import Foundation
import SwiftData

@Model
final class CommandRecord {
    var id: UUID
    var node: AgentNode?
    var command: String
    var exitCode: Int
    var stdout: String
    var stderr: String
    var duration: Double
    var executedAt: Date

    init(
        id: UUID = UUID(),
        node: AgentNode? = nil,
        command: String = "",
        exitCode: Int = 0,
        stdout: String = "",
        stderr: String = "",
        duration: Double = 0,
        executedAt: Date = Date()
    ) {
        self.id = id
        self.node = node
        self.command = command
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.duration = duration
        self.executedAt = executedAt
    }
}
