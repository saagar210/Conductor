import XCTest
import SwiftData
@testable import Conductor

@MainActor
final class ReplayControllerTests: XCTestCase {
    var replayController: ReplayController!

    override func setUp() async throws {
        replayController = ReplayController()
    }

    override func tearDown() async throws {
        replayController.stop()
        replayController = nil
    }

    func testBuildTimeline() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        XCTAssertNotNil(replayController.timeline)
        XCTAssertGreaterThan(replayController.timeline!.eventCount, 0)
        XCTAssertEqual(replayController.timeline!.sessionID, session.id)
    }

    func testInitialState() throws {
        XCTAssertFalse(replayController.isPlaying)
        XCTAssertEqual(replayController.progress, 0.0)
        XCTAssertEqual(replayController.speed, 1.0)
        XCTAssertEqual(replayController.currentEventIndex, 0)
    }

    func testPlayPause() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        // Test play
        replayController.play()
        XCTAssertTrue(replayController.isPlaying)

        // Test pause
        replayController.pause()
        XCTAssertFalse(replayController.isPlaying)
    }

    func testStop() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)
        replayController.play()

        replayController.stop()

        XCTAssertFalse(replayController.isPlaying)
        XCTAssertEqual(replayController.progress, 0.0)
        XCTAssertEqual(replayController.currentEventIndex, 0)
    }

    func testSeek() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        replayController.seek(to: 0.5)

        XCTAssertEqual(replayController.progress, 0.5, accuracy: 0.01)
        XCTAssertGreaterThan(replayController.currentEventIndex, 0)
    }

    func testSeekBounds() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        // Test lower bound
        replayController.seek(to: -0.5)
        XCTAssertEqual(replayController.progress, 0.0)

        // Test upper bound
        replayController.seek(to: 1.5)
        XCTAssertEqual(replayController.progress, 1.0)
    }

    func testSeekForwardBackward() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        let initialProgress = replayController.progress

        // Seek forward
        replayController.seekForward(seconds: 5.0)
        XCTAssertGreaterThan(replayController.progress, initialProgress)

        // Seek backward
        let forwardProgress = replayController.progress
        replayController.seekBackward(seconds: 5.0)
        XCTAssertLessThan(replayController.progress, forwardProgress)
    }

    func testSpeedAdjustment() throws {
        replayController.adjustSpeed(2.0)
        XCTAssertEqual(replayController.speed, 2.0)

        // Test lower bound
        replayController.adjustSpeed(0.1)
        XCTAssertEqual(replayController.speed, 0.25)

        // Test upper bound
        replayController.adjustSpeed(5.0)
        XCTAssertEqual(replayController.speed, 4.0)
    }

    func testCurrentEvent() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        let currentEvent = replayController.currentEvent
        XCTAssertNotNil(currentEvent)
        XCTAssertEqual(currentEvent!.event.eventType, .sessionStarted)
    }

    func testFormattedProgress() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        let formatted = replayController.formattedProgress
        XCTAssertTrue(formatted.contains("/"))
        XCTAssertTrue(formatted.contains(":"))
    }

    func testEventOrdering() throws {
        let context = createInMemoryContext()
        let session = createMockSessionForReplay(in: context)

        replayController.buildTimeline(for: session, in: context)

        guard let timeline = replayController.timeline else {
            XCTFail("Timeline not created")
            return
        }

        // Events should be sorted by timestamp
        for i in 0..<(timeline.events.count - 1) {
            XCTAssertLessThanOrEqual(
                timeline.events[i].event.timestamp,
                timeline.events[i + 1].event.timestamp
            )
        }
    }

    // MARK: - Helper Methods

    private func createInMemoryContext() -> ModelContext {
        let schema = Schema([
            Session.self,
            AgentNode.self,
            CommandRecord.self,
            ToolCallRecord.self,
            ReplayEvent.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func createMockSessionForReplay(in context: ModelContext) -> Session {
        let session = Session(
            id: UUID(),
            name: "Replay Session",
            slug: "replay",
            sourceDir: "/test",
            logPath: "/test/replay.jsonl",
            rootPrompt: "Test replay",
            status: .completed,
            startedAt: Date(),
            completedAt: Date().addingTimeInterval(60),
            totalTokens: 5000,
            totalDuration: 60.0
        )
        context.insert(session)

        // Create nodes with timestamps
        for i in 0..<3 {
            let node = AgentNode(
                id: UUID(),
                agentType: .subagent,
                agentName: "Node \(i)",
                task: "Task \(i)",
                status: .completed,
                startedAt: Date().addingTimeInterval(Double(i * 10)),
                completedAt: Date().addingTimeInterval(Double(i * 10 + 5)),
                tokenCount: 1000
            )
            node.session = session
            context.insert(node)

            // Add a command
            let cmd = CommandRecord(
                id: UUID(),
                command: "echo test \(i)",
                exitCode: 0,
                duration: 0.5,
                executedAt: Date().addingTimeInterval(Double(i * 10 + 2))
            )
            cmd.node = node
            context.insert(cmd)
        }

        return session
    }
}
