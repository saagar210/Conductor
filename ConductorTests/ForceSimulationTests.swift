import Testing
import Foundation
@testable import Conductor

@Suite("ForceSimulation Tests")
struct ForceSimulationTests {

    private func makeNode(
        id: UUID = UUID(),
        parent: AgentNode? = nil,
        agentType: AgentType = .subagent,
        status: AgentNodeStatus = .completed,
        depth: Int = 1
    ) -> AgentNode {
        AgentNode(
            id: id,
            parent: parent,
            agentType: agentType,
            status: status,
            depth: depth
        )
    }

    @Test("Simulation converges within 5 seconds")
    @MainActor
    func simulationConverges() async throws {
        let simulation = ForceSimulation()
        let root = makeNode(agentType: .orchestrator, status: .running, depth: 0)

        let children = (0..<4).map { _ in
            makeNode(parent: root, depth: 1)
        }

        let allNodes = [root] + children
        simulation.loadNodes(from: allNodes, canvasSize: CGSize(width: 800, height: 600))

        // Wait up to 5 seconds for convergence
        let deadline = Date().addingTimeInterval(5.0)
        while simulation.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        #expect(!simulation.isRunning, "Simulation should have converged")
    }

    @Test("No NaN positions after simulation")
    @MainActor
    func noNaNPositions() async throws {
        let simulation = ForceSimulation()
        let root = makeNode(agentType: .orchestrator, depth: 0)
        let nodes = [root] + (0..<9).map { _ in makeNode(parent: root, depth: 1) }

        simulation.loadNodes(from: nodes, canvasSize: CGSize(width: 800, height: 600))

        try await Task.sleep(for: .seconds(2))
        simulation.stop()

        for pos in simulation.positions {
            #expect(!pos.x.isNaN, "X should not be NaN for node \(pos.id)")
            #expect(!pos.y.isNaN, "Y should not be NaN for node \(pos.id)")
            #expect(!pos.x.isInfinite, "X should not be Infinite for node \(pos.id)")
            #expect(!pos.y.isInfinite, "Y should not be Infinite for node \(pos.id)")
        }
    }

    @Test("Nodes do not stack on top of each other")
    @MainActor
    func nodesDoNotStack() async throws {
        let simulation = ForceSimulation()
        let root = makeNode(agentType: .orchestrator, depth: 0)
        let nodes = [root] + (0..<5).map { _ in makeNode(parent: root, depth: 1) }

        simulation.loadNodes(from: nodes, canvasSize: CGSize(width: 800, height: 600))

        try await Task.sleep(for: .seconds(3))
        simulation.stop()

        let positions = simulation.positions
        for i in 0..<positions.count {
            for j in (i + 1)..<positions.count {
                let dx = positions[i].x - positions[j].x
                let dy = positions[i].y - positions[j].y
                let dist = sqrt(dx * dx + dy * dy)
                #expect(dist > 5.0, "Nodes \(i) and \(j) are too close: \(dist)pt")
            }
        }
    }
}
