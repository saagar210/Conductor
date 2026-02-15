import SwiftUI
import SwiftData

struct SearchHistoryView: View {
    @Query(sort: \SearchHistory.executedAt, order: .reverse) private var recentSearches: [SearchHistory]

    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !recentSearches.isEmpty {
                Text("Recent Searches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(recentSearches.prefix(10)) { history in
                            SearchHistoryRow(history: history) {
                                onSelect(history.query)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 200)
            } else {
                Text("No search history yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct SearchHistoryRow: View {
    let history: SearchHistory
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                VStack(alignment: .leading, spacing: 2) {
                    Text(history.query)
                        .font(.body)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(history.resultCount) results")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(formattedDate(history.executedAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if history.frequency > 1 {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("Used \(history.frequency)×")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func formattedDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}
