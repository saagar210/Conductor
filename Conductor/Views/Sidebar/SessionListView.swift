import SwiftUI

struct SessionListView: View {
    let sessions: [Session]
    @Binding var selectedSessionID: UUID?

    /// Sessions grouped by project (from tagsRaw), sorted by most recent session in each group.
    private var groupedSessions: [(project: String, sessions: [Session])] {
        let grouped = Dictionary(grouping: sessions) { session in
            session.tagsRaw.isEmpty ? "Other" : session.tagsRaw
        }
        return grouped
            .map { (project: $0.key, sessions: $0.value) }
            .sorted { lhs, rhs in
                let lhsDate = lhs.sessions.first?.startedAt ?? .distantPast
                let rhsDate = rhs.sessions.first?.startedAt ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    var body: some View {
        List(selection: $selectedSessionID) {
            ForEach(groupedSessions, id: \.project) { group in
                Section(group.project) {
                    ForEach(group.sessions, id: \.id) { session in
                        SessionRowView(session: session)
                            .tag(session.id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Sessions")
    }
}
