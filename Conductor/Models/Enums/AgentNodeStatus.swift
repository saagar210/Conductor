import Foundation

enum AgentNodeStatus: String, Codable, CaseIterable, Sendable {
    case pending, running, completed, failed
}
