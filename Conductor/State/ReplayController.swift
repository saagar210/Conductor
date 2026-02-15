import Foundation
import SwiftUI

struct ReplayTimeline {
    let sessionID: UUID
    let events: [ReplayEventFrame]
    let totalDuration: Double
    let eventCount: Int
}

struct ReplayEventFrame: Identifiable {
    var id: UUID { event.id }
    let event: ReplayEvent
    let relativeTime: Double // 0.0 to 1.0
    let description: String
}

@Observable
@MainActor
final class ReplayController {
    var isPlaying: Bool = false
    var progress: Double = 0.0 // 0.0 to 1.0
    var speed: Double = 1.0 // Playback speed multiplier
    var currentEventIndex: Int = 0
    var timeline: ReplayTimeline?

    private var playbackTask: Task<Void, Never>?

    // MARK: - Timeline Building

    func buildTimeline(for session: Session) {
        let events = extractEvents(from: session)
        let totalDuration = session.totalDuration

        let frames = events.enumerated().map { index, event in
            let relativeTime = totalDuration > 0 ? event.timestamp / totalDuration : 0.0
            let description = formatEventDescription(event, session: session)

            return ReplayEventFrame(
                event: event,
                relativeTime: relativeTime,
                description: description
            )
        }

        timeline = ReplayTimeline(
            sessionID: session.id,
            events: frames,
            totalDuration: totalDuration,
            eventCount: events.count
        )

        // Reset playback state
        progress = 0.0
        currentEventIndex = 0
        isPlaying = false
    }

    private func extractEvents(from session: Session) -> [ReplayEvent] {
        var events: [ReplayEvent] = []
        let sessionStart = session.startedAt

        // Session started event
        events.append(ReplayEvent(
            sessionID: session.id,
            timestamp: 0.0,
            eventType: .sessionStarted,
            details: session.rootPrompt
        ))

        // Node creation events
        for node in session.nodes.sorted(by: { ($0.startedAt ?? Date.distantPast) < ($1.startedAt ?? Date.distantPast) }) {
            if let nodeStart = node.startedAt {
                let timestamp = nodeStart.timeIntervalSince(sessionStart)

                // Node created
                events.append(ReplayEvent(
                    sessionID: session.id,
                    timestamp: timestamp,
                    eventType: .nodeCreated,
                    nodeID: node.id,
                    details: node.task
                ))

                // Tool calls
                for tool in node.toolCallRecords.sorted(by: { $0.executedAt < $1.executedAt }) {
                    let toolTimestamp = tool.executedAt.timeIntervalSince(sessionStart)

                    events.append(ReplayEvent(
                        sessionID: session.id,
                        timestamp: toolTimestamp,
                        eventType: .toolCallInitiated,
                        nodeID: node.id,
                        details: tool.toolName
                    ))

                    // Tool completed (assume 1 second later if no duration)
                    events.append(ReplayEvent(
                        sessionID: session.id,
                        timestamp: toolTimestamp + 1.0,
                        eventType: .toolCallCompleted,
                        nodeID: node.id,
                        details: tool.toolName
                    ))
                }

                // Commands
                for command in node.commandRecords.sorted(by: { $0.executedAt < $1.executedAt }) {
                    let cmdTimestamp = command.executedAt.timeIntervalSince(sessionStart)

                    events.append(ReplayEvent(
                        sessionID: session.id,
                        timestamp: cmdTimestamp,
                        eventType: .commandExecuted,
                        nodeID: node.id,
                        details: command.command
                    ))
                }

                // Node completion
                if let nodeEnd = node.completedAt {
                    let endTimestamp = nodeEnd.timeIntervalSince(sessionStart)
                    events.append(ReplayEvent(
                        sessionID: session.id,
                        timestamp: endTimestamp,
                        eventType: .nodeProgressUpdate,
                        nodeID: node.id,
                        details: "Completed: \(node.status.rawValue)"
                    ))
                }
            }
        }

        // Session completed event
        if let sessionEnd = session.completedAt {
            let endTimestamp = sessionEnd.timeIntervalSince(sessionStart)
            events.append(ReplayEvent(
                sessionID: session.id,
                timestamp: endTimestamp,
                eventType: .sessionCompleted,
                details: "Status: \(session.status.rawValue)"
            ))
        }

        return events.sorted { $0.timestamp < $1.timestamp }
    }

    private func formatEventDescription(_ event: ReplayEvent, session: Session) -> String {
        switch event.eventType {
        case .sessionStarted:
            return "Session started: \(String(event.details.prefix(50)))"
        case .nodeCreated:
            if let nodeID = event.nodeID,
               let node = session.nodes.first(where: { $0.id == nodeID }) {
                return "Created node: \(node.agentName)"
            }
            return "Node created"
        case .nodeProgressUpdate:
            return "Node updated: \(event.details)"
        case .toolCallInitiated:
            return "Tool initiated: \(event.details)"
        case .toolCallCompleted:
            return "Tool completed: \(event.details)"
        case .commandExecuted:
            return "Command: \(String(event.details.prefix(40)))"
        case .sessionCompleted:
            return "Session completed"
        }
    }

    // MARK: - Playback Control

    func play() {
        guard let timeline = timeline, !timeline.events.isEmpty else { return }
        guard !isPlaying else { return }

        isPlaying = true

        playbackTask = Task { @MainActor in
            while isPlaying && currentEventIndex < timeline.events.count && !Task.isCancelled {
                let event = timeline.events[currentEventIndex]

                // Update progress
                progress = event.relativeTime

                // Wait before next event
                let nextIndex = currentEventIndex + 1
                if nextIndex < timeline.events.count {
                    let nextEvent = timeline.events[nextIndex]
                    let timeDiff = (nextEvent.event.timestamp - event.event.timestamp) / speed
                    let waitTime = max(0.1, timeDiff) // Minimum 100ms

                    try? await Task.sleep(for: .milliseconds(Int(waitTime * 1000)))

                    if !Task.isCancelled {
                        currentEventIndex = nextIndex
                    }
                } else {
                    // Reached end
                    isPlaying = false
                    break
                }
            }

            if currentEventIndex >= timeline.events.count - 1 {
                isPlaying = false
                progress = 1.0
            }
        }
    }

    func pause() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    func stop() {
        pause()
        progress = 0.0
        currentEventIndex = 0
    }

    func seek(to position: Double) {
        guard let timeline = timeline else { return }

        let wasPlaying = isPlaying
        pause()

        progress = max(0.0, min(1.0, position))

        // Find nearest event
        if let index = timeline.events.firstIndex(where: { $0.relativeTime >= progress }) {
            currentEventIndex = index
        } else {
            currentEventIndex = timeline.events.count - 1
        }

        if wasPlaying {
            play()
        }
    }

    func seekForward(seconds: Double = 5.0) {
        guard let timeline = timeline else { return }

        let currentTime = progress * timeline.totalDuration
        let newTime = min(currentTime + seconds, timeline.totalDuration)
        let newProgress = timeline.totalDuration > 0 ? newTime / timeline.totalDuration : 0.0

        seek(to: newProgress)
    }

    func seekBackward(seconds: Double = 5.0) {
        guard let timeline = timeline else { return }

        let currentTime = progress * timeline.totalDuration
        let newTime = max(currentTime - seconds, 0.0)
        let newProgress = timeline.totalDuration > 0 ? newTime / timeline.totalDuration : 0.0

        seek(to: newProgress)
    }

    func adjustSpeed(_ newSpeed: Double) {
        speed = max(0.25, min(4.0, newSpeed))
    }

    // MARK: - Current Event Info

    var currentEvent: ReplayEventFrame? {
        guard let timeline = timeline,
              currentEventIndex >= 0,
              currentEventIndex < timeline.events.count else {
            return nil
        }
        return timeline.events[currentEventIndex]
    }

    var formattedProgress: String {
        guard let timeline = timeline else { return "0:00 / 0:00" }

        let currentSeconds = Int(progress * timeline.totalDuration)
        let totalSeconds = Int(timeline.totalDuration)

        return "\(formatTime(currentSeconds)) / \(formatTime(totalSeconds))"
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
