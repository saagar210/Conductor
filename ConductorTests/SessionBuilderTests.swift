import Testing
import Foundation
import SwiftData
@testable import Conductor

@Suite("Session Builder Tests")
struct SessionBuilderTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Session.self, AgentNode.self, CommandRecord.self, ToolCallRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeTempJSONL(lines: [String]) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let file = tempDir.appendingPathComponent("\(UUID().uuidString).jsonl")
        let content = lines.joined(separator: "\n")
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    // MARK: - Session Building

    @Test("Build session from minimal log entries")
    @MainActor
    func buildSessionFromMinimalEntries() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let lines = [
            """
            {"type":"user","uuid":"u1","timestamp":"2026-02-09T07:00:00.000Z","sessionId":"s1","cwd":"/Users/d/Projects/Test","slug":"test-slug","message":{"role":"user","content":"Build a hello world app"}}
            """,
            """
            {"type":"assistant","uuid":"a1","timestamp":"2026-02-09T07:01:00.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"text","text":"I will build the app now."}],"usage":{"input_tokens":100,"output_tokens":50}}}
            """,
            """
            {"type":"system","subtype":"turn_duration","durationMs":60000,"uuid":"sys1","timestamp":"2026-02-09T07:02:00.000Z","sessionId":"s1"}
            """,
        ]

        let logURL = try makeTempJSONL(lines: lines)
        defer { try? FileManager.default.removeItem(at: logURL) }

        let discovered = DiscoveredSession(
            projectDir: "-Users-d-Projects-Test",
            projectName: "Test",
            sessionId: "s1",
            logURL: logURL,
            subagentURLs: [],
            fileSize: 1000,
            modifiedDate: Date()
        )

        let session = SessionBuilder.build(from: discovered, in: context)

        #expect(session != nil)
        #expect(session?.name == "Build a hello world app")
        #expect(session?.slug == "test-slug")
        #expect(session?.status == .completed)
        #expect(session?.totalDuration == 60.0)
        #expect(session?.nodes.count == 1) // root orchestrator

        let rootNode = session?.nodes.first
        #expect(rootNode?.agentType == .orchestrator)
        #expect(rootNode?.depth == 0)
    }

    @Test("Tool calls extracted from log entries")
    @MainActor
    func toolCallsExtracted() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let lines = [
            """
            {"type":"user","uuid":"u1","timestamp":"2026-02-09T07:00:00.000Z","sessionId":"s1","cwd":"/test","slug":"slug","message":{"role":"user","content":"Read the file"}}
            """,
            """
            {"type":"assistant","uuid":"a1","timestamp":"2026-02-09T07:00:01.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"Read","input":{"file_path":"/src/main.swift"}}]}}
            """,
            """
            {"type":"user","uuid":"u2","timestamp":"2026-02-09T07:00:02.000Z","sessionId":"s1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"file contents","is_error":false}]}}
            """,
            """
            {"type":"assistant","uuid":"a2","timestamp":"2026-02-09T07:00:03.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"text","text":"Done reading."}]}}
            """,
        ]

        let logURL = try makeTempJSONL(lines: lines)
        defer { try? FileManager.default.removeItem(at: logURL) }

        let discovered = DiscoveredSession(
            projectDir: "-Test",
            projectName: "Test",
            sessionId: "s1",
            logURL: logURL,
            subagentURLs: [],
            fileSize: 500,
            modifiedDate: Date()
        )

        let session = SessionBuilder.build(from: discovered, in: context)
        #expect(session != nil)

        let toolCalls = try context.fetch(FetchDescriptor<ToolCallRecord>())
        #expect(toolCalls.count == 1)
        #expect(toolCalls.first?.toolName == "Read")
        #expect(toolCalls.first?.status == .succeeded)
    }

    @Test("Bash commands create CommandRecords")
    @MainActor
    func bashCommandsExtracted() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let lines = [
            """
            {"type":"user","uuid":"u1","timestamp":"2026-02-09T07:00:00.000Z","sessionId":"s1","cwd":"/test","slug":"slug","message":{"role":"user","content":"Run ls"}}
            """,
            """
            {"type":"assistant","uuid":"a1","timestamp":"2026-02-09T07:00:01.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_bash1","name":"Bash","input":{"command":"ls -la"}}]}}
            """,
            """
            {"type":"user","uuid":"u2","timestamp":"2026-02-09T07:00:02.000Z","sessionId":"s1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_bash1","content":"file1.txt\\nfile2.txt","is_error":false}]}}
            """,
        ]

        let logURL = try makeTempJSONL(lines: lines)
        defer { try? FileManager.default.removeItem(at: logURL) }

        let discovered = DiscoveredSession(
            projectDir: "-Test",
            projectName: "Test",
            sessionId: "s1",
            logURL: logURL,
            subagentURLs: [],
            fileSize: 500,
            modifiedDate: Date()
        )

        let session = SessionBuilder.build(from: discovered, in: context)
        #expect(session != nil)

        let commands = try context.fetch(FetchDescriptor<CommandRecord>())
        #expect(commands.count == 1)
        #expect(commands.first?.command == "ls -la")
        #expect(commands.first?.exitCode == 0)
    }

    @Test("Failed tool call marked as failed")
    @MainActor
    func failedToolCall() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let lines = [
            """
            {"type":"user","uuid":"u1","timestamp":"2026-02-09T07:00:00.000Z","sessionId":"s1","cwd":"/test","slug":"slug","message":{"role":"user","content":"Edit file"}}
            """,
            """
            {"type":"assistant","uuid":"a1","timestamp":"2026-02-09T07:00:01.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_edit1","name":"Edit","input":{"file_path":"/missing.txt","old_string":"x","new_string":"y"}}]}}
            """,
            """
            {"type":"user","uuid":"u2","timestamp":"2026-02-09T07:00:02.000Z","sessionId":"s1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_edit1","content":"File not found","is_error":true}]}}
            """,
        ]

        let logURL = try makeTempJSONL(lines: lines)
        defer { try? FileManager.default.removeItem(at: logURL) }

        let discovered = DiscoveredSession(
            projectDir: "-Test",
            projectName: "Test",
            sessionId: "s1",
            logURL: logURL,
            subagentURLs: [],
            fileSize: 500,
            modifiedDate: Date()
        )

        _ = SessionBuilder.build(from: discovered, in: context)

        let toolCalls = try context.fetch(FetchDescriptor<ToolCallRecord>())
        #expect(toolCalls.count == 1)
        #expect(toolCalls.first?.status == .failed)
    }

    @Test("Session with subagent creates child node")
    @MainActor
    func subagentCreatesChildNode() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Main session log
        let mainLines = [
            """
            {"type":"user","uuid":"u1","timestamp":"2026-02-09T07:00:00.000Z","sessionId":"s1","cwd":"/test","slug":"slug","message":{"role":"user","content":"Research something"}}
            """,
            """
            {"type":"assistant","uuid":"a1","timestamp":"2026-02-09T07:00:01.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_task1","name":"Task","input":{"description":"Research the topic","subagent_type":"Explore","prompt":"Find info about X"}}]}}
            """,
            """
            {"type":"assistant","uuid":"a2","timestamp":"2026-02-09T07:00:30.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"text","text":"Done."}]}}
            """,
        ]

        // Subagent log
        let subLines = [
            """
            {"type":"user","uuid":"su1","timestamp":"2026-02-09T07:00:02.000Z","sessionId":"s1","agentId":"abc1234","message":{"role":"user","content":"Find info about X"}}
            """,
            """
            {"type":"assistant","uuid":"sa1","timestamp":"2026-02-09T07:00:10.000Z","sessionId":"s1","agentId":"abc1234","message":{"role":"assistant","content":[{"type":"text","text":"Here is the info."}],"usage":{"input_tokens":50,"output_tokens":30}}}
            """,
        ]

        let mainURL = try makeTempJSONL(lines: mainLines)
        let subURL = try makeTempJSONL(lines: subLines)
        // Rename subagent file to agent-abc1234.jsonl
        let subDir = subURL.deletingLastPathComponent()
        let renamedSub = subDir.appendingPathComponent("agent-abc1234.jsonl")
        try FileManager.default.moveItem(at: subURL, to: renamedSub)

        defer {
            try? FileManager.default.removeItem(at: mainURL)
            try? FileManager.default.removeItem(at: renamedSub)
        }

        let discovered = DiscoveredSession(
            projectDir: "-Test",
            projectName: "Test",
            sessionId: "s1",
            logURL: mainURL,
            subagentURLs: [renamedSub],
            fileSize: 500,
            modifiedDate: Date()
        )

        let session = SessionBuilder.build(from: discovered, in: context)
        #expect(session != nil)

        let nodes = try context.fetch(FetchDescriptor<AgentNode>())
        #expect(nodes.count == 2) // root + 1 subagent

        let rootNode = nodes.first { $0.agentType == .orchestrator }
        let subNode = nodes.first { $0.agentType == .subagent }

        #expect(rootNode != nil)
        #expect(subNode != nil)
        #expect(subNode?.depth == 1)
        #expect(subNode?.parent?.id == rootNode?.id)
        #expect(subNode?.agentName == "Research the topic")
    }

    @Test("Empty session file returns nil")
    @MainActor
    func emptySessionReturnsNil() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let logURL = try makeTempJSONL(lines: [])
        defer { try? FileManager.default.removeItem(at: logURL) }

        let discovered = DiscoveredSession(
            projectDir: "-Test",
            projectName: "Test",
            sessionId: "s1",
            logURL: logURL,
            subagentURLs: [],
            fileSize: 0,
            modifiedDate: Date()
        )

        let session = SessionBuilder.build(from: discovered, in: context)
        #expect(session == nil)
    }

    // MARK: - Session Discovery

    @Test("Project name extraction from directory name")
    func projectNameExtraction() {
        #expect(SessionDiscovery.projectName(from: "-Users-d-Projects-Conductor") == "Conductor")
        #expect(SessionDiscovery.projectName(from: "-Users-d-Projects-my-cool-app") == "my-cool-app")
        #expect(SessionDiscovery.projectName(from: "-Users-d-claude-code") == "code")
        #expect(SessionDiscovery.projectName(from: "standalone") == "standalone")
    }
}
