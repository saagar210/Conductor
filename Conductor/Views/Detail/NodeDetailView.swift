import SwiftUI

struct NodeDetailView: View {
    let node: AgentNode

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            NodeDetailHeader(node: node)
            Divider()

            Picker("Tab", selection: $selectedTab) {
                Text("Task").tag(0)
                Text("Result").tag(1)
                Text("Files").tag(2)
                Text("Commands").tag(3)
                Text("Tools").tag(4)
                Text("Analytics").tag(5)
                Text("Replay").tag(6)
            }
            .pickerStyle(.segmented)
            .padding(8)

            Divider()

            switch selectedTab {
            case 0: TaskTabView(node: node)
            case 1: ResultTabView(node: node)
            case 2: FilesTabView(node: node)
            case 3: CommandsTabView(node: node)
            case 4: ToolsTabView(node: node)
            case 5:
                if let session = node.session {
                    AnalyticsView(session: session)
                } else {
                    EmptyStateView(
                        systemImage: "chart.bar",
                        title: "No Analytics",
                        subtitle: "Session data not available"
                    )
                }
            case 6:
                if let session = node.session {
                    ReplayView(session: session)
                } else {
                    EmptyStateView(
                        systemImage: "film",
                        title: "No Replay",
                        subtitle: "Session data not available"
                    )
                }
            default: TaskTabView(node: node)
            }
        }
        .frame(minWidth: ConductorTheme.detailMinWidth)
    }
}
