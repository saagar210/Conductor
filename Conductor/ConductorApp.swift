import SwiftUI
import SwiftData
import os

@main
struct ConductorApp: App {
    let modelContainer: ModelContainer
    @State private var appState = AppState()

    private let logger = Logger(subsystem: "com.conductor.app", category: "app")

    init() {
        do {
            let schema = Schema([
                Session.self,
                AgentNode.self,
                CommandRecord.self,
                ToolCallRecord.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task { await loadSessions() }
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1400, height: 900)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(
                        #selector(NSSplitViewController.toggleSidebar(_:)), with: nil
                    )
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(after: .newItem) {
                Button("Refresh Sessions") {
                    Task { await refreshSessions() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }

    @MainActor
    private func loadSessions() async {
        let context = modelContainer.mainContext
        let existingCount = (try? context.fetchCount(FetchDescriptor<Session>())) ?? 0
        guard existingCount == 0 else { return }

        await importSessions(into: context)
    }

    @MainActor
    private func refreshSessions() async {
        let context = modelContainer.mainContext
        appState.selectedSessionID = nil
        appState.selectedNodeID = nil

        // Delete all existing data
        try? context.delete(model: ToolCallRecord.self)
        try? context.delete(model: CommandRecord.self)
        try? context.delete(model: AgentNode.self)
        try? context.delete(model: Session.self)
        try? context.save()

        await importSessions(into: context)
    }

    @MainActor
    private func importSessions(into context: ModelContext) async {
        let discovered = SessionDiscovery.discoverAll()
        logger.info("Discovered \(discovered.count) sessions")

        if discovered.isEmpty {
            logger.info("No real sessions found, seeding mock data")
            let session = MockDataFactory.createMockSessions(in: context)
            try? context.save()
            appState.selectedSessionID = session.id
            return
        }

        for session in discovered {
            _ = SessionBuilder.build(from: session, in: context)
        }
        try? context.save()

        // Auto-select most recent session
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        if let newest = try? context.fetch(descriptor).first {
            appState.selectedSessionID = newest.id
        }

        logger.info("Imported \(discovered.count) sessions successfully")
    }
}
