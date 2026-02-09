import Foundation

/// Type-erased Codable wrapper for handling heterogeneous JSON values.
/// Used for `tool_use.input` (dictionaries) and `tool_result.content` (string, array, or null).
struct AnyCodable: Codable, Sendable, CustomStringConvertible {
    let value: Any & Sendable

    var description: String {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case let a as [Any]: return "[\(a.count) items]"
        case let d as [String: Any]: return "{\(d.count) keys}"
        case is NSNull: return "null"
        default: return String(describing: value)
        }
    }

    var stringValue: String? { value as? String }
    var arrayValue: [AnyCodable]? { nil } // arrays decoded inline
    var dictValue: [String: AnyCodable]? { nil }

    init(_ value: Any & Sendable) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull() as! any Sendable
        } else if let b = try? container.decode(Bool.self) {
            value = b
        } else if let i = try? container.decode(Int.self) {
            value = i
        } else if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self) {
            value = s
        } else if let arr = try? container.decode([AnyCodable].self) {
            value = arr.map(\.value) as! any Sendable
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value) as! any Sendable
        } else {
            value = NSNull() as! any Sendable
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case is NSNull: try container.encodeNil()
        default: try container.encodeNil()
        }
    }

    /// Attempt to serialize the value to a JSON string for storage.
    func toJSONString(maxLength: Int = 2000) -> String {
        if let s = value as? String {
            return String(s.prefix(maxLength))
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: value, options: [.fragmentsAllowed]
        ) else {
            return String(describing: value).prefix(maxLength).description
        }
        let str = String(data: data, encoding: .utf8) ?? ""
        return String(str.prefix(maxLength))
    }
}
