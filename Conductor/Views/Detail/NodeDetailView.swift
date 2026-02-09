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
            default: TaskTabView(node: node)
            }
        }
        .frame(minWidth: ConductorTheme.detailMinWidth)
    }
}
