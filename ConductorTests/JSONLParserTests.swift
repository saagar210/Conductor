import Testing
import Foundation
@testable import Conductor

@Suite("JSONL Parser Tests")
struct JSONLParserTests {

    @Test("Parse user entry with text content")
    func parseUserEntry() throws {
        let json = """
        {"type":"user","uuid":"abc-123","timestamp":"2026-02-09T07:13:10.022Z","sessionId":"sess-1","isSidechain":false,"userType":"external","cwd":"/Users/d/Projects/Test","slug":"test-slug","message":{"role":"user","content":"Hello world"}}
        """
        let data = json.data(using: .utf8)!
        let entry = JSONLParser.parseLine(data)

        #expect(entry != nil)
        #expect(entry?.type == "user")
        #expect(entry?.uuid == "abc-123")
        #expect(entry?.sessionId == "sess-1")
        #expect(entry?.cwd == "/Users/d/Projects/Test")
        #expect(entry?.slug == "test-slug")
        #expect(entry?.message?.role == "user")
        #expect(entry?.message?.content?.textContent == "Hello world")
        #expect(entry?.parsedTimestamp != nil)
    }

    @Test("Parse assistant entry with tool_use block")
    func parseAssistantWithToolUse() throws {
        let json = """
        {"type":"assistant","uuid":"def-456","timestamp":"2026-02-09T07:14:00.000Z","sessionId":"sess-1","message":{"role":"assistant","content":[{"type":"text","text":"Let me read that file."},{"type":"tool_use","id":"toolu_abc","name":"Read","input":{"file_path":"/src/main.swift"}}]}}
        """
        let data = json.data(using: .utf8)!
        let entry = JSONLParser.parseLine(data)

        #expect(entry != nil)
        #expect(entry?.type == "assistant")
        #expect(entry?.message?.role == "assistant")

        let toolUses = entry?.message?.content?.toolUseBlocks ?? []
        #expect(toolUses.count == 1)
        #expect(toolUses.first?.name == "Read")
        #expect(toolUses.first?.id == "toolu_abc")
        #expect(toolUses.first?.input["file_path"]?.stringValue == "/src/main.swift")

        #expect(entry?.message?.content?.textContent == "Let me read that file.")
    }

    @Test("Parse tool_result block")
    func parseToolResult() throws {
        let json = """
        {"type":"user","uuid":"ghi-789","timestamp":"2026-02-09T07:15:00.000Z","sessionId":"sess-1","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_abc","content":"file contents here","is_error":false}]}}
        """
        let data = json.data(using: .utf8)!
        let entry = JSONLParser.parseLine(data)

        #expect(entry != nil)
        let results = entry?.message?.content?.toolResultBlocks ?? []
        #expect(results.count == 1)
        #expect(results.first?.tool_use_id == "toolu_abc")
        #expect(results.first?.is_error == false)
    }

    @Test("Malformed line is skipped gracefully")
    func malformedLineSkipped() throws {
        // Write a temp file with one good line and one bad line
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).jsonl")
        let content = """
        {"type":"user","uuid":"ok-1","timestamp":"2026-02-09T07:00:00.000Z","sessionId":"s1","message":{"role":"user","content":"good line"}}
        {this is not valid json at all
        {"type":"assistant","uuid":"ok-2","timestamp":"2026-02-09T07:01:00.000Z","sessionId":"s1","message":{"role":"assistant","content":[{"type":"text","text":"response"}]}}
        """
        try content.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let entries = JSONLParser.parse(fileAt: tempFile)
        #expect(entries.count == 2)
        #expect(entries[0].type == "user")
        #expect(entries[1].type == "assistant")
    }

    @Test("Parse system entry with turn_duration")
    func parseSystemEntry() throws {
        let json = """
        {"type":"system","subtype":"turn_duration","durationMs":582577,"uuid":"sys-1","timestamp":"2026-02-09T07:22:52.673Z","sessionId":"sess-1","isMeta":false}
        """
        let data = json.data(using: .utf8)!
        let entry = JSONLParser.parseLine(data)

        #expect(entry != nil)
        #expect(entry?.type == "system")
        #expect(entry?.subtype == "turn_duration")
        #expect(entry?.durationMs == 582577)
    }

    @Test("Parse file-history-snapshot entry")
    func parseFileHistorySnapshot() throws {
        let json = """
        {"type":"file-history-snapshot","messageId":"snap-1","snapshot":{"messageId":"snap-1","trackedFileBackups":{},"timestamp":"2026-02-09T07:13:10.095Z"},"isSnapshotUpdate":false}
        """
        let data = json.data(using: .utf8)!
        let entry = JSONLParser.parseLine(data)

        #expect(entry != nil)
        #expect(entry?.type == "file-history-snapshot")
    }

    @Test("Empty file returns empty array")
    func emptyFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("empty_\(UUID().uuidString).jsonl")
        try "".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let entries = JSONLParser.parse(fileAt: tempFile)
        #expect(entries.isEmpty)
    }
}
