import SwiftUI

struct PlaybackControlsView: View {
    @Bindable var controller: ReplayController
    let isPlaying: Bool
    let progress: String
    let speed: Double

    var body: some View {
        VStack(spacing: 12) {
            // Progress display
            Text(progress)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            // Main controls
            HStack(spacing: 20) {
                // Skip back button
                Button(action: {
                    controller.seekBackward()
                }) {
                    Image(systemName: "gobackward.5")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Seek backward 5 seconds")

                // Play/Pause button
                Button(action: {
                    if isPlaying {
                        controller.pause()
                    } else {
                        controller.play()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help(isPlaying ? "Pause" : "Play")

                // Skip forward button
                Button(action: {
                    controller.seekForward()
                }) {
                    Image(systemName: "goforward.5")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help("Seek forward 5 seconds")

                Spacer()

                // Stop button
                Button(action: {
                    controller.stop()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Stop and reset")
            }

            // Speed controls
            HStack(spacing: 12) {
                Text("Speed:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach([0.25, 0.5, 1.0, 1.5, 2.0, 4.0], id: \.self) { speedValue in
                    Button(action: {
                        controller.adjustSpeed(speedValue)
                    }) {
                        Text("\(speedValue, specifier: "%.2g")×")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(abs(speed - speedValue) < 0.01 ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                            .foregroundColor(abs(speed - speedValue) < 0.01 ? .white : .primary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Keyboard shortcuts hint
            HStack(spacing: 16) {
                KeyboardShortcutHint(key: "Space", action: "Play/Pause")
                KeyboardShortcutHint(key: "←", action: "Back 5s")
                KeyboardShortcutHint(key: "→", action: "Forward 5s")
                KeyboardShortcutHint(key: "+/-", action: "Speed")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }
}

struct KeyboardShortcutHint: View {
    let key: String
    let action: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Text(action)
        }
    }
}
