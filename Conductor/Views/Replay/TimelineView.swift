import SwiftUI

struct TimelineView: View {
    let timeline: ReplayTimeline
    @Binding var progress: Double
    let currentEventIndex: Int
    let onSeek: (Double) -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Timeline - \(timeline.eventCount) events")
                .font(.headline)

            // Event markers
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 40)
                        .cornerRadius(8)

                    // Progress fill
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: geometry.size.width * progress, height: 40)
                        .cornerRadius(8)

                    // Event markers
                    ForEach(timeline.events.indices, id: \.self) { index in
                        let event = timeline.events[index]
                        let xPosition = geometry.size.width * event.relativeTime

                        Circle()
                            .fill(colorForEvent(event.event.eventType))
                            .frame(width: index == currentEventIndex ? 12 : 8,
                                   height: index == currentEventIndex ? 12 : 8)
                            .position(x: xPosition, y: 20)
                            .shadow(radius: index == currentEventIndex ? 3 : 0)
                            .animation(.easeInOut(duration: 0.2), value: currentEventIndex)
                    }

                    // Playhead
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 3, height: 50)
                        .position(x: geometry.size.width * progress, y: 20)
                        .shadow(radius: 2)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                            progress = newProgress
                        }
                        .onEnded { value in
                            isDragging = false
                            let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                            onSeek(newProgress)
                        }
                )
            }
            .frame(height: 40)

            // Event list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(timeline.events.indices, id: \.self) { index in
                        EventMarkerButton(
                            event: timeline.events[index],
                            index: index,
                            isActive: index == currentEventIndex,
                            onTap: {
                                onSeek(timeline.events[index].relativeTime)
                            }
                        )
                    }
                }
            }
        }
    }

    private func colorForEvent(_ type: ReplayEventType) -> Color {
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
}

struct EventMarkerButton: View {
    let event: ReplayEventFrame
    let index: Int
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: iconForEventType(event.event.eventType))
                    .font(.caption)
                    .foregroundColor(isActive ? .white : colorForEvent(event.event.eventType))

                Text("#\(index + 1)")
                    .font(.caption2)
                    .foregroundColor(isActive ? .white : .secondary)
            }
            .padding(8)
            .background(isActive ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(colorForEvent(event.event.eventType), lineWidth: isActive ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconForEventType(_ type: ReplayEventType) -> String {
        switch type {
        case .sessionStarted: return "play.circle"
        case .nodeCreated: return "plus.circle"
        case .nodeProgressUpdate: return "arrow.triangle.2.circlepath"
        case .toolCallInitiated: return "hammer"
        case .toolCallCompleted: return "checkmark.circle"
        case .commandExecuted: return "terminal"
        case .sessionCompleted: return "checkmark.seal"
        }
    }

    private func colorForEvent(_ type: ReplayEventType) -> Color {
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
}
