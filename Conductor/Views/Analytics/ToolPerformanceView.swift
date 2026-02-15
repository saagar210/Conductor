import SwiftUI
import SwiftData

struct ToolPerformanceView: View {
    let session: Session
    let allSessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tool Performance")
                .font(.title2)
                .fontWeight(.bold)

            // Current session tools
            GroupBox("Tools Used in This Session") {
                if toolsInSession.isEmpty {
                    Text("No tools used")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(toolsInSession, id: \.toolName) { tool in
                            ToolPerformanceRow(performance: tool)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // All sessions tools
            if allSessions.count > 1 {
                GroupBox("Tools Across All Sessions") {
                    let allTools = AnalyticsCalculator.calculateToolPerformance(for: allSessions)

                    if allTools.isEmpty {
                        Text("No tools used")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(allTools.prefix(10)) { tool in
                                ToolPerformanceRow(performance: tool)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }

            // Top performing tools
            GroupBox("Top Performing Tools") {
                let allTools = AnalyticsCalculator.calculateToolPerformance(for: allSessions)
                let topTools = allTools.sorted { $0.successRate > $1.successRate }.prefix(5)

                if topTools.isEmpty {
                    Text("No data available")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(topTools), id: \.toolName) { tool in
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)

                                Text(tool.toolName)
                                    .fontWeight(.medium)

                                Spacer()

                                Text("\(Int(tool.successRate * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var toolsInSession: [ToolPerformance] {
        AnalyticsCalculator.calculateToolPerformance(for: [session])
    }
}

struct ToolPerformanceRow: View {
    let performance: ToolPerformance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(performance.toolName)
                    .fontWeight(.medium)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: successIcon)
                        .foregroundColor(successColor)
                        .font(.caption)

                    Text("\(Int(performance.successRate * 100))%")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }

            HStack(spacing: 12) {
                Label("\(performance.callCount) calls", systemImage: "phone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if performance.failureCount > 0 {
                    Label("\(performance.failureCount) failures", systemImage: "xmark.circle")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                if performance.avgDuration > 0 {
                    Label(String(format: "%.2fs avg", performance.avgDuration), systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Success rate bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)

                    Rectangle()
                        .fill(successColor)
                        .frame(width: geometry.size.width * performance.successRate, height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 4)
    }

    private var successIcon: String {
        if performance.successRate >= 0.9 {
            return "checkmark.circle.fill"
        } else if performance.successRate >= 0.7 {
            return "checkmark.circle"
        } else {
            return "exclamationmark.triangle"
        }
    }

    private var successColor: Color {
        if performance.successRate >= 0.9 {
            return .green
        } else if performance.successRate >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}
