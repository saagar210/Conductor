import Foundation
import os

@MainActor
final class LogMonitor {
    private let logger = Logger(subsystem: "com.conductor.app", category: "monitor")
    private var fileHandles: [String: FileMonitorState] = [:]

    struct FileMonitorState {
        var fileHandle: FileHandle?
        var lastFileSize: UInt64
        var lastModified: Date
        var isActive: Bool
    }

    // MARK: - Public API

    func startMonitoring(path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw LogMonitorError.fileNotFound(path)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        let modifiedDate = attributes[.modificationDate] as? Date ?? Date()

        let fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))

        fileHandles[path] = FileMonitorState(
            fileHandle: fileHandle,
            lastFileSize: fileSize,
            lastModified: modifiedDate,
            isActive: true
        )

        logger.info("Started monitoring file: \(path)")
    }

    func stopMonitoring(path: String) {
        if let state = fileHandles[path] {
            try? state.fileHandle?.close()
            fileHandles.removeValue(forKey: path)
            logger.info("Stopped monitoring file: \(path)")
        }
    }

    func stopAll() {
        for path in fileHandles.keys {
            stopMonitoring(path: path)
        }
    }

    func checkForNewEntries(path: String) throws -> [String] {
        guard var state = fileHandles[path] else {
            throw LogMonitorError.notMonitoring(path)
        }

        // Check if file still exists
        guard FileManager.default.fileExists(atPath: path) else {
            throw LogMonitorError.fileNotFound(path)
        }

        // Get current file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let currentSize = attributes[.size] as? UInt64 ?? 0
        let currentModified = attributes[.modificationDate] as? Date ?? Date()

        // If file hasn't changed, return empty
        if currentSize == state.lastFileSize && currentModified <= state.lastModified {
            return []
        }

        // If file shrunk, it was recreated - re-read from beginning
        if currentSize < state.lastFileSize {
            logger.info("File \(path) was recreated, re-reading from beginning")
            try? state.fileHandle?.close()

            let newFileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
            state.fileHandle = newFileHandle
            state.lastFileSize = 0
            fileHandles[path] = state
        }

        // Seek to last known position
        guard let fileHandle = state.fileHandle else {
            throw LogMonitorError.invalidFileHandle(path)
        }

        try fileHandle.seek(toOffset: state.lastFileSize)

        // Read new data
        let newData: Data
        if #available(macOS 10.15.4, *) {
            newData = try fileHandle.readToEnd() ?? Data()
        } else {
            newData = fileHandle.readDataToEndOfFile()
        }

        // Update state
        state.lastFileSize = currentSize
        state.lastModified = currentModified
        fileHandles[path] = state

        // Parse new lines
        guard !newData.isEmpty else { return [] }

        let newContent = String(data: newData, encoding: .utf8) ?? ""
        let newLines = newContent.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        logger.debug("Read \(newLines.count) new lines from \(path)")

        return newLines
    }

    func pollAllMonitoredFiles() -> [String: [String]] {
        var results: [String: [String]] = [:]

        for path in fileHandles.keys {
            do {
                let newLines = try checkForNewEntries(path: path)
                if !newLines.isEmpty {
                    results[path] = newLines
                }
            } catch {
                logger.error("Error polling \(path): \(error.localizedDescription)")
            }
        }

        return results
    }

    // MARK: - Incremental Parsing

    func parseNewEntries(from path: String) throws -> [LogEntry] {
        let newLines = try checkForNewEntries(path: path)
        guard !newLines.isEmpty else { return [] }

        var entries: [LogEntry] = []
        for line in newLines {
            do {
                let entry = try JSONLParser.parseLine(line)
                entries.append(entry)
            } catch {
                logger.warning("Failed to parse line: \(error.localizedDescription)")
                continue
            }
        }

        return entries
    }

    func isMonitoring(path: String) -> Bool {
        return fileHandles[path]?.isActive ?? false
    }

    func monitoredPaths() -> [String] {
        return Array(fileHandles.keys)
    }
}

enum LogMonitorError: Error, LocalizedError {
    case fileNotFound(String)
    case notMonitoring(String)
    case invalidFileHandle(String)
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .notMonitoring(let path):
            return "Not monitoring file: \(path)"
        case .invalidFileHandle(let path):
            return "Invalid file handle for: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        }
    }
}
