import Foundation
import SwiftData

@Model
final class ToolMetric: Sendable {
    @Attribute(.unique) var id: UUID
    var toolName: String
    var callCount: Int
    var successCount: Int
    var totalDuration: Double
    var lastUsed: Date

    var avgDuration: Double {
        callCount > 0 ? totalDuration / Double(callCount) : 0
    }

    var successRate: Double {
        callCount > 0 ? Double(successCount) / Double(callCount) : 0
    }

    init(
        id: UUID = UUID(),
        toolName: String,
        callCount: Int = 0,
        successCount: Int = 0,
        totalDuration: Double = 0.0,
        lastUsed: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.callCount = callCount
        self.successCount = successCount
        self.totalDuration = totalDuration
        self.lastUsed = lastUsed
    }
}
