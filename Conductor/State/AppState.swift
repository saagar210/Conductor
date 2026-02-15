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

    // Phase 4: Analytics
    var analyticsTab: AnalyticsTab = .tokens
    var selectedDateRange: DateRange = .all

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
