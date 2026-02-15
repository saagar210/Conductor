import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SearchView(sessions: sessions, selectedSessionID: $appState.selectedSessionID)
                .navigationSplitViewColumnWidth(
                    min: ConductorTheme.sidebarMinWidth,
                    ideal: ConductorTheme.sidebarIdealWidth,
                    max: ConductorTheme.sidebarMaxWidth
                )
        } content: {
            if let session = selectedSession {
                GeometryReader { geometry in
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
                    .onAppear {
                        let canvasHeight = max(geometry.size.height - 50, 100)
                        appState.canvasSize = CGSize(width: geometry.size.width, height: canvasHeight)
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        let canvasHeight = max(newSize.height - 50, 100)
                        let newCanvasSize = CGSize(width: newSize.width, height: canvasHeight)
                        appState.canvasSize = newCanvasSize
                        // Reload nodes with new canvas size
                        if let session = selectedSession {
                            appState.simulation.loadNodes(from: session.nodes, canvasSize: newCanvasSize)
                        }
                    }
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
                    canvasSize: appState.canvasSize
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
