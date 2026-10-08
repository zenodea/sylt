import Foundation

/// Version 1 of the plugin protocol: JSON objects, one per line, both ways.
///
/// A plugin prints messages to stdout: `wing`, `hud`, `section`, `sound`,
/// `activate`, `open`, `log`. The host writes events to its stdin: `start`,
/// `settings`, `click`, `button`, `action`, `drop`, `remove`, `stop`.
enum PluginProtocol {
    static let version = 1
}

/// A folder's `plugin.json`.
struct PluginManifest: Decodable, Hashable {
    struct Setting: Decodable, Hashable, Identifiable {
        enum Kind: String, Decodable { case bool, text, number, choice }
        let key: String
        let title: String
        let type: Kind
        let `default`: JSONValue?
        let options: [String]?

        var id: String { key }
    }

    let protocolVersion: Int
    let id: String
    let name: String
    let description: String?
    let symbol: String?
    let run: String
    /// Seconds between one-shot runs. Absent means the plugin stays running.
    let interval: Double?
    let accepts: [String]?
    let settings: [Setting]?
    let enabledByDefault: Bool?
    /// "left" or "right": where the badge goes unless the user moves it.
    let side: String?

    var acceptsFiles: Bool { accepts?.contains("files") ?? false }
    var wantsClipboard: Bool { accepts?.contains("clipboard") ?? false }
    var isOneShot: Bool { interval != nil }

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol", id, name, description, symbol, run, interval, accepts, settings, enabledByDefault, side
    }
}

/// Something a plugin puts in a wing: a glyph, an image, text, a dot or a ring, in any mix.
struct PluginItem: Decodable, Hashable {
    var symbol: String?
    var image: String?
    var text: String?
    var tint: String?
    var dot: String?
    var ring: Double?
    var status: String?
    /// A small graph of values from 0 to 1, oldest first.
    var graph: [Double]?

    var isWorking: Bool { status == "working" }
}

/// A row of a plugin's expanded section.
struct PluginRow: Decodable, Hashable, Identifiable {
    struct Button: Decodable, Hashable, Identifiable { let id: String; let title: String }

    var id: String?
    var symbol: String?
    var image: String?
    var title: String?
    var detail: String?
    var trailing: String?
    var trailingTint: String?
    var status: String?
    var progress: Double?
    var buttons: [Button]?
    var highlighted: Bool?
    var graph: [Double]?
    var tint: String?
    /// A bigger title, for a headline number like a temperature.
    var large: Bool?

    var rowID: String { id ?? "\(title ?? "")\(detail ?? "")" }
}

/// A plugin's section in the expanded island.
struct PluginSection: Decodable, Hashable {
    struct Action: Decodable, Hashable, Identifiable { let id: String; let title: String }

    var title: String?
    var symbol: String?
    /// Small items at the right of the header, like tallies.
    var items: [PluginItem]?
    var rows: [PluginRow]?
    var files: [String]?
    var buttons: [PluginRow.Button]?
    var actions: [Action]?
}

/// A HUD a plugin asks to show now.
struct PluginHUD: Decodable, Hashable {
    var symbol: String?
    var image: String?
    var tint: String?
    var text: String?
    var level: Double?
    var side: String?
    var duration: Double?
    var sound: String?
    /// A symbol after the text that bounces in, like a tick.
    var trailingSymbol: String?
    var trailingTint: String?
}

struct PluginActivation: Decodable, Hashable {
    var process: String?
    var pid: Int32?
    var bundle: String?
    /// Raise the window whose title contains this, once the app is in front.
    var window: String?
}

/// One line of plugin output.
struct PluginMessage: Decodable {
    struct Wing: Decodable {
        let side: String
        let items: [PluginItem]?
        /// Space between items; 8 unless the plugin wants its icons tighter.
        let spacing: Double?
    }

    var wing: Wing?
    var hud: PluginHUD?
    var section: PluginSection?
    var clearSection: Bool?
    var sound: String?
    var activate: PluginActivation?
    var open: String?
    var log: String?
}

/// One line of host input, written to the plugin.
struct PluginEvent: Encodable {
    let event: String
    var settings: [String: JSONValue]? = nil
    var dataDir: String? = nil
    var `protocol`: Int? = nil
    var row: String? = nil
    var id: String? = nil
    var files: [String]? = nil
    var text: String? = nil
}

/// A JSON scalar, array or object, for settings values.
enum JSONValue: Codable, Hashable {
    case string(String), number(Double), bool(Bool), null
    indirect case array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { self = .object(try container.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    var stringValue: String? { if case .string(let value) = self { return value }; return nil }
    var doubleValue: Double? { if case .number(let value) = self { return value }; return nil }
    var boolValue: Bool? { if case .bool(let value) = self { return value }; return nil }
}
