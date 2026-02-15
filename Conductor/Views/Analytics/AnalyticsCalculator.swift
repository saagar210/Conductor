import Foundation
import SwiftData

struct TokenStats: Sendable {
    let totalTokens: Int
    let avgPerSession: Int
    let avgPerNode: Int
    let range: (min: Int, max: Int)
}

struct ToolPerformance: Sendable, Identifiable {
    var id: String { toolName }
    let toolName: String
    let callCount: Int
    let successRate: Double
    let avgDuration: Double
    let failureCount: Int
}

struct SessionComparison: Sendable {
    let session1: Session
    let session2: Session
    let tokenDifference: Int
    let durationDifference: Double
    let nodeDifference: Int
}

@MainActor
struct AnalyticsCalculator {
    // MARK: - Token Analytics

    static func calculateTokenStats(for sessions: [Session]) -> TokenStats {
        guard !sessions.isEmpty else {
            return TokenStats(
                totalTokens: 0,
                avgPerSession: 0,
                avgPerNode: 0,
                range: (min: 0, max: 0)
            )
        }

        let totalTokens = sessions.reduce(0) { $0 + $1.totalTokens }
        let avgPerSession = totalTokens / sessions.count

        let allNodes = sessions.flatMap { $0.nodes }
        let nodeCount = allNodes.count
        let avgPerNode = nodeCount > 0 ? allNodes.reduce(0) { $0 + $1.tokenCount } / nodeCount : 0

        let tokenCounts = sessions.map { $0.totalTokens }
        let minTokens = tokenCounts.min() ?? 0
        let maxTokens = tokenCounts.max() ?? 0

        return TokenStats(
            totalTokens: totalTokens,
            avgPerSession: avgPerSession,
            avgPerNode: avgPerNode,
            range: (min: minTokens, max: maxTokens)
        )
    }

    static func calculateSessionAnalytics(for session: Session, in context: ModelContext) -> SessionAnalytics {
        let nodeCount = session.nodes.count
        let totalTokens = session.totalTokens
        let avgTokensPerNode = nodeCount > 0 ? totalTokens / nodeCount : 0

        let allCommands = session.nodes.flatMap { $0.commandRecords }
        let commandCount = allCommands.count

        let allTools = session.nodes.flatMap { $0.toolCallRecords }
        let toolCallCount = allTools.count

        let completedNodes = session.nodes.filter { $0.status == .completed }
        let successRate = nodeCount > 0 ? Double(completedNodes.count) / Double(nodeCount) : 0.0

        return SessionAnalytics(
            sessionID: session.id,
            computedAt: Date(),
            totalTokens: totalTokens,
            avgTokensPerNode: avgTokensPerNode,
            nodeCount: nodeCount,
            commandCount: commandCount,
            toolCallCount: toolCallCount,
            successRate: successRate
        )
    }

    // MARK: - Tool Performance Analytics

    static func calculateToolPerformance(for sessions: [Session]) -> [ToolPerformance] {
        var toolMetrics: [String: (calls: Int, successes: Int, totalDuration: Double)] = [:]

        for session in sessions {
            for node in session.nodes {
                // Collect command records (Bash tool)
                for command in node.commandRecords {
                    let toolName = "Bash"
                    var metrics = toolMetrics[toolName] ?? (calls: 0, successes: 0, totalDuration: 0.0)
                    metrics.calls += 1
                    if command.exitCode == 0 {
                        metrics.successes += 1
                    }
                    metrics.totalDuration += command.duration
                    toolMetrics[toolName] = metrics
                }

                // Collect other tool records
                for tool in node.toolCallRecords {
                    let toolName = tool.toolName
                    var metrics = toolMetrics[toolName] ?? (calls: 0, successes: 0, totalDuration: 0.0)
                    metrics.calls += 1
                    if tool.status == .succeeded {
                        metrics.successes += 1
                    }
                    // Note: ToolCallRecord doesn't have duration in current schema
                    // We'll estimate as 0 for now
                    toolMetrics[toolName] = metrics
                }
            }
        }

        return toolMetrics.map { name, metrics in
            let successRate = metrics.calls > 0 ? Double(metrics.successes) / Double(metrics.calls) : 0.0
            let avgDuration = metrics.calls > 0 ? metrics.totalDuration / Double(metrics.calls) : 0.0
            let failureCount = metrics.calls - metrics.successes

            return ToolPerformance(
                toolName: name,
                callCount: metrics.calls,
                successRate: successRate,
                avgDuration: avgDuration,
                failureCount: failureCount
            )
        }.sorted { $0.callCount > $1.callCount }
    }

    static func calculateToolMetric(toolName: String, in sessions: [Session], context: ModelContext) -> ToolMetric {
        var callCount = 0
        var successCount = 0
        var totalDuration = 0.0
        var lastUsed = Date.distantPast

        for session in sessions {
            for node in session.nodes {
                if toolName == "Bash" {
                    for command in node.commandRecords {
                        callCount += 1
                        if command.exitCode == 0 {
                            successCount += 1
                        }
                        totalDuration += command.duration
                        if command.executedAt > lastUsed {
                            lastUsed = command.executedAt
                        }
                    }
                } else {
                    for tool in node.toolCallRecords where tool.toolName == toolName {
                        callCount += 1
                        if tool.status == .succeeded {
                            successCount += 1
                        }
                        if tool.executedAt > lastUsed {
                            lastUsed = tool.executedAt
                        }
                    }
                }
            }
        }

        return ToolMetric(
            toolName: toolName,
            callCount: callCount,
            successCount: successCount,
            totalDuration: totalDuration,
            lastUsed: lastUsed
        )
    }

    // MARK: - Session Comparison

    static func compareSessionsBy sessions: [Session], sortBy: SessionSortCriteria) -> [Session] {
        switch sortBy {
        case .tokens:
            return sessions.sorted { $0.totalTokens > $1.totalTokens }
        case .duration:
            return sessions.sorted { $0.totalDuration > $1.totalDuration }
        case .nodeCount:
            return sessions.sorted { $0.nodes.count > $1.nodes.count }
        case .date:
            return sessions.sorted { $0.startedAt > $1.startedAt }
        }
    }

    static func compareTwo(_ session1: Session, _ session2: Session) -> SessionComparison {
        return SessionComparison(
            session1: session1,
            session2: session2,
            tokenDifference: session1.totalTokens - session2.totalTokens,
            durationDifference: session1.totalDuration - session2.totalDuration,
            nodeDifference: session1.nodes.count - session2.nodes.count
        )
    }

    // MARK: - Time-based Analytics

    static func filterSessionsByDateRange(_ sessions: [Session], range: DateRange) -> [Session] {
        let now = Date()
        let calendar = Calendar.current

        let startDate: Date
        switch range {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .all:
            return sessions
        }

        return sessions.filter { $0.startedAt >= startDate }
    }

    static func calculateTrends(for sessions: [Session], by period: TrendPeriod) -> [(date: Date, value: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            switch period {
            case .daily:
                return calendar.startOfDay(for: session.startedAt)
            case .weekly:
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startedAt)
                return calendar.date(from: components) ?? session.startedAt
            case .monthly:
                let components = calendar.dateComponents([.year, .month], from: session.startedAt)
                return calendar.date(from: components) ?? session.startedAt
            }
        }

        return grouped.map { (date: $0.key, value: $0.value.count) }
            .sorted { $0.date < $1.date }
    }
}

enum SessionSortCriteria {
    case tokens
    case duration
    case nodeCount
    case date
}

enum TrendPeriod {
    case daily
    case weekly
    case monthly
}
