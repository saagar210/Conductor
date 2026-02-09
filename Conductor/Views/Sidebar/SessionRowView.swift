import SwiftUI

struct SessionRowView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if session.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(session.name)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                StatusBadge(status: sessionStatusToNodeStatus(session.status))
                Text("\(session.nodes.count) nodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(session.startedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private func sessionStatusToNodeStatus(_ status: SessionStatus) -> AgentNodeStatus {
        switch status {
        case .active:    return .running
        case .completed: return .completed
        case .failed:    return .failed
        case .cancelled: return .pending
        }
    }
}
