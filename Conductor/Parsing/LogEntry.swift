import Foundation

// MARK: - Top-Level Log Entry

struct LogEntry: Codable, Sendable {
    let type: String
    let uuid: String?
    let timestamp: String?
    let sessionId: String?
    let parentUuid: String?
    let isSidechain: Bool?
    let userType: String?
    let cwd: String?
    let version: String?
    let gitBranch: String?
    let slug: String?
    let agentId: String?
    let requestId: String?
    let message: LogMessage?
    let toolUseResult: ToolUseResultInfo?
    let sourceToolAssistantUUID: String?

    // system entry fields
    let subtype: String?
    let durationMs: Int?
    let isMeta: Bool?

    // progress entry fields
    let data: AnyCodable?

    var parsedTimestamp: Date? {
        guard let timestamp else { return nil }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: timestamp) {
            return date
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: timestamp)
    }
}

// MARK: - Message

struct LogMessage: Codable, Sendable {
    let role: String?
    let model: String?
    let content: MessageContent?
    let usage: UsageInfo?
    let stop_reason: String?
}

/// Message content can be a plain string or an array of content blocks.
enum MessageContent: Codable, Sendable {
    case text(String)
    case blocks([ContentBlock])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .text(s)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            self = .text("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s): try container.encode(s)
        case .blocks(let blocks): try container.encode(blocks)
        }
    }

    /// Extract all text from this content (concatenating text blocks).
    var textContent: String {
        switch self {
        case .text(let s): return s
        case .blocks(let blocks):
            return blocks.compactMap { block in
                if case .text(let tb) = block { return tb.text }
                return nil
            }.joined(separator: "\n")
        }
    }

    /// Extract all tool_use blocks.
    var toolUseBlocks: [ToolUseBlock] {
        guard case .blocks(let blocks) = self else { return [] }
        return blocks.compactMap { block in
            if case .toolUse(let tu) = block { return tu }
            return nil
        }
    }

    /// Extract all tool_result blocks.
    var toolResultBlocks: [ToolResultBlock] {
        guard case .blocks(let blocks) = self else { return [] }
        return blocks.compactMap { block in
            if case .toolResult(let tr) = block { return tr }
            return nil
        }
    }
}

// MARK: - Content Blocks

enum ContentBlock: Codable, Sendable {
    case text(TextBlock)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""

        switch type {
        case "text":
            self = .text(try TextBlock(from: decoder))
        case "tool_use":
            self = .toolUse(try ToolUseBlock(from: decoder))
        case "tool_result":
            self = .toolResult(try ToolResultBlock(from: decoder))
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let block): try block.encode(to: encoder)
        case .toolUse(let block): try block.encode(to: encoder)
        case .toolResult(let block): try block.encode(to: encoder)
        case .unknown: break
        }
    }
}

struct TextBlock: Codable, Sendable {
    let type: String
    let text: String
}

struct ToolUseBlock: Codable, Sendable {
    let type: String
    let id: String
    let name: String
    let input: [String: AnyCodable]
}

struct ToolResultBlock: Codable, Sendable {
    let tool_use_id: String
    let type: String
    let content: AnyCodable?
    let is_error: Bool?
}

// MARK: - Supporting Types

struct UsageInfo: Codable, Sendable {
    let input_tokens: Int?
    let output_tokens: Int?
    let cache_creation_input_tokens: Int?
    let cache_read_input_tokens: Int?
}

struct ToolUseResultInfo: Codable, Sendable {
    // Result can have many shapes depending on tool type.
    // We capture it loosely and extract what we need.
    let type: String?
    let content: AnyCodable?
    let status: String?
    let agentId: String?
    let prompt: String?
    let filePath: String?
    let file: String?
    let stdout: AnyCodable?
    let stderr: AnyCodable?
}
