import SwiftUI
import SwiftData
import os

@main
struct ConductorApp: App {
    let modelContainer: ModelContainer
    @State private var appState = AppState()
    @State private var sessionFingerprints: [String: SessionFingerprint] = [:]
    @State private var monitorTask: Task<Void, Never>?
    @State private var logMonitor = LogMonitor()

    private let logger = Logger(subsystem: "com.conductor.app", category: "app")

    init() {
        do {
            let schema = Schema([
                Session.self,
                AgentNode.self,
                CommandRecord.self,
                ToolCallRecord.self,
                SearchHistory.self,
                SessionAnalytics.self,
                ReplayEvent.self,
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
                .task {
                    await loadSessions()
                    startMonitoringIfNeeded()
                }
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
        guard existingCount == 0 else {
            let discovered = SessionDiscovery.discoverAll()
            sessionFingerprints = SessionSyncPlanner.fingerprints(from: discovered)
            return
        }

        await importSessions(into: context)
    }

    @MainActor
    private func refreshSessions() async {
        stopMonitoring()

        let context = modelContainer.mainContext
        appState.selectedSessionID = nil
        appState.selectedNodeID = nil
        sessionFingerprints = [:]

        try? context.delete(model: ToolCallRecord.self)
        try? context.delete(model: CommandRecord.self)
        try? context.delete(model: AgentNode.self)
        try? context.delete(model: Session.self)
        try? context.save()

        await importSessions(into: context)
        startMonitoringIfNeeded()
    }

    @MainActor
    private func importSessions(into context: ModelContext) async {
        let discovered = SessionDiscovery.discoverAll()
        logger.info("Discovered \(discovered.count) sessions")
        sessionFingerprints = SessionSyncPlanner.fingerprints(from: discovered)

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

        selectNewestSession(in: context)
        logger.info("Imported \(discovered.count) sessions successfully")
    }

    @MainActor
    private func startMonitoringIfNeeded() {
        guard monitorTask == nil else { return }

        // Set up log monitors for discovered sessions
        let discovered = SessionDiscovery.discoverAll()
        for session in discovered {
            let logPath = session.logURL.path
            do {
                try logMonitor.startMonitoring(path: logPath)
                logger.info("Started monitoring: \(logPath)")
            } catch {
                logger.error("Failed to monitor \(logPath): \(error.localizedDescription)")
            }
        }

        monitorTask = Task { @MainActor in
            while !Task.isCancelled {
                await syncDiscoveredSessions()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @MainActor
    private func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        logMonitor.stopAll()
        logger.info("Stopped all monitoring")
    }

    @MainActor
    private func syncDiscoveredSessions() async {
        let context = modelContainer.mainContext
        let discovered = SessionDiscovery.discoverAll()
        let plan = SessionSyncPlanner.plan(
            discovered: discovered,
            knownFingerprints: sessionFingerprints
        )

        // Check for new entries in monitored files
        var hasNewEntries = false
        for path in logMonitor.monitoredPaths() {
            do {
                let newLines = try logMonitor.checkForNewEntries(path: path)
                if !newLines.isEmpty {
                    hasNewEntries = true
                    logger.debug("Detected \(newLines.count) new lines in \(path)")
                }
            } catch {
                logger.error("Error checking \(path): \(error.localizedDescription)")
            }
        }

        guard !plan.isEmpty || hasNewEntries else { return }

        let allSessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []

        // Remove sessions no longer on disk.
        let sessionsByPath = Dictionary(uniqueKeysWithValues: allSessions.map { ($0.logPath, $0) })
        for removedPath in plan.removedLogPaths {
            guard let existing = sessionsByPath[removedPath] else { continue }
            if existing.id == appState.selectedSessionID {
                appState.selectedSessionID = nil
            }
            context.delete(existing)
        }

        // If real sessions now exist, remove mock fallback records.
        if !discovered.isEmpty {
            let mockSessions = allSessions.filter { $0.logPath.hasPrefix("~/.claude/projects/") }
            for mock in mockSessions {
                context.delete(mock)
            }
        }

        // Rebuild changed/new sessions.
        let postDeleteSessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        for discoveredSession in plan.changedSessions {
            let existing = postDeleteSessions.first(where: { $0.logPath == discoveredSession.logURL.path })
            let wasSelected = existing?.id == appState.selectedSessionID

            if let existing {
                context.delete(existing)
            }

            if let rebuilt = SessionBuilder.build(from: discoveredSession, in: context), wasSelected {
                appState.selectedSessionID = rebuilt.id
            }
        }

        try? context.save()

        if appState.selectedSessionID == nil {
            selectNewestSession(in: context)
        }

        sessionFingerprints = SessionSyncPlanner.fingerprints(from: discovered)
        logger.info(
            "Live sync updated \(plan.changedSessions.count) changed sessions; removed \(plan.removedLogPaths.count)"
        )
    }

    @MainActor
    private func selectNewestSession(in context: ModelContext) {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        if let newest = try? context.fetch(descriptor).first {
            appState.selectedSessionID = newest.id
        }
    }
}
