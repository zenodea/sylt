import Foundation

enum PluginProtocol {
    static let version = 1
}

/// Unknown words decode as the fallback, so one never fails the whole message.
protocol PluginKeyword: RawRepresentable, Decodable where RawValue == String {
    static var fallback: Self { get }
}

extension PluginKeyword {
    init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .fallback
    }
}

extension WingSide: PluginKeyword {
    static let fallback = WingSide.right
}

enum HUDSide: String, PluginKeyword {
    case both, left, right
    static let fallback = HUDSide.both
}

enum PluginStatus: String, PluginKeyword {
    case working, waiting, done
    static let fallback = PluginStatus.waiting
}

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
    let interval: Double?
    let accepts: [String]?
    let settings: [Setting]?
    let enabledByDefault: Bool?
    let side: WingSide?
    let opens: String?

    var acceptsFiles: Bool { accepts?.contains("files") ?? false }
    var wantsClipboard: Bool { accepts?.contains("clipboard") ?? false }
    var isOneShot: Bool { interval != nil }

    enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol", id, name, description, symbol, run, interval, accepts, settings, enabledByDefault, side, opens
    }
}

struct PluginItem: Decodable, Hashable {
    var symbol: String?
    var image: String?
    var text: String?
    var tint: String?
    var dot: String?
    var ring: Double?
    var status: PluginStatus?
    var graph: [Double]?
}

struct PluginRow: Decodable, Hashable, Identifiable {
    struct Button: Decodable, Hashable, Identifiable { let id: String; let title: String }

    var id: String?
    var symbol: String?
    var image: String?
    var title: String?
    var detail: String?
    var trailing: String?
    var trailingTint: String?
    var status: PluginStatus?
    var progress: Double?
    var buttons: [Button]?
    var highlighted: Bool?
    var graph: [Double]?
    var tint: String?
    var large: Bool?

    var rowID: String { id ?? "\(title ?? "")\(detail ?? "")" }
}

struct PluginSection: Decodable, Hashable {
    struct Action: Decodable, Hashable, Identifiable { let id: String; let title: String }

    var title: String?
    var symbol: String?
    var items: [PluginItem]?
    var rows: [PluginRow]?
    var files: [String]?
    var buttons: [PluginRow.Button]?
    var actions: [Action]?
}

struct PluginHUD: Decodable, Hashable {
    var symbol: String?
    var image: String?
    var tint: String?
    var text: String?
    var level: Double?
    var side: HUDSide?
    var duration: Double?
    var sound: String?
    var trailingSymbol: String?
    var trailingTint: String?
}

struct PluginActivation: Decodable, Hashable {
    var process: String?
    var pid: Int32?
    var bundle: String?
    var window: String?
}

struct PluginMessage: Decodable {
    struct Wing: Decodable {
        let side: WingSide
        let items: [PluginItem]?
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
