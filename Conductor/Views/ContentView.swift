import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SessionListView(sessions: sessions, selectedSessionID: $appState.selectedSessionID)
                .navigationSplitViewColumnWidth(
                    min: ConductorTheme.sidebarMinWidth,
                    ideal: ConductorTheme.sidebarIdealWidth,
                    max: ConductorTheme.sidebarMaxWidth
                )
        } content: {
            if let session = selectedSession {
                VStack(spacing: 0) {
                    GraphCanvasView(
                        positions: appState.simulation.positions,
                        selectedNodeID: appState.selectedNodeID,
                        onNodeTapped: { id in appState.selectedNodeID = id }
                    )
                    Divider()
                    StatsBarView(session: session)
                        .frame(height: 50)
                }
            } else {
                EmptyStateView(
                    systemImage: "point.3.connected.trianglepath.dotted",
                    title: "No Session Selected",
                    subtitle: "Select a session from the sidebar to view its agent graph"
                )
            }
        } detail: {
            if let node = selectedNode {
                NodeDetailView(node: node)
            } else {
                EmptyStateView(
                    systemImage: "sidebar.right",
                    title: "No Node Selected",
                    subtitle: "Click a node in the graph to see its details"
                )
            }
        }
        .onChange(of: appState.selectedSessionID) { _, newID in
            if let session = sessions.first(where: { $0.id == newID }) {
                appState.simulation.loadNodes(
                    from: session.nodes,
                    canvasSize: CGSize(width: 800, height: 600)
                )
            }
        }
    }

    private var selectedSession: Session? {
        guard let id = appState.selectedSessionID else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    private var selectedNode: AgentNode? {
        guard let id = appState.selectedNodeID,
              let session = selectedSession else { return nil }
        return session.nodes.first(where: { $0.id == id })
    }
}
