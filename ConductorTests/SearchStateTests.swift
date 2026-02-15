import XCTest
import SwiftData
@testable import Conductor

@MainActor
final class SearchStateTests: XCTestCase {
    var searchState: SearchState!

    override func setUp() async throws {
        searchState = SearchState()
    }

    override func tearDown() async throws {
        searchState = nil
    }

    func testSearchTextDebouncing() async throws {
        searchState.updateSearchText("test")
        XCTAssertEqual(searchState.searchText, "test")
        XCTAssertEqual(searchState.debouncedSearchText, "") // Not yet debounced

        try await Task.sleep(for: .milliseconds(350))
        XCTAssertEqual(searchState.debouncedSearchText, "test")
    }

    func testFilterSessions_EmptyQuery() throws {
        let context = createInMemoryContext()
        let sessions = createMockSessions(in: context)

        let filtered = searchState.filterSessions(sessions)
        XCTAssertEqual(filtered.count, sessions.count)
    }

    func testFilterSessions_NameMatch() async throws {
        let context = createInMemoryContext()
        let sessions = createMockSessions(in: context)

        searchState.updateSearchText("Test")
        try await Task.sleep(for: .milliseconds(350))

        let filtered = searchState.filterSessions(sessions)
        XCTAssertGreaterThan(filtered.count, 0)
    }

    func testFilterByStatus() throws {
        let context = createInMemoryContext()
        let sessions = createMockSessions(in: context)

        searchState.setFilter(.status(.completed))
        let filtered = searchState.filterSessions(sessions)

        for session in filtered {
            XCTAssertEqual(session.status, .completed)
        }
    }

    func testFilterByDateRange() throws {
        let context = createInMemoryContext()
        let sessions = createMockSessions(in: context)

        let start = Date().addingTimeInterval(-86400) // 1 day ago
        let end = Date()

        searchState.setFilter(.dateRange(start, end))
        let filtered = searchState.filterSessions(sessions)

        for session in filtered {
            XCTAssertGreaterThanOrEqual(session.startedAt, start)
            XCTAssertLessThanOrEqual(session.startedAt, end)
        }
    }

    func testRelevanceScoring() async throws {
        let context = createInMemoryContext()
        let sessions = createMockSessions(in: context)

        searchState.updateSearchText("test")
        try await Task.sleep(for: .milliseconds(350))

        let results = searchState.searchWithResults(sessions)
        if results.count > 1 {
            // Results should be sorted by relevance
            for i in 0..<(results.count - 1) {
                XCTAssertGreaterThanOrEqual(results[i].relevanceScore, results[i + 1].relevanceScore)
            }
        }
    }

    func testClearSearch() async throws {
        searchState.updateSearchText("test")
        searchState.setFilter(.status(.completed))

        searchState.clearSearch()

        XCTAssertEqual(searchState.searchText, "")
        XCTAssertEqual(searchState.debouncedSearchText, "")
        XCTAssertEqual(searchState.currentFilter, .none)
    }

    // MARK: - Helper Methods

    private func createInMemoryContext() -> ModelContext {
        let schema = Schema([Session.self, AgentNode.self, CommandRecord.self, ToolCallRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func createMockSessions(in context: ModelContext) -> [Session] {
        var sessions: [Session] = []

        for i in 0..<5 {
            let session = Session(
                id: UUID(),
                name: "Test Session \(i)",
                slug: "test-\(i)",
                sourceDir: "/test",
                logPath: "/test/log\(i).jsonl",
                rootPrompt: "Test prompt \(i)",
                status: i % 2 == 0 ? .completed : .active,
                startedAt: Date().addingTimeInterval(Double(-i * 3600)),
                totalTokens: 1000 * (i + 1)
            )
            context.insert(session)
            sessions.append(session)
        }

        return sessions
    }
}
