import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Session.startedAt, order: .reverse) private var allSessions: [Session]

    let session: Session

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("Analytics Type", selection: Binding(
                get: { appState.analyticsTab },
                set: { appState.analyticsTab = $0 }
            )) {
                Text("Tokens").tag(AnalyticsTab.tokens)
                Text("Tools").tag(AnalyticsTab.tools)
                Text("Performance").tag(AnalyticsTab.performance)
                Text("Trends").tag(AnalyticsTab.trends)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Content
            ScrollView {
                switch appState.analyticsTab {
                case .tokens:
                    TokenAnalyzerView(session: session, allSessions: filteredSessions)
                        .padding()

                case .tools:
                    ToolPerformanceView(session: session, allSessions: filteredSessions)
                        .padding()

                case .performance:
                    PerformanceAnalyticsView(session: session)
                        .padding()

                case .trends:
                    TrendsView(sessions: filteredSessions)
                        .padding()
                }
            }
        }
    }

    private var filteredSessions: [Session] {
        AnalyticsCalculator.filterSessionsByDateRange(allSessions, range: appState.selectedDateRange)
    }
}

struct TokenAnalyzerView: View {
    let session: Session
    let allSessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Token Usage Analysis")
                .font(.title2)
                .fontWeight(.bold)

            // Current session stats
            GroupBox("Current Session") {
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(label: "Total Tokens", value: "\(session.totalTokens)")
                    StatRow(label: "Nodes", value: "\(session.nodes.count)")
                    StatRow(label: "Avg Tokens/Node", value: avgTokensPerNode)
                    StatRow(label: "Duration", value: formattedDuration(session.totalDuration))
                    StatRow(label: "Tokens/Second", value: tokensPerSecond)
                }
                .padding(.vertical, 8)
            }

            // Comparison with all sessions
            if allSessions.count > 1 {
                GroupBox("Comparison with All Sessions") {
                    let stats = AnalyticsCalculator.calculateTokenStats(for: allSessions)

                    VStack(alignment: .leading, spacing: 8) {
                        StatRow(label: "Total Across All", value: "\(stats.totalTokens)")
                        StatRow(label: "Average Per Session", value: "\(stats.avgPerSession)")
                        StatRow(label: "Range", value: "\(stats.range.min) - \(stats.range.max)")

                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("This session is")
                                .foregroundStyle(.secondary)
                            Text(comparisonText(stats: stats))
                                .fontWeight(.semibold)
                                .foregroundColor(comparisonColor(stats: stats))
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            // Token distribution chart
            GroupBox("Token Distribution") {
                AnalyticsChartView(
                    data: tokenDistributionData,
                    title: "Tokens by Node",
                    maxValue: session.nodes.map { $0.tokenCount }.max() ?? 1
                )
            }
        }
    }

    private var avgTokensPerNode: String {
        let count = session.nodes.count
        guard count > 0 else { return "0" }
        return "\(session.totalTokens / count)"
    }

    private var tokensPerSecond: String {
        guard session.totalDuration > 0 else { return "0" }
        let rate = Double(session.totalTokens) / session.totalDuration
        return String(format: "%.1f", rate)
    }

    private var tokenDistributionData: [(String, Int)] {
        session.nodes.enumerated().map { index, node in
            let label = node.agentName.isEmpty ? "Node \(index + 1)" : String(node.agentName.prefix(15))
            return (label, node.tokenCount)
        }
    }

    private func comparisonText(stats: TokenStats) -> String {
        let diff = session.totalTokens - stats.avgPerSession
        let percent = abs(diff * 100 / max(stats.avgPerSession, 1))

        if diff > 0 {
            return "\(percent)% above average"
        } else if diff < 0 {
            return "\(percent)% below average"
        } else {
            return "at average"
        }
    }

    private func comparisonColor(stats: TokenStats) -> Color {
        let diff = session.totalTokens - stats.avgPerSession
        if diff > 0 {
            return .orange
        } else if diff < 0 {
            return .green
        } else {
            return .primary
        }
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PerformanceAnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.title2)
                .fontWeight(.bold)

            GroupBox("Node Success Rate") {
                let analytics = AnalyticsCalculator.calculateSessionAnalytics(for: session)

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: analytics.successRate) {
                        HStack {
                            Text("Success Rate")
                            Spacer()
                            Text("\(Int(analytics.successRate * 100))%")
                                .fontWeight(.semibold)
                        }
                    }

                    Divider()
                        .padding(.vertical, 4)

                    StatRow(label: "Total Nodes", value: "\(analytics.nodeCount)")
                    StatRow(label: "Completed", value: "\(Int(Double(analytics.nodeCount) * analytics.successRate))")
                    StatRow(label: "Commands Executed", value: "\(analytics.commandCount)")
                    StatRow(label: "Tool Calls", value: "\(analytics.toolCallCount)")
                }
                .padding(.vertical, 8)
            }

            GroupBox("Node Breakdown") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(AgentNodeStatus.allCases, id: \.self) { status in
                        let count = session.nodes.filter { $0.status == status }.count
                        if count > 0 {
                            HStack {
                                Circle()
                                    .fill(ConductorTheme.nodeColor(for: status))
                                    .frame(width: 8, height: 8)
                                Text(status.rawValue.capitalized)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(count)")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}
