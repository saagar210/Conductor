import Foundation

struct SessionFingerprint: Sendable, Equatable {
    let fileSize: Int
    let modifiedDate: Date
    let subagentSignature: String
}

struct SessionSyncPlan: Sendable, Equatable {
    let changedSessions: [DiscoveredSession]
    let removedLogPaths: [String]

    var isEmpty: Bool {
        changedSessions.isEmpty && removedLogPaths.isEmpty
    }
}

enum SessionSyncPlanner {
    /// Build a fingerprint map keyed by log path for quick change detection.
    static func fingerprints(from sessions: [DiscoveredSession]) -> [String: SessionFingerprint] {
        Dictionary(uniqueKeysWithValues: sessions.map { session in
            (
                session.logURL.path,
                SessionFingerprint(
                    fileSize: session.fileSize,
                    modifiedDate: session.modifiedDate,
                    subagentSignature: subagentSignature(for: session)
                )
            )
        })
    }

    /// Build a complete synchronization plan from discovered sessions and known fingerprints.
    static func plan(
        discovered: [DiscoveredSession],
        knownFingerprints: [String: SessionFingerprint]
    ) -> SessionSyncPlan {
        let latest = fingerprints(from: discovered)

        let changedSessions = discovered.filter { session in
            guard let existing = knownFingerprints[session.logURL.path],
                  let current = latest[session.logURL.path] else {
                return true
            }
            return existing != current
        }

        let removedLogPaths = Array(Set(knownFingerprints.keys).subtracting(latest.keys)).sorted()

        return SessionSyncPlan(changedSessions: changedSessions, removedLogPaths: removedLogPaths)
    }

    private static func subagentSignature(for session: DiscoveredSession) -> String {
        session.subagentURLs
            .map { subagentURL in
                let values = try? subagentURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = values?.fileSize ?? 0
                let modifiedAt = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                return "\(subagentURL.path)#\(size)#\(modifiedAt)"
            }
            .sorted()
            .joined(separator: "||")
    }
}
