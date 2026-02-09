import SwiftUI

struct StatsBarView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 0) {
            statItem(value: "\(session.nodes.count)", label: "Nodes")
            Divider().padding(.vertical, 8)
            statItem(value: session.status.rawValue.capitalized, label: "Status")
            Divider().padding(.vertical, 8)
            statItem(value: formatTokens(session.totalTokens), label: "Tokens")
            Divider().padding(.vertical, 8)
            statItem(value: formatDuration(session.totalDuration), label: "Duration")
            Divider().padding(.vertical, 8)
            statItem(value: "\(activeCount)", label: "Active", color: .blue)
            Divider().padding(.vertical, 8)
            statItem(value: "\(failedCount)", label: "Failed", color: failedCount > 0 ? .red : .secondary)
        }
        .padding(.horizontal)
        .background(.bar)
    }

    private var activeCount: Int {
        session.nodes.filter { $0.status == .running }.count
    }

    private var failedCount: Int {
        session.nodes.filter { $0.status == .failed }.count
    }

    private func statItem(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }

    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m \(secs)s"
    }
}
