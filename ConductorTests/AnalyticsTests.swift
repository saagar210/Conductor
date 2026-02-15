import XCTest
import SwiftData
@testable import Conductor

@MainActor
final class AnalyticsTests: XCTestCase {
    func testCalculateTokenStats() throws {
        let sessions = createMockSessionsForAnalytics()

        let stats = AnalyticsCalculator.calculateTokenStats(for: sessions)

        XCTAssertGreaterThan(stats.totalTokens, 0)
        XCTAssertGreaterThan(stats.avgPerSession, 0)
        XCTAssertEqual(stats.avgPerSession, stats.totalTokens / sessions.count)
    }

    func testCalculateTokenStats_EmptySessions() throws {
        let stats = AnalyticsCalculator.calculateTokenStats(for: [])

        XCTAssertEqual(stats.totalTokens, 0)
        XCTAssertEqual(stats.avgPerSession, 0)
        XCTAssertEqual(stats.avgPerNode, 0)
        XCTAssertEqual(stats.range.min, 0)
        XCTAssertEqual(stats.range.max, 0)
    }

    func testCalculateSessionAnalytics() throws {
        let context = createInMemoryContext()
        let session = createMockSessionWithNodes(in: context)

        let analytics = AnalyticsCalculator.calculateSessionAnalytics(for: session)

        XCTAssertEqual(analytics.sessionID, session.id)
        XCTAssertEqual(analytics.nodeCount, session.nodes.count)
        XCTAssertEqual(analytics.totalTokens, session.totalTokens)
        XCTAssertGreaterThanOrEqual(analytics.successRate, 0.0)
        XCTAssertLessThanOrEqual(analytics.successRate, 1.0)
    }

    func testCalculateToolPerformance() throws {
        let sessions = createMockSessionsWithTools()

        let performance = AnalyticsCalculator.calculateToolPerformance(for: sessions)

        XCTAssertGreaterThan(performance.count, 0)

        for tool in performance {
            XCTAssertGreaterThan(tool.callCount, 0)
            XCTAssertGreaterThanOrEqual(tool.successRate, 0.0)
            XCTAssertLessThanOrEqual(tool.successRate, 1.0)
            XCTAssertEqual(tool.failureCount, tool.callCount - Int(Double(tool.callCount) * tool.successRate))
        }
    }

    func testFilterSessionsByDateRange() throws {
        let sessions = createMockSessionsForAnalytics()

        // Test today filter
        let today = AnalyticsCalculator.filterSessionsByDateRange(sessions, range: .today)
        for session in today {
            let calendar = Calendar.current
            let isToday = calendar.isDateInToday(session.startedAt)
            XCTAssertTrue(isToday)
        }

        // Test all filter
        let all = AnalyticsCalculator.filterSessionsByDateRange(sessions, range: .all)
        XCTAssertEqual(all.count, sessions.count)
    }

    func testCalculateTrends() throws {
        let sessions = createMockSessionsForAnalytics()

        let trends = AnalyticsCalculator.calculateTrends(for: sessions, by: .daily)

        XCTAssertGreaterThan(trends.count, 0)

        // Trends should be sorted by date
        for i in 0..<(trends.count - 1) {
            XCTAssertLessThanOrEqual(trends[i].date, trends[i + 1].date)
        }
    }

    func testCompareSessionsSorting() throws {
        let sessions = createMockSessionsForAnalytics()

        // Sort by tokens
        let byTokens = AnalyticsCalculator.compareSessionsBy(sessions: sessions, sortBy: .tokens)
        for i in 0..<(byTokens.count - 1) {
            XCTAssertGreaterThanOrEqual(byTokens[i].totalTokens, byTokens[i + 1].totalTokens)
        }

        // Sort by duration
        let byDuration = AnalyticsCalculator.compareSessionsBy(sessions: sessions, sortBy: .duration)
        for i in 0..<(byDuration.count - 1) {
            XCTAssertGreaterThanOrEqual(byDuration[i].totalDuration, byDuration[i + 1].totalDuration)
        }
    }

    // MARK: - Helper Methods

    private func createInMemoryContext() -> ModelContext {
        let schema = Schema([Session.self, AgentNode.self, CommandRecord.self, ToolCallRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func createMockSessionsForAnalytics() -> [Session] {
        var sessions: [Session] = []

        for i in 0..<5 {
            let session = Session(
                id: UUID(),
                name: "Analytics Session \(i)",
                slug: "analytics-\(i)",
                sourceDir: "/test",
                logPath: "/test/log\(i).jsonl",
                rootPrompt: "Analytics test \(i)",
                status: .completed,
                startedAt: Date().addingTimeInterval(Double(-i * 86400)), // i days ago
                totalTokens: 1000 * (i + 1),
                totalDuration: Double((i + 1) * 60)
            )
            sessions.append(session)
        }

        return sessions
    }

    private func createMockSessionWithNodes(in context: ModelContext) -> Session {
        let session = Session(
            id: UUID(),
            name: "Session with Nodes",
            slug: "with-nodes",
            sourceDir: "/test",
            logPath: "/test/nodes.jsonl",
            rootPrompt: "Test",
            status: .completed,
            startedAt: Date(),
            totalTokens: 5000
        )
        context.insert(session)

        for i in 0..<3 {
            let node = AgentNode(
                id: UUID(),
                agentType: .subagent,
                agentName: "Node \(i)",
                task: "Task \(i)",
                status: i == 0 ? .completed : .running,
                tokenCount: 1000
            )
            node.session = session
            context.insert(node)
        }

        return session
    }

    private func createMockSessionsWithTools() -> [Session] {
        let context = createInMemoryContext()
        var sessions: [Session] = []

        for i in 0..<2 {
            let session = Session(
                id: UUID(),
                name: "Tool Session \(i)",
                slug: "tools-\(i)",
                sourceDir: "/test",
                logPath: "/test/tools\(i).jsonl",
                rootPrompt: "Test",
                status: .completed,
                startedAt: Date(),
                totalTokens: 1000
            )
            context.insert(session)

            let node = AgentNode(
                id: UUID(),
                agentType: .orchestrator,
                agentName: "Orchestrator",
                task: "Execute tools",
                status: .completed,
                tokenCount: 1000
            )
            node.session = session
            context.insert(node)

            // Add command records
            let cmd = CommandRecord(
                id: UUID(),
                command: "echo test",
                exitCode: 0,
                duration: 0.1
            )
            cmd.node = node
            context.insert(cmd)

            sessions.append(session)
        }

        return sessions
    }
}
