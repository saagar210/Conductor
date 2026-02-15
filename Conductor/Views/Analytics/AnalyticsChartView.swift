import SwiftUI

struct AnalyticsChartView: View {
    let data: [(String, Int)]
    let title: String
    let maxValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 4)
            }

            if data.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.indices, id: \.self) { index in
                        ChartBar(
                            label: data[index].0,
                            value: data[index].1,
                            maxValue: maxValue
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct ChartBar: View {
    let label: String
    let value: Int
    let maxValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption)
                    .lineLimit(1)

                Spacer()

                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                        .cornerRadius(4)

                    // Bar
                    Rectangle()
                        .fill(barColor)
                        .frame(width: barWidth(geometry.size.width), height: 20)
                        .cornerRadius(4)
                }
            }
            .frame(height: 20)
        }
    }

    private func barWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        let ratio = CGFloat(value) / CGFloat(maxValue)
        return totalWidth * ratio
    }

    private var barColor: Color {
        let ratio = Double(value) / Double(max(maxValue, 1))
        if ratio >= 0.7 {
            return .blue
        } else if ratio >= 0.4 {
            return .green
        } else {
            return .orange
        }
    }
}

struct TrendsView: View {
    let sessions: [Session]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Trends")
                .font(.title2)
                .fontWeight(.bold)

            // Daily trends
            GroupBox("Daily Activity") {
                let trends = AnalyticsCalculator.calculateTrends(for: sessions, by: .daily)
                if trends.isEmpty {
                    Text("No data available")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    TrendChart(data: trends, period: .daily)
                }
            }

            // Sessions by status
            GroupBox("Sessions by Status") {
                let statusData = statusDistribution
                if statusData.isEmpty {
                    Text("No sessions")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    AnalyticsChartView(
                        data: statusData,
                        title: "",
                        maxValue: statusData.map { $0.1 }.max() ?? 1
                    )
                }
            }

            // Token usage over time
            GroupBox("Token Usage Trends") {
                let tokenTrends = tokenTrendData
                if tokenTrends.isEmpty {
                    Text("No data available")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(tokenTrends.indices, id: \.self) { index in
                            let trend = tokenTrends[index]
                            HStack {
                                Text(formattedDate(trend.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text("\(trend.tokens) tokens")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var statusDistribution: [(String, Int)] {
        var counts: [SessionStatus: Int] = [:]
        for session in sessions {
            counts[session.status, default: 0] += 1
        }
        return counts.map { ($0.key.rawValue.capitalized, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    private var tokenTrendData: [(date: Date, tokens: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        return grouped.map { date, sessions in
            let totalTokens = sessions.reduce(0) { $0 + $1.totalTokens }
            return (date: date, tokens: totalTokens)
        }.sorted { $0.date > $1.date }
        .prefix(10)
        .reversed()
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TrendChart: View {
    let data: [(date: Date, value: Int)]
    let period: TrendPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if data.isEmpty {
                Text("No data")
                    .foregroundStyle(.secondary)
            } else {
                let maxValue = data.map { $0.value }.max() ?? 1

                VStack(spacing: 4) {
                    ForEach(data.indices, id: \.self) { index in
                        let item = data[index]
                        HStack {
                            Text(formattedDate(item.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 16)
                                        .cornerRadius(3)

                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: barWidth(item.value, max: maxValue, total: geometry.size.width), height: 16)
                                        .cornerRadius(3)
                                }
                            }
                            .frame(height: 16)

                            Text("\(item.value)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func barWidth(_ value: Int, max maxValue: Int, total: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        return total * CGFloat(value) / CGFloat(maxValue)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch period {
        case .daily:
            formatter.dateFormat = "MMM d"
        case .weekly:
            formatter.dateFormat = "MMM d"
        case .monthly:
            formatter.dateFormat = "MMM yyyy"
        }
        return formatter.string(from: date)
    }
}
