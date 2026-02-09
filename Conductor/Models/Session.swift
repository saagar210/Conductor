import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    var name: String
    var slug: String
    var sourceDir: String
    var logPath: String
    var rootPrompt: String
    var status: SessionStatus
    var startedAt: Date
    var completedAt: Date?
    var totalTokens: Int
    var totalDuration: Double
    var isBookmarked: Bool
    var notes: String
    var tagsRaw: String

    @Relationship(deleteRule: .cascade, inverse: \AgentNode.session)
    var nodes: [AgentNode]

    var tags: [String] {
        get {
            guard !tagsRaw.isEmpty else { return [] }
            return tagsRaw.components(separatedBy: ",")
        }
        set {
            tagsRaw = newValue.joined(separator: ",")
        }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        slug: String = "",
        sourceDir: String = "",
        logPath: String = "",
        rootPrompt: String = "",
        status: SessionStatus = .active,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        totalTokens: Int = 0,
        totalDuration: Double = 0,
        isBookmarked: Bool = false,
        notes: String = "",
        tagsRaw: String = "",
        nodes: [AgentNode] = []
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.sourceDir = sourceDir
        self.logPath = logPath
        self.rootPrompt = rootPrompt
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.totalTokens = totalTokens
        self.totalDuration = totalDuration
        self.isBookmarked = isBookmarked
        self.notes = notes
        self.tagsRaw = tagsRaw
        self.nodes = nodes
    }
}
