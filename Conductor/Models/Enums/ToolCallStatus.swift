import Foundation

enum ToolCallStatus: String, Codable, CaseIterable, Sendable {
    case pending, running, succeeded, failed
}
