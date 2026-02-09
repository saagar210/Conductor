import Foundation

enum AgentType: String, Codable, CaseIterable, Sendable {
    case orchestrator, subagent, toolCall
}
