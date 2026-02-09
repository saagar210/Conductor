import SwiftUI

struct NodeDetailHeader: View {
    let node: AgentNode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(node.agentName)
                .font(.headline)

            HStack(spacing: 8) {
                StatusBadge(status: node.status)
                StatusBadge(agentType: node.agentType)

                Spacer()

                if node.tokenCount > 0 {
                    Label("\(node.tokenCount) tokens", systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if node.duration > 0 {
                    Label(formatDuration(node.duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.bar)
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
