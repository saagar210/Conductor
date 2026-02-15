import Foundation
import SwiftUI
import SwiftData

enum SearchFilterType: String, Codable, Sendable, CaseIterable {
    case none = "None"
    case projectName = "Project"
    case status = "Status"
    case dateRange = "Date Range"
    case tokenRange = "Tokens"
    case text = "Full Text"
}

enum SearchFilter: Hashable, Sendable {
    case none
    case project(String)
    case status(SessionStatus)
    case dateRange(Date, Date)
    case tokens(min: Int, max: Int)
    case text(String)
}

struct SearchResult: Sendable, Identifiable {
    var id: UUID { session.id }
    let session: Session
    let matchedFields: [MatchedField]
    let relevanceScore: Double
}

enum MatchedField: String, Sendable {
    case name
    case prompt
    case projectName
    case notes
}

@Observable
@MainActor
final class SearchState {
    var searchText: String = ""
    var currentFilter: SearchFilter = .none
    var isSearching: Bool = false
    var debouncedSearchText: String = ""

    private var debounceTask: Task<Void, Never>?

    init() {
        // Set up debouncing for search text
    }

    func updateSearchText(_ text: String) {
        searchText = text

        // Cancel previous debounce task
        debounceTask?.cancel()

        // Create new debounce task (300ms delay)
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if !Task.isCancelled {
                debouncedSearchText = text
            }
        }
    }

    func filterSessions(_ sessions: [Session]) -> [Session] {
        isSearching = true
        defer { isSearching = false }

        var filtered = sessions

        // Apply text search
        if !debouncedSearchText.isEmpty {
            filtered = filtered.filter { session in
                matchesQuery(session, query: debouncedSearchText)
            }
        }

        // Apply current filter
        filtered = applyFilter(to: filtered, filter: currentFilter)

        return filtered
    }

    func searchWithResults(_ sessions: [Session]) -> [SearchResult] {
        let filtered = filterSessions(sessions)

        return filtered.map { session in
            let matchedFields = findMatchedFields(session, query: debouncedSearchText)
            let relevanceScore = calculateRelevance(session, query: debouncedSearchText, matchedFields: matchedFields)
            return SearchResult(session: session, matchedFields: matchedFields, relevanceScore: relevanceScore)
        }.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    private func matchesQuery(_ session: Session, query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let lowercaseQuery = query.lowercased()

        // Search in name
        if session.name.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in prompt
        if session.rootPrompt.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in project tags
        if session.tags.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
            return true
        }

        // Search in notes
        if session.notes.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }

    private func applyFilter(to sessions: [Session], filter: SearchFilter) -> [Session] {
        switch filter {
        case .none:
            return sessions

        case .project(let projectName):
            return sessions.filter { session in
                session.tags.contains(where: { $0.caseInsensitiveCompare(projectName) == .orderedSame })
            }

        case .status(let status):
            return sessions.filter { $0.status == status }

        case .dateRange(let start, let end):
            return sessions.filter { session in
                session.startedAt >= start && session.startedAt <= end
            }

        case .tokens(let min, let max):
            return sessions.filter { session in
                session.totalTokens >= min && session.totalTokens <= max
            }

        case .text(let query):
            return sessions.filter { matchesQuery($0, query: query) }
        }
    }

    private func findMatchedFields(_ session: Session, query: String) -> [MatchedField] {
        guard !query.isEmpty else { return [] }

        var matched: [MatchedField] = []
        let lowercaseQuery = query.lowercased()

        if session.name.lowercased().contains(lowercaseQuery) {
            matched.append(.name)
        }

        if session.rootPrompt.lowercased().contains(lowercaseQuery) {
            matched.append(.prompt)
        }

        if session.tags.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
            matched.append(.projectName)
        }

        if session.notes.lowercased().contains(lowercaseQuery) {
            matched.append(.notes)
        }

        return matched
    }

    private func calculateRelevance(_ session: Session, query: String, matchedFields: [MatchedField]) -> Double {
        guard !query.isEmpty else { return 0.0 }

        var score = 0.0
        let lowercaseQuery = query.lowercased()

        // Name match is most relevant
        if matchedFields.contains(.name) {
            let nameMatch = session.name.lowercased()
            if nameMatch == lowercaseQuery {
                score += 1.0  // Exact match
            } else if nameMatch.hasPrefix(lowercaseQuery) {
                score += 0.8  // Prefix match
            } else {
                score += 0.5  // Contains match
            }
        }

        // Prompt match
        if matchedFields.contains(.prompt) {
            score += 0.3
        }

        // Project name match
        if matchedFields.contains(.projectName) {
            score += 0.4
        }

        // Notes match
        if matchedFields.contains(.notes) {
            score += 0.2
        }

        // Boost recent sessions
        let daysSinceStart = Date().timeIntervalSince(session.startedAt) / 86400
        let recencyBoost = max(0, 0.2 * (1.0 - daysSinceStart / 30.0))
        score += recencyBoost

        // Boost bookmarked sessions
        if session.isBookmarked {
            score += 0.1
        }

        return min(score, 2.0) // Cap at 2.0
    }

    func clearSearch() {
        searchText = ""
        debouncedSearchText = ""
        currentFilter = .none
        debounceTask?.cancel()
    }

    func setFilter(_ filter: SearchFilter) {
        currentFilter = filter
    }

    func recordSearch(query: String, filterType: SearchFilterType, resultCount: Int, in context: ModelContext) {
        guard !query.isEmpty else { return }

        let descriptor = FetchDescriptor<SearchHistory>(
            predicate: #Predicate { $0.query == query && $0.filterTypeRaw == filterType.rawValue }
        )

        if let existing = try? context.fetch(descriptor).first {
            // Update existing entry
            existing.executedAt = Date()
            existing.resultCount = resultCount
            existing.frequency += 1
        } else {
            // Create new entry
            let history = SearchHistory(
                query: query,
                filterType: filterType,
                executedAt: Date(),
                resultCount: resultCount,
                frequency: 1
            )
            context.insert(history)
        }

        try? context.save()
    }

    func getRecentSearches(from context: ModelContext, limit: Int = 10) -> [SearchHistory] {
        let descriptor = FetchDescriptor<SearchHistory>(
            sortBy: [SortDescriptor(\.executedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor).prefix(limit).map { $0 }) ?? []
    }

    func getPopularSearches(from context: ModelContext, limit: Int = 5) -> [SearchHistory] {
        let descriptor = FetchDescriptor<SearchHistory>(
            sortBy: [SortDescriptor(\.frequency, order: .reverse)]
        )
        return (try? context.fetch(descriptor).prefix(limit).map { $0 }) ?? []
    }
}
