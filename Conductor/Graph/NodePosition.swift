import Foundation

struct NodePosition: Identifiable, Sendable {
    let id: UUID
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    let depth: Int
    let agentType: AgentType
    let status: AgentNodeStatus
    let parentID: UUID?

    var point: CGPoint { CGPoint(x: x, y: y) }
    var kineticEnergy: Double { vx * vx + vy * vy }
}
