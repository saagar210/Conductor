import Foundation
import SwiftData

@Model
final class ToolCallRecord {
    var id: UUID
    var node: AgentNode?
    var toolName: String
    var input: String
    var output: String
    var status: ToolCallStatus
    var executedAt: Date

    init(
        id: UUID = UUID(),
        node: AgentNode? = nil,
        toolName: String = "",
        input: String = "",
        output: String = "",
        status: ToolCallStatus = .pending,
        executedAt: Date = Date()
    ) {
        self.id = id
        self.node = node
        self.toolName = toolName
        self.input = input
        self.output = output
        self.status = status
        self.executedAt = executedAt
    }
}
