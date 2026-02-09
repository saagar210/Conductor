import Foundation
import os

@Observable
@MainActor
final class ForceSimulation {
    private let logger = Logger(subsystem: "com.conductor.app", category: "simulation")

    var positions: [NodePosition] = []
    var isRunning: Bool = false
    var settings = GraphLayoutSettings()

    private var edges: [(Int, Int)] = []  // (parentIndex, childIndex)
    private var simulationTask: Task<Void, Never>?
    private var canvasSize: CGSize = .zero

    func loadNodes(from nodes: [AgentNode], canvasSize: CGSize) {
        stop()
        self.canvasSize = canvasSize

        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2

        // Create initial positions in radial layout
        var newPositions: [NodePosition] = []
        let nodeCount = nodes.count

        for (index, node) in nodes.enumerated() {
            let angle = (Double(index) / Double(max(nodeCount, 1))) * 2.0 * .pi
            let radius = 50.0 + Double(node.depth) * 80.0
            let x = centerX + cos(angle) * radius + Double.random(in: -10...10)
            let y = centerY + sin(angle) * radius + Double.random(in: -10...10)

            newPositions.append(NodePosition(
                id: node.id,
                x: x,
                y: y,
                vx: 0,
                vy: 0,
                depth: node.depth,
                agentType: node.agentType,
                status: node.status,
                parentID: node.parent?.id
            ))
        }

        positions = newPositions

        // Build edge index list
        edges = []
        for (childIdx, pos) in positions.enumerated() {
            guard let parentID = pos.parentID else { continue }
            if let parentIdx = positions.firstIndex(where: { $0.id == parentID }) {
                edges.append((parentIdx, childIdx))
            }
        }

        guard !positions.isEmpty else { return }

        isRunning = true
        simulationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isRunning {
                self.tick()
                try? await Task.sleep(for: .seconds(self.settings.tickInterval))
            }
        }

        logger.debug("Loaded \(nodes.count) nodes with \(self.edges.count) edges")
    }

    func stop() {
        simulationTask?.cancel()
        simulationTask = nil
        isRunning = false
    }

    func tick() {
        let count = positions.count
        guard count > 0 else { return }

        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2

        var forces = Array(repeating: (fx: 0.0, fy: 0.0), count: count)

        // 1. REPULSION (all pairs)
        for i in 0..<count {
            for j in (i + 1)..<count {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let distSq = max(dx * dx + dy * dy, 1.0)
                let force = settings.repulsionStrength / distSq
                let dist = sqrt(distSq)
                let fx = (dx / dist) * force
                let fy = (dy / dist) * force

                forces[i].fx += fx
                forces[i].fy += fy
                forces[j].fx -= fx
                forces[j].fy -= fy
            }
        }

        // 2. SPRING ATTRACTION (edges only)
        for (parentIdx, childIdx) in edges {
            let dx = positions[childIdx].x - positions[parentIdx].x
            let dy = positions[childIdx].y - positions[parentIdx].y
            let dist = max(sqrt(dx * dx + dy * dy), 1.0)
            let displacement = dist - settings.springRestLength
            let force = settings.springStrength * displacement
            let fx = (dx / dist) * force
            let fy = (dy / dist) * force

            forces[parentIdx].fx += fx
            forces[parentIdx].fy += fy
            forces[childIdx].fx -= fx
            forces[childIdx].fy -= fy
        }

        // 3. CENTER GRAVITY (all nodes)
        for i in 0..<count {
            forces[i].fx += settings.centerGravity * (centerX - positions[i].x)
            forces[i].fy += settings.centerGravity * (centerY - positions[i].y)
        }

        // 4. DEPTH Y BIAS (all nodes)
        for i in 0..<count {
            let targetY = centerY + Double(positions[i].depth) * settings.depthYSpacing - settings.depthYSpacing
            forces[i].fy += settings.depthYStrength * (targetY - positions[i].y)
        }

        // Integration + convergence check
        var totalKE = 0.0
        for i in 0..<count {
            positions[i].vx = (positions[i].vx + forces[i].fx) * settings.damping
            positions[i].vy = (positions[i].vy + forces[i].fy) * settings.damping
            positions[i].x += positions[i].vx
            positions[i].y += positions[i].vy
            totalKE += positions[i].kineticEnergy
        }

        if totalKE < settings.convergenceThreshold {
            logger.debug("Simulation converged with total KE: \(totalKE)")
            isRunning = false
            simulationTask?.cancel()
            simulationTask = nil
        }
    }

    func addNode(from node: AgentNode) {
        let parentPos = positions.first(where: { $0.id == node.parent?.id })
        let x = (parentPos?.x ?? canvasSize.width / 2) + Double.random(in: -30...30)
        let y = (parentPos?.y ?? canvasSize.height / 2) + Double.random(in: -30...30)

        let newPos = NodePosition(
            id: node.id,
            x: x,
            y: y,
            vx: 0,
            vy: 0,
            depth: node.depth,
            agentType: node.agentType,
            status: node.status,
            parentID: node.parent?.id
        )

        positions.append(newPos)

        if let parentID = node.parent?.id,
           let parentIdx = positions.firstIndex(where: { $0.id == parentID }) {
            let childIdx = positions.count - 1
            edges.append((parentIdx, childIdx))
        }

        if !isRunning {
            isRunning = true
            simulationTask = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled && self.isRunning {
                    self.tick()
                    try? await Task.sleep(for: .seconds(self.settings.tickInterval))
                }
            }
        }
    }
}
