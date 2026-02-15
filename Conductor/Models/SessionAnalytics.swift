import Foundation
import SwiftData

@Model
final class SessionAnalytics: Sendable {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var computedAt: Date
    var totalTokens: Int
    var avgTokensPerNode: Int
    var nodeCount: Int
    var commandCount: Int
    var toolCallCount: Int
    var successRate: Double

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        computedAt: Date = Date(),
        totalTokens: Int = 0,
        avgTokensPerNode: Int = 0,
        nodeCount: Int = 0,
        commandCount: Int = 0,
        toolCallCount: Int = 0,
        successRate: Double = 0.0
    ) {
        self.id = id
        self.sessionID = sessionID
        self.computedAt = computedAt
        self.totalTokens = totalTokens
        self.avgTokensPerNode = avgTokensPerNode
        self.nodeCount = nodeCount
        self.commandCount = commandCount
        self.toolCallCount = toolCallCount
        self.successRate = successRate
    }
}
