import SwiftUI

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    init(status: AgentNodeStatus) {
        self.text = status.rawValue.capitalized
        self.color = ConductorTheme.color(for: status)
    }

    init(agentType: AgentType) {
        self.text = agentType.rawValue.capitalized
        self.color = ConductorTheme.nodeStroke(for: agentType)
    }

    init(toolStatus: ToolCallStatus) {
        self.text = toolStatus.rawValue.capitalized
        self.color = ConductorTheme.color(for: toolStatus)
    }
}
