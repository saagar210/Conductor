import Foundation
import SwiftData

@Model
final class AgentNode {
    var id: UUID
    var session: Session?
    var parent: AgentNode?

    @Relationship(deleteRule: .cascade, inverse: \AgentNode.parent)
    var children: [AgentNode]

    var agentType: AgentType
    var agentName: String
    var task: String
    var result: String
    var status: AgentNodeStatus
    var startedAt: Date?
    var completedAt: Date?
    var duration: Double
    var tokenCount: Int
    var depth: Int
    var filesModifiedRaw: String
    var filesCreatedRaw: String
    var errorMessage: String?

    @Relationship(deleteRule: .cascade, inverse: \CommandRecord.node)
    var commandRecords: [CommandRecord]

    @Relationship(deleteRule: .cascade, inverse: \ToolCallRecord.node)
    var toolCallRecords: [ToolCallRecord]

    var filesModified: [String] {
        get {
            guard !filesModifiedRaw.isEmpty else { return [] }
            return filesModifiedRaw.components(separatedBy: "|||")
        }
        set {
            filesModifiedRaw = newValue.joined(separator: "|||")
        }
    }

    var filesCreated: [String] {
        get {
            guard !filesCreatedRaw.isEmpty else { return [] }
            return filesCreatedRaw.components(separatedBy: "|||")
        }
        set {
            filesCreatedRaw = newValue.joined(separator: "|||")
        }
    }

    init(
        id: UUID = UUID(),
        session: Session? = nil,
        parent: AgentNode? = nil,
        children: [AgentNode] = [],
        agentType: AgentType = .subagent,
        agentName: String = "",
        task: String = "",
        result: String = "",
        status: AgentNodeStatus = .pending,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        duration: Double = 0,
        tokenCount: Int = 0,
        depth: Int = 0,
        filesModifiedRaw: String = "",
        filesCreatedRaw: String = "",
        errorMessage: String? = nil,
        commandRecords: [CommandRecord] = [],
        toolCallRecords: [ToolCallRecord] = []
    ) {
        self.id = id
        self.session = session
        self.parent = parent
        self.children = children
        self.agentType = agentType
        self.agentName = agentName
        self.task = task
        self.result = result
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.tokenCount = tokenCount
        self.depth = depth
        self.filesModifiedRaw = filesModifiedRaw
        self.filesCreatedRaw = filesCreatedRaw
        self.errorMessage = errorMessage
        self.commandRecords = commandRecords
        self.toolCallRecords = toolCallRecords
    }
}
