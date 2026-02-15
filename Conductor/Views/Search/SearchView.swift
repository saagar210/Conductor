import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    let sessions: [Session]
    @Binding var selectedSessionID: UUID?

    @State private var showFilterPanel = false
    @State private var showHistory = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search sessions...", text: Binding(
                    get: { appState.searchState.searchText },
                    set: {
                        appState.searchState.updateSearchText($0)
                        showHistory = false
                    }
                ))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onTapGesture {
                    showHistory = true
                }
                .onChange(of: isSearchFocused) { _, isFocused in
                    if isFocused && appState.searchState.searchText.isEmpty {
                        showHistory = true
                    } else if !isFocused {
                        Task {
                            try? await Task.sleep(for: .milliseconds(200))
                            showHistory = false
                        }
                    }
                }
                .onChange(of: appState.searchState.debouncedSearchText) { _, newText in
                    if !newText.isEmpty {
                        let resultCount = filteredSessions.count
                        appState.searchState.recordSearch(
                            query: newText,
                            filterType: .text,
                            resultCount: resultCount,
                            in: modelContext
                        )
                    }
                }

                if !appState.searchState.searchText.isEmpty {
                    Button(action: {
                        appState.searchState.clearSearch()
                        showHistory = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    showFilterPanel.toggle()
                }) {
                    Image(systemName: showFilterPanel ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(appState.searchState.currentFilter == .none ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding([.horizontal, .top], 12)

            // Search history
            if showHistory && appState.searchState.searchText.isEmpty {
                SearchHistoryView { query in
                    appState.searchState.updateSearchText(query)
                    showHistory = false
                    isSearchFocused = false
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Filter panel
            if showFilterPanel {
                SearchFilterPanel()
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
                .padding(.top, 8)

            // Results
            SearchResultsView(
                sessions: filteredSessions,
                selectedSessionID: $selectedSessionID
            )
        }
    }

    private var filteredSessions: [Session] {
        let searchState = appState.searchState

        // If no search text and no filter, return all sessions
        if searchState.debouncedSearchText.isEmpty && searchState.currentFilter == .none {
            return sessions
        }

        return searchState.filterSessions(sessions)
    }
}

struct SearchFilterPanel: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter by:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterButton(
                        title: "All",
                        icon: "circle.grid.3x3",
                        isActive: appState.searchState.currentFilter == .none
                    ) {
                        appState.searchState.setFilter(.none)
                    }

                    FilterButton(
                        title: "Active",
                        icon: "bolt.circle",
                        isActive: matchesStatusFilter(.active)
                    ) {
                        appState.searchState.setFilter(.status(.active))
                    }

                    FilterButton(
                        title: "Completed",
                        icon: "checkmark.circle",
                        isActive: matchesStatusFilter(.completed)
                    ) {
                        appState.searchState.setFilter(.status(.completed))
                    }

                    FilterButton(
                        title: "Failed",
                        icon: "xmark.circle",
                        isActive: matchesStatusFilter(.failed)
                    ) {
                        appState.searchState.setFilter(.status(.failed))
                    }

                    FilterButton(
                        title: "Today",
                        icon: "calendar",
                        isActive: matchesDateRangeFilter(days: 1)
                    ) {
                        let start = Calendar.current.startOfDay(for: Date())
                        appState.searchState.setFilter(.dateRange(start, Date()))
                    }

                    FilterButton(
                        title: "This Week",
                        icon: "calendar.badge.clock",
                        isActive: matchesDateRangeFilter(days: 7)
                    ) {
                        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        appState.searchState.setFilter(.dateRange(start, Date()))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func matchesStatusFilter(_ status: SessionStatus) -> Bool {
        if case .status(let filterStatus) = appState.searchState.currentFilter {
            return filterStatus == status
        }
        return false
    }

    private func matchesDateRangeFilter(days: Int) -> Bool {
        if case .dateRange(let start, _) = appState.searchState.currentFilter {
            let expectedStart = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return abs(start.timeIntervalSince(expectedStart)) < 3600 // Within an hour
        }
        return false
    }
}

struct FilterButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.blue : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(isActive ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct SearchResultsView: View {
    let sessions: [Session]
    @Binding var selectedSessionID: UUID?

    var body: some View {
        if sessions.isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "No Results",
                subtitle: "Try adjusting your search or filters"
            )
        } else {
            List(groupedSessions.keys.sorted(by: >), id: \.self) { project in
                Section {
                    ForEach(groupedSessions[project] ?? []) { session in
                        SessionRowView(
                            session: session,
                            isSelected: selectedSessionID == session.id
                        )
                        .onTapGesture {
                            selectedSessionID = session.id
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(project)
                            .font(.headline)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var groupedSessions: [String: [Session]] {
        Dictionary(grouping: sessions) { session in
            session.tags.first ?? "Uncategorized"
        }
    }
}
