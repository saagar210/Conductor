import Testing
import Foundation
import SwiftData
@testable import Conductor

@Suite("SwiftData Model Tests")
struct ModelTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Session.self, AgentNode.self, CommandRecord.self, ToolCallRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Create and fetch a session")
    @MainActor
    func createSession() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = Session(name: "Test Session", slug: "test-session")
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Session")
    }

    @Test("Session-Node relationship")
    @MainActor
    func sessionNodeRelationship() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = Session(name: "Rel Test", slug: "rel-test")
        context.insert(session)

        let node = AgentNode(session: session, agentName: "TestNode", depth: 0)
        context.insert(node)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched.first?.nodes.count == 1)

        let fetchedNode = try context.fetch(FetchDescriptor<AgentNode>())
        #expect(fetchedNode.first?.session?.id == session.id)
    }

    @Test("Self-referential parent-child relationship")
    @MainActor
    func selfReferentialParentChild() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = Session(name: "Tree Test", slug: "tree-test")
        context.insert(session)

        let parent = AgentNode(session: session, agentType: .orchestrator, agentName: "Parent", depth: 0)
        context.insert(parent)

        let child = AgentNode(session: session, parent: parent, agentName: "Child", depth: 1)
        context.insert(child)
        try context.save()

        #expect(parent.children.count == 1)
        #expect(child.parent?.id == parent.id)
    }

    @Test("Cascade delete removes nodes")
    @MainActor
    func cascadeDeleteRemovesNodes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = Session(name: "Cascade Test", slug: "cascade-test")
        context.insert(session)

        let node = AgentNode(session: session, agentName: "ToDelete", depth: 0)
        context.insert(node)
        try context.save()

        context.delete(session)
        try context.save()

        let nodeCount = try context.fetchCount(FetchDescriptor<AgentNode>())
        #expect(nodeCount == 0)
    }

    @Test("Tags round-trip through raw storage")
    @MainActor
    func tagsRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = Session(name: "Tags Test", slug: "tags-test")
        session.tags = ["swift", "backend", "auth"]
        context.insert(session)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Session>())
        #expect(fetched.first?.tags == ["swift", "backend", "auth"])
    }

    @Test("Files with special characters preserved")
    @MainActor
    func filesModifiedWithSpecialChars() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let session = Session(name: "Files Test", slug: "files-test")
        context.insert(session)

        let node = AgentNode(session: session, agentName: "FileNode", depth: 0)
        node.filesModified = ["/src/main.ts", "/src/util, special.ts"]
        context.insert(node)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<AgentNode>())
        let files = fetched.first?.filesModified ?? []
        #expect(files.count == 2)
        #expect(files[1] == "/src/util, special.ts")
    }
}
