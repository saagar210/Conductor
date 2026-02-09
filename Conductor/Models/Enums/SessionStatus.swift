import Foundation

enum SessionStatus: String, Codable, CaseIterable, Sendable {
    case active, completed, failed, cancelled
}
