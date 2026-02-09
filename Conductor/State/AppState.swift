import Foundation

@Observable
@MainActor
final class AppState {
    var selectedSessionID: UUID? {
        didSet {
            selectedNodeID = nil
        }
    }
    var selectedNodeID: UUID?

    let simulation = ForceSimulation()
}
