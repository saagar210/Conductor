import Testing
import Foundation
@testable import Conductor

@Suite("Session Sync Planner Tests")
struct SessionSyncPlannerTests {

    private func makeSession(
        path: String,
        size: Int,
        modifiedDate: Date,
        subagents: [String] = []
    ) -> DiscoveredSession {
        DiscoveredSession(
            projectDir: "-Users-d-Projects-Conductor",
            projectName: "Conductor",
            sessionId: UUID().uuidString,
            logURL: URL(fileURLWithPath: path),
            subagentURLs: subagents.map { URL(fileURLWithPath: $0) },
            fileSize: size,
            modifiedDate: modifiedDate
        )
    }

    @Test("Plan includes new paths")
    func includesNewSessions() {
        let now = Date()
        let discovered = [makeSession(path: "/tmp/a.jsonl", size: 10, modifiedDate: now)]

        let plan = SessionSyncPlanner.plan(discovered: discovered, knownFingerprints: [:])

        #expect(plan.changedSessions.count == 1)
        #expect(plan.changedSessions.first?.logURL.path == "/tmp/a.jsonl")
        #expect(plan.removedLogPaths.isEmpty)
    }

    @Test("Plan detects size and modified date changes")
    func detectsFingerprintChange() {
        let now = Date()
        let old = now.addingTimeInterval(-10)
        let discovered = [makeSession(path: "/tmp/a.jsonl", size: 20, modifiedDate: now)]

        let known: [String: SessionFingerprint] = [
            "/tmp/a.jsonl": SessionFingerprint(
                fileSize: 10,
                modifiedDate: old,
                subagentSignature: ""
            )
        ]

        let plan = SessionSyncPlanner.plan(discovered: discovered, knownFingerprints: known)
        #expect(plan.changedSessions.count == 1)
        #expect(plan.removedLogPaths.isEmpty)
    }

    @Test("Plan excludes unchanged sessions")
    func excludesUnchangedSessions() {
        let now = Date()
        let discovered = [makeSession(path: "/tmp/a.jsonl", size: 10, modifiedDate: now)]

        let known = SessionSyncPlanner.fingerprints(from: discovered)
        let plan = SessionSyncPlanner.plan(discovered: discovered, knownFingerprints: known)

        #expect(plan.changedSessions.isEmpty)
        #expect(plan.removedLogPaths.isEmpty)
    }

    @Test("Plan reports removed log paths")
    func reportsRemovedLogPaths() {
        let now = Date()
        let discovered = [makeSession(path: "/tmp/a.jsonl", size: 10, modifiedDate: now)]

        let known: [String: SessionFingerprint] = [
            "/tmp/a.jsonl": SessionFingerprint(fileSize: 10, modifiedDate: now, subagentSignature: ""),
            "/tmp/b.jsonl": SessionFingerprint(fileSize: 99, modifiedDate: now, subagentSignature: "")
        ]

        let plan = SessionSyncPlanner.plan(discovered: discovered, knownFingerprints: known)
        #expect(plan.changedSessions.isEmpty)
        #expect(plan.removedLogPaths == ["/tmp/b.jsonl"])
    }

    @Test("Plan detects subagent list changes")
    func detectsSubagentChanges() {
        let now = Date()
        let oldDiscovered = [
            makeSession(
                path: "/tmp/a.jsonl",
                size: 10,
                modifiedDate: now,
                subagents: ["/tmp/subagents/agent-1.jsonl"]
            )
        ]
        let newDiscovered = [
            makeSession(
                path: "/tmp/a.jsonl",
                size: 10,
                modifiedDate: now,
                subagents: ["/tmp/subagents/agent-1.jsonl", "/tmp/subagents/agent-2.jsonl"]
            )
        ]

        let known = SessionSyncPlanner.fingerprints(from: oldDiscovered)
        let plan = SessionSyncPlanner.plan(discovered: newDiscovered, knownFingerprints: known)

        #expect(plan.changedSessions.count == 1)
    }

    @Test("Subagent signature is stable regardless of URL order")
    func subagentOrderStability() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-order-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let subA = tempDir.appendingPathComponent("agent-a.jsonl")
        let subB = tempDir.appendingPathComponent("agent-b.jsonl")
        try "a".write(to: subA, atomically: true, encoding: .utf8)
        try "b".write(to: subB, atomically: true, encoding: .utf8)

        let now = Date()
        let one = makeSession(
            path: "/tmp/a.jsonl",
            size: 10,
            modifiedDate: now,
            subagents: [subA.path, subB.path]
        )
        let two = makeSession(
            path: "/tmp/a.jsonl",
            size: 10,
            modifiedDate: now,
            subagents: [subB.path, subA.path]
        )

        let fingerprintsOne = SessionSyncPlanner.fingerprints(from: [one])
        let fingerprintsTwo = SessionSyncPlanner.fingerprints(from: [two])

        #expect(fingerprintsOne[one.logURL.path] == fingerprintsTwo[two.logURL.path])
    }
}
