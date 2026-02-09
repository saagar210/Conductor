import SwiftUI

enum ConductorTheme {
    // Node fill color: determined by STATUS (primary visual signal)
    static func nodeColor(for status: AgentNodeStatus) -> Color {
        switch status {
        case .pending:   return .gray
        case .running:   return .blue
        case .completed: return .green
        case .failed:    return .red
        }
    }

    // Node stroke color: determined by TYPE (secondary visual signal)
    static func nodeStroke(for agentType: AgentType) -> Color {
        switch agentType {
        case .orchestrator: return .primary.opacity(0.6)
        case .subagent:     return .purple.opacity(0.6)
        case .toolCall:     return .orange.opacity(0.6)
        }
    }

    // Node radius: determined by TYPE
    static func nodeRadius(for agentType: AgentType) -> Double {
        switch agentType {
        case .orchestrator: return 30
        case .subagent:     return 22
        case .toolCall:     return 12
        }
    }

    // Badge colors for AgentNodeStatus
    static func color(for status: AgentNodeStatus) -> Color {
        nodeColor(for: status)
    }

    // Badge colors for ToolCallStatus
    static func color(for status: ToolCallStatus) -> Color {
        switch status {
        case .pending:   return .gray
        case .running:   return .blue
        case .succeeded: return .green
        case .failed:    return .red
        }
    }

    // Graph constants
    static let edgeColor = Color.secondary.opacity(0.4)
    static let selectionBorder = Color.accentColor
    static let selectionGlow = Color.accentColor.opacity(0.5)

    // Layout constants
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 250
    static let sidebarMaxWidth: CGFloat = 350
    static let detailMinWidth: CGFloat = 280
}
