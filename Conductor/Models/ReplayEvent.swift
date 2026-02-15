import Foundation
import SwiftData

enum ReplayEventType: String, Codable, Sendable {
    case sessionStarted
    case nodeCreated
    case nodeProgressUpdate
    case toolCallInitiated
    case toolCallCompleted
    case commandExecuted
    case sessionCompleted
}

@Model
final class ReplayEvent: Sendable {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var timestamp: Double // Relative to session start (in seconds)
    var eventTypeRaw: String
    var nodeID: UUID?
    var details: String // JSON payload

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        timestamp: Double,
        eventType: ReplayEventType,
        nodeID: UUID? = nil,
        details: String = ""
    ) {
        self.id = id
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.eventTypeRaw = eventType.rawValue
        self.nodeID = nodeID
        self.details = details
    }

    var eventType: ReplayEventType {
        get { ReplayEventType(rawValue: eventTypeRaw) ?? .nodeProgressUpdate }
        set { eventTypeRaw = newValue.rawValue }
    }
}
