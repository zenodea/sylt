enum StoredID {
    private static let pluginPrefix = "plugin:"

    static func plugin(_ id: String) -> String { pluginPrefix + id }

    static func pluginID(in stored: String) -> String? {
        stored.hasPrefix(pluginPrefix) ? String(stored.dropFirst(pluginPrefix.count)) : nil
    }
}
