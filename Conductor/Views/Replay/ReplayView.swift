import SwiftUI

struct ReplayView: View {
    let session: Session
    @State private var replayController = ReplayController()

    var body: some View {
        VStack(spacing: 0) {
            if let timeline = replayController.timeline {
                // Timeline scrubber
                TimelineView(
                    timeline: timeline,
                    progress: $replayController.progress,
                    currentEventIndex: replayController.currentEventIndex,
                    onSeek: { position in
                        replayController.seek(to: position)
                    }
                )
                .padding()

                Divider()

                // Current event info
                if let currentEvent = replayController.currentEvent {
                    EventInfoView(event: currentEvent, session: session)
                        .padding()
                } else {
                    Text("No event selected")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Divider()

                // Playback controls
                PlaybackControlsView(
                    controller: replayController,
                    isPlaying: replayController.isPlaying,
                    progress: replayController.formattedProgress,
                    speed: replayController.speed
                )
                .padding()
            } else {
                EmptyStateView(
                    systemImage: "film",
                    title: "No Timeline",
                    subtitle: "Loading session timeline..."
                )
            }
        }
        .onAppear {
            replayController.buildTimeline(for: session)
        }
        .onKeyPress(.space) {
            // Space: play/pause
            if replayController.isPlaying {
                replayController.pause()
            } else {
                replayController.play()
            }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            // Left arrow: seek backward 5s
            replayController.seekBackward()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            // Right arrow: seek forward 5s
            replayController.seekForward()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "+")) { _ in
            // +: increase speed
            let newSpeed = min(replayController.speed * 1.25, 4.0)
            replayController.adjustSpeed(newSpeed)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "-")) { _ in
            // -: decrease speed
            let newSpeed = max(replayController.speed / 1.25, 0.25)
            replayController.adjustSpeed(newSpeed)
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "r")) { _ in
            // r: restart from beginning
            replayController.stop()
            return .handled
        }
        .focusable()
    }
}

struct EventInfoView: View {
    let event: ReplayEventFrame
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForEventType(event.event.eventType))
                    .foregroundColor(colorForEventType(event.event.eventType))
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.description)
                        .font(.headline)

                    Text(formattedTime(event.event.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Event details
            if !event.event.details.isEmpty {
                GroupBox("Details") {
                    ScrollView {
                        Text(event.event.details)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
            }

            // Related node info
            if let nodeID = event.event.nodeID,
               let node = session.nodes.first(where: { $0.id == nodeID }) {
                GroupBox("Node Info") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Name:")
                                .foregroundStyle(.secondary)
                            Text(node.agentName)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Type:")
                                .foregroundStyle(.secondary)
                            Text(node.agentType.rawValue)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("Status:")
                                .foregroundStyle(.secondary)
                            StatusBadge(status: node.status)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func iconForEventType(_ type: ReplayEventType) -> String {
        switch type {
        case .sessionStarted: return "play.circle.fill"
        case .nodeCreated: return "plus.circle.fill"
        case .nodeProgressUpdate: return "arrow.triangle.2.circlepath"
        case .toolCallInitiated: return "hammer.circle.fill"
        case .toolCallCompleted: return "checkmark.circle.fill"
        case .commandExecuted: return "terminal.fill"
        case .sessionCompleted: return "checkmark.seal.fill"
        }
    }

    private func colorForEventType(_ type: ReplayEventType) -> Color {
        switch type {
        case .sessionStarted: return .blue
        case .nodeCreated: return .green
        case .nodeProgressUpdate: return .orange
        case .toolCallInitiated: return .purple
        case .toolCallCompleted: return .green
        case .commandExecuted: return .cyan
        case .sessionCompleted: return .blue
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%d:%02d.%03d", mins, secs, millis)
    }
}
