import Foundation
import SwiftData
import os

/// Transforms parsed log entries into SwiftData models.
enum SessionBuilder {
    private static let logger = Logger(subsystem: "com.conductor.app", category: "SessionBuilder")

    /// Build a complete Session with all nodes, tool calls, and commands
    /// from a discovered session's log entries.
    @MainActor
    static func build(
        from discovered: DiscoveredSession,
        in context: ModelContext
    ) -> Session? {
        let entries = JSONLParser.parse(fileAt: discovered.logURL)
        guard !entries.isEmpty else {
            logger.debug("Skipping empty session: \(discovered.sessionId)")
            return nil
        }

        // Parse subagent logs keyed by agentId
        var subagentEntries: [String: [LogEntry]] = [:]
        for url in discovered.subagentURLs {
            let subEntries = JSONLParser.parse(fileAt: url)
            // Extract agentId from filename: "agent-abc1234.jsonl" → "abc1234"
            let filename = url.deletingPathExtension().lastPathComponent
            let agentId = String(filename.dropFirst("agent-".count))
            if !subEntries.isEmpty {
                subagentEntries[agentId] = subEntries
            }
        }

        // Build Session model
        let session = buildSession(from: entries, discovered: discovered)
        context.insert(session)

        // Build root orchestrator node
        let rootNode = buildRootNode(from: entries, session: session)
        context.insert(rootNode)
        rootNode.session = session

        // Build tool calls and commands for root node
        let rootToolCalls = buildToolCalls(from: entries, node: rootNode, context: context)
        let rootCommands = buildCommands(from: entries, node: rootNode, context: context)

        logger.debug("Root node: \(rootToolCalls.count) tool calls, \(rootCommands.count) commands")

        // Build subagent nodes
        for (agentId, subEntries) in subagentEntries {
            let subNode = buildSubagentNode(
                agentId: agentId,
                entries: subEntries,
                parentEntries: entries,
                parent: rootNode,
                session: session,
                context: context
            )
            context.insert(subNode)
            subNode.session = session
            subNode.parent = rootNode

            let subToolCalls = buildToolCalls(from: subEntries, node: subNode, context: context)
            let subCommands = buildCommands(from: subEntries, node: subNode, context: context)
            logger.debug("Subagent \(agentId): \(subToolCalls.count) tool calls, \(subCommands.count) commands")
        }

        return session
    }

    // MARK: - Session

    private static func buildSession(
        from entries: [LogEntry],
        discovered: DiscoveredSession
    ) -> Session {
        let firstUser = entries.first { $0.type == "user" && $0.message?.role == "user" }
        let systemEntry = entries.first { $0.type == "system" && $0.subtype == "turn_duration" }
        let firstEntry = entries.first { $0.parsedTimestamp != nil }
        let lastEntry = entries.last { $0.parsedTimestamp != nil }

        let promptText = firstUser?.message?.content?.textContent ?? ""
        let name = String(promptText.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)

        let totalTokens = entries.compactMap { $0.message?.usage?.output_tokens }.reduce(0, +)
        let inputTokens = entries.compactMap { $0.message?.usage?.input_tokens }.reduce(0, +)

        let startDate = firstEntry?.parsedTimestamp ?? discovered.modifiedDate
        let endDate = systemEntry?.parsedTimestamp ?? lastEntry?.parsedTimestamp

        let durationMs = systemEntry?.durationMs
        let duration = durationMs.map { Double($0) / 1000.0 }
            ?? (endDate.map { $0.timeIntervalSince(startDate) } ?? 0)

        let status: SessionStatus = systemEntry != nil ? .completed : .active

        return Session(
            name: name.isEmpty ? "Untitled Session" : name,
            slug: firstUser?.slug ?? "",
            sourceDir: firstUser?.cwd ?? discovered.projectDir,
            logPath: discovered.logURL.path,
            rootPrompt: String(promptText.prefix(5000)),
            status: status,
            startedAt: startDate,
            completedAt: endDate,
            totalTokens: totalTokens + inputTokens,
            totalDuration: duration,
            tagsRaw: discovered.projectName
        )
    }

    // MARK: - Root Node

    private static func buildRootNode(from entries: [LogEntry], session: Session) -> AgentNode {
        let assistantEntries = entries.filter { $0.message?.role == "assistant" }
        let lastAssistantText = assistantEntries.last?.message?.content?.textContent ?? ""

        let firstTimestamp = entries.first { $0.parsedTimestamp != nil }?.parsedTimestamp
        let lastTimestamp = entries.last { $0.parsedTimestamp != nil }?.parsedTimestamp

        let tokens = entries.compactMap { $0.message?.usage?.output_tokens }.reduce(0, +)

        // Collect files modified via Write/Edit tools
        let writeFiles = collectModifiedFiles(from: entries)

        return AgentNode(
            agentType: .orchestrator,
            agentName: session.slug.isEmpty ? "orchestrator" : session.slug,
            task: session.rootPrompt,
            result: String(lastAssistantText.prefix(2000)),
            status: session.status == .completed ? .completed : .running,
            startedAt: firstTimestamp,
            completedAt: lastTimestamp,
            duration: session.totalDuration,
            tokenCount: tokens,
            depth: 0,
            filesModifiedRaw: writeFiles.joined(separator: "|||")
        )
    }

    // MARK: - Subagent Nodes

    private static func buildSubagentNode(
        agentId: String,
        entries: [LogEntry],
        parentEntries: [LogEntry],
        parent: AgentNode,
        session: Session,
        context: ModelContext
    ) -> AgentNode {
        // Find the Task tool_use in parent that spawned this subagent
        let taskDescription = findTaskDescription(for: agentId, in: parentEntries)

        let firstUser = entries.first { $0.type == "user" && $0.message?.role == "user" }
        let promptText = firstUser?.message?.content?.textContent ?? ""

        let assistantEntries = entries.filter { $0.message?.role == "assistant" }
        let lastAssistantText = assistantEntries.last?.message?.content?.textContent ?? ""

        let firstTimestamp = entries.first { $0.parsedTimestamp != nil }?.parsedTimestamp
        let lastTimestamp = entries.last { $0.parsedTimestamp != nil }?.parsedTimestamp

        let tokens = entries.compactMap { $0.message?.usage?.output_tokens }.reduce(0, +)

        // Determine status from progress/system entries or last entry
        let hasCompletion = entries.contains { $0.type == "system" || $0.type == "progress" }
        let status: AgentNodeStatus = hasCompletion ? .completed : .running

        let duration: Double
        if let start = firstTimestamp, let end = lastTimestamp {
            duration = end.timeIntervalSince(start)
        } else {
            duration = 0
        }

        let writeFiles = collectModifiedFiles(from: entries)

        return AgentNode(
            agentType: .subagent,
            agentName: taskDescription ?? "agent-\(agentId.prefix(7))",
            task: String(promptText.prefix(2000)),
            result: String(lastAssistantText.prefix(2000)),
            status: status,
            startedAt: firstTimestamp,
            completedAt: lastTimestamp,
            duration: duration,
            tokenCount: tokens,
            depth: 1,
            filesModifiedRaw: writeFiles.joined(separator: "|||")
        )
    }

    // MARK: - Tool Calls

    @discardableResult
    private static func buildToolCalls(
        from entries: [LogEntry],
        node: AgentNode,
        context: ModelContext
    ) -> [ToolCallRecord] {
        // Collect all tool_use blocks with their timestamps
        var toolUses: [(block: ToolUseBlock, timestamp: Date?)] = []
        // Collect all tool_result blocks for matching
        var toolResults: [String: (block: ToolResultBlock, entry: LogEntry)] = [:]

        for entry in entries {
            guard let content = entry.message?.content else { continue }

            for tu in content.toolUseBlocks {
                // Skip Task tool calls — those become AgentNodes
                guard tu.name != "Task" else { continue }
                toolUses.append((tu, entry.parsedTimestamp))
            }

            for tr in content.toolResultBlocks {
                toolResults[tr.tool_use_id] = (tr, entry)
            }
        }

        var records: [ToolCallRecord] = []

        for (tu, useTimestamp) in toolUses {
            let result = toolResults[tu.id]
            let isError = result?.block.is_error ?? false

            let inputStr = tu.input.map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")

            let outputStr: String
            if let content = result?.block.content {
                outputStr = content.toJSONString(maxLength: 2000)
            } else {
                outputStr = ""
            }

            let status: ToolCallStatus
            if result == nil {
                status = .pending
            } else if isError {
                status = .failed
            } else {
                status = .succeeded
            }

            let executedAt = result?.entry.parsedTimestamp ?? useTimestamp ?? Date()

            let record = ToolCallRecord(
                toolName: tu.name,
                input: String(inputStr.prefix(2000)),
                output: String(outputStr.prefix(2000)),
                status: status,
                executedAt: executedAt
            )
            context.insert(record)
            record.node = node
            records.append(record)
        }

        return records
    }

    // MARK: - Commands (Bash tool calls)

    @discardableResult
    private static func buildCommands(
        from entries: [LogEntry],
        node: AgentNode,
        context: ModelContext
    ) -> [CommandRecord] {
        var bashUses: [(block: ToolUseBlock, timestamp: Date?)] = []
        var toolResults: [String: (block: ToolResultBlock, entry: LogEntry)] = [:]

        for entry in entries {
            guard let content = entry.message?.content else { continue }

            for tu in content.toolUseBlocks where tu.name == "Bash" {
                bashUses.append((tu, entry.parsedTimestamp))
            }

            for tr in content.toolResultBlocks {
                toolResults[tr.tool_use_id] = (tr, entry)
            }
        }

        var records: [CommandRecord] = []

        for (tu, useTimestamp) in bashUses {
            let command = tu.input["command"]?.stringValue ?? ""
            guard !command.isEmpty else { continue }

            let result = toolResults[tu.id]

            // Try to extract stdout/stderr from toolUseResult on the result entry
            let resultEntry = result?.entry
            let stdout = resultEntry?.toolUseResult?.stdout?.toJSONString(maxLength: 2000) ?? ""
            let stderr = resultEntry?.toolUseResult?.stderr?.toJSONString(maxLength: 2000) ?? ""

            // If no structured stdout, use tool_result content
            let output: String
            if stdout.isEmpty, let content = result?.block.content {
                output = content.toJSONString(maxLength: 2000)
            } else {
                output = stdout
            }

            let isError = result?.block.is_error ?? false
            let exitCode = isError ? 1 : 0

            let executedAt = result?.entry.parsedTimestamp ?? useTimestamp ?? Date()

            let record = CommandRecord(
                command: String(command.prefix(2000)),
                exitCode: exitCode,
                stdout: output,
                stderr: stderr,
                executedAt: executedAt
            )
            context.insert(record)
            record.node = node
            records.append(record)
        }

        return records
    }

    // MARK: - Helpers

    /// Find the Task tool_use description that spawned a given subagent.
    private static func findTaskDescription(for agentId: String, in entries: [LogEntry]) -> String? {
        // Look for tool_result entries with toolUseResult containing this agentId
        for entry in entries {
            if let trInfo = entry.toolUseResult, trInfo.agentId == agentId {
                // Found the completion — now find the original Task tool_use
                // by matching the tool_use_id
                break
            }
        }

        // Simpler approach: look for Task tool_use blocks and try to match by order
        // or description. Since we can't directly match agentId to tool_use_id,
        // extract description from all Task calls
        for entry in entries {
            guard let content = entry.message?.content else { continue }
            for tu in content.toolUseBlocks where tu.name == "Task" {
                if let desc = tu.input["description"]?.stringValue {
                    // Check if any tool_result references this agentId
                    // For now, use the description as the name
                    return desc
                }
            }
        }
        return nil
    }

    /// Collect file paths modified by Write/Edit tools.
    private static func collectModifiedFiles(from entries: [LogEntry]) -> [String] {
        var files = Set<String>()

        for entry in entries {
            guard let content = entry.message?.content else { continue }
            for tu in content.toolUseBlocks {
                switch tu.name {
                case "Write", "Edit":
                    if let path = tu.input["file_path"]?.stringValue {
                        files.insert(path)
                    }
                default:
                    break
                }
            }

            // Also check toolUseResult.filePath for file operations
            if let filePath = entry.toolUseResult?.filePath {
                files.insert(filePath)
            }
        }

        return Array(files).sorted()
    }
}
