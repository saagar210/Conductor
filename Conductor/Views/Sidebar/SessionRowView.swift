import SwiftUI

struct SessionRowView: View {
    let session: Session
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if session.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if isLive {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("LIVE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.1))
                    .cornerRadius(4)
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
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private var isLive: Bool {
        // Session is considered live if:
        // 1. Status is active, or
        // 2. No completion date, or
        // 3. Last activity within 30 seconds
        if session.status == .active {
            return true
        }

        if session.completedAt == nil {
            return true
        }

        if let completed = session.completedAt {
            let timeSinceCompletion = Date().timeIntervalSince(completed)
            return timeSinceCompletion < 30
        }

        return false
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
