import Foundation
import os

/// Represents a discovered Claude Code session on disk.
struct DiscoveredSession: Sendable {
    let projectDir: String
    let projectName: String
    let sessionId: String
    let logURL: URL
    let subagentURLs: [URL]
    let fileSize: Int
    let modifiedDate: Date
}

/// Scans `~/.claude/projects/` to discover all Claude Code session logs.
enum SessionDiscovery {
    private static let logger = Logger(subsystem: "com.conductor.app", category: "SessionDiscovery")

    /// UUID pattern: 8-4-4-4-12 hex chars
    private static let uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

    /// Scan `~/.claude/projects/` and return all discovered sessions, newest first.
    static func discoverAll() -> [DiscoveredSession] {
        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard FileManager.default.fileExists(atPath: claudeProjectsDir.path) else {
            logger.info("No ~/.claude/projects/ directory found")
            return []
        }

        let fm = FileManager.default
        var sessions: [DiscoveredSession] = []

        guard let projectDirs = try? fm.contentsOfDirectory(
            at: claudeProjectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.warning("Could not list ~/.claude/projects/")
            return []
        }

        for projectDirURL in projectDirs {
            guard isDirectory(projectDirURL) else { continue }

            let dirName = projectDirURL.lastPathComponent
            let projName = projectName(from: dirName)

            guard let files = try? fm.contentsOfDirectory(
                at: projectDirURL,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files {
                guard file.pathExtension == "jsonl" else { continue }
                let stem = file.deletingPathExtension().lastPathComponent

                // Must match UUID pattern (not subagent files like "agent-xxx")
                guard stem.wholeMatch(of: uuidPattern) != nil else { continue }

                let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let fileSize = attrs?.fileSize ?? 0
                let modDate = attrs?.contentModificationDate ?? Date.distantPast

                // Skip empty files
                guard fileSize > 0 else { continue }

                // Look for subagent logs
                let subagentDir = projectDirURL
                    .appendingPathComponent(stem)
                    .appendingPathComponent("subagents")
                var subagentURLs: [URL] = []
                if let subFiles = try? fm.contentsOfDirectory(
                    at: subagentDir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) {
                    subagentURLs = subFiles.filter { $0.pathExtension == "jsonl" }
                }

                sessions.append(DiscoveredSession(
                    projectDir: dirName,
                    projectName: projName,
                    sessionId: stem,
                    logURL: file,
                    subagentURLs: subagentURLs,
                    fileSize: fileSize,
                    modifiedDate: modDate
                ))
            }
        }

        // Sort newest first
        sessions.sort { $0.modifiedDate > $1.modifiedDate }
        logger.info("Discovered \(sessions.count) sessions across \(projectDirs.count) projects")
        return sessions
    }

    /// Extract a human-readable project name from the directory name.
    /// e.g. "-Users-d-Projects-Conductor" → "Conductor"
    static func projectName(from dirName: String) -> String {
        let components = dirName.split(separator: "-")
        guard components.count > 1 else { return dirName }

        // Find last occurrence of "Projects" or "projects" and take everything after
        if let projectsIndex = components.lastIndex(where: {
            $0.lowercased() == "projects"
        }), projectsIndex + 1 < components.count {
            return components[(projectsIndex + 1)...].joined(separator: "-")
        }

        // Fallback: last component
        return String(components.last ?? Substring(dirName))
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
