import Foundation
import os

/// Parses Claude Code JSONL log files into arrays of `LogEntry`.
enum JSONLParser {
    private static let logger = Logger(subsystem: "com.conductor.app", category: "JSONLParser")

    /// Parse an entire JSONL file into log entries.
    /// Malformed lines are skipped with a warning log.
    static func parse(fileAt url: URL) -> [LogEntry] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            logger.warning("Could not read file: \(url.path)")
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var entries: [LogEntry] = []
        entries.reserveCapacity(lines.count)

        let decoder = JSONDecoder()

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            guard let data = trimmed.data(using: .utf8) else { continue }

            if let entry = try? decoder.decode(LogEntry.self, from: data) {
                entries.append(entry)
            } else {
                logger.debug("Skipped malformed line \(index) in \(url.lastPathComponent)")
            }
        }

        return entries
    }

    /// Parse a single JSON line (useful for incremental parsing in Phase 3).
    static func parseLine(_ data: Data) -> LogEntry? {
        try? JSONDecoder().decode(LogEntry.self, from: data)
    }
}
