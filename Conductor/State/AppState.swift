import Foundation
import CoreGraphics

@Observable
@MainActor
final class AppState {
    var selectedSessionID: UUID? {
        didSet {
            selectedNodeID = nil
        }
    }
    var selectedNodeID: UUID?
    var canvasSize: CGSize = CGSize(width: 800, height: 600) // Default fallback

    // Phase 3: Search & Filtering
    var searchText: String = ""
    var searchFilter: SearchFilter = .none
    var filteredSessions: [Session] = []
    var isSearching: Bool = false

    // Phase 4: Analytics
    var analyticsTab: AnalyticsTab = .tokens
    var selectedDateRange: DateRange = .all

    // Phase 5: Live Monitoring
    var isMonitoring: Bool = false
    var newSessionsCount: Int = 0

    // Phase 6: Replay
    var isReplaying: Bool = false
    var replayProgress: Double = 0.0
    var replaySpeed: Double = 1.0
    var currentReplayEventIndex: Int = 0

    let simulation = ForceSimulation()
    let searchState = SearchState()
}

// Phase 4: Analytics tab types
enum AnalyticsTab: String, Sendable {
    case tokens
    case tools
    case performance
    case trends
}

enum DateRange: String, Sendable, CaseIterable {
    case today
    case week
    case month
    case all
}
