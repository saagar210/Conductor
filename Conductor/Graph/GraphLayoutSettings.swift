import Foundation

struct GraphLayoutSettings: Sendable {
    var repulsionStrength: Double = 5000.0
    var springStrength: Double = 0.01
    var springRestLength: Double = 120.0
    var centerGravity: Double = 0.1
    var depthYStrength: Double = 0.05
    var depthYSpacing: Double = 150.0
    var damping: Double = 0.9
    var convergenceThreshold: Double = 0.1
    var tickInterval: TimeInterval = 1.0 / 60.0
}
