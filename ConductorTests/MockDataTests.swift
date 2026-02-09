import Testing
import Foundation
import SwiftData
@testable import Conductor

@Suite("Mock Data Tests")
struct MockDataTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Session.self, AgentNode.self, CommandRecord.self, ToolCallRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("All node statuses are present in mock data")
    @MainActor
    func allNodeStatusesPresent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = MockDataFactory.createMockSessions(in: context)
        try context.save()

        let nodes = try context.fetch(FetchDescriptor<AgentNode>())
        let statuses = Set(nodes.map(\.status))

        #expect(statuses.contains(.pending))
        #expect(statuses.contains(.running))
        #expect(statuses.contains(.completed))
        #expect(statuses.contains(.failed))
    }

    @Test("Tool calls exist with expected tool names")
    @MainActor
    func toolCallsExist() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = MockDataFactory.createMockSessions(in: context)
        try context.save()

        let tools = try context.fetch(FetchDescriptor<ToolCallRecord>())
        #expect(tools.count > 20)

        let toolNames = Set(tools.map(\.toolName))
        #expect(toolNames.contains("Read"))
        #expect(toolNames.contains("Write"))
        #expect(toolNames.contains("Bash"))
        #expect(toolNames.contains("Grep"))
        #expect(toolNames.contains("Glob"))
        #expect(toolNames.contains("Edit"))
    }

    @Test("At least one command failure exists")
    @MainActor
    func commandFailureExists() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = MockDataFactory.createMockSessions(in: context)
        try context.save()

        let commands = try context.fetch(FetchDescriptor<CommandRecord>())
        let hasFailure = commands.contains { $0.exitCode != 0 }
        #expect(hasFailure, "Should have at least one failed command")
    }

    @Test("Relationship integrity is maintained")
    @MainActor
    func relationshipIntegrity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = MockDataFactory.createMockSessions(in: context)
        try context.save()

        let nodes = try context.fetch(FetchDescriptor<AgentNode>())
        for node in nodes {
            #expect(node.session != nil, "Node \(node.agentName) should have a session")
            if node.depth > 0 {
                #expect(node.parent != nil, "Node \(node.agentName) at depth \(node.depth) should have a parent")
            }
        }

        let tools = try context.fetch(FetchDescriptor<ToolCallRecord>())
        for tool in tools {
            #expect(tool.node != nil, "ToolCallRecord should have a node")
        }

        let commands = try context.fetch(FetchDescriptor<CommandRecord>())
        for cmd in commands {
            #expect(cmd.node != nil, "CommandRecord should have a node")
        }
    }

    @Test("Two sessions are created")
    @MainActor
    func twoSessionsCreated() throws {
        let container = try makeContainer()
        let context = container.mainContext
        _ = MockDataFactory.createMockSessions(in: context)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(sessions.count == 2)
    }
}
