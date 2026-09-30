import Combine
import Foundation
import IOBluetooth

@MainActor
final class BluetoothMonitor: NSObject, ObservableObject {
    struct Device: Hashable {
        let name: String
        let address: String
        /// Percent, when the device reports one.
        let battery: Int?
    }

    enum Event: Hashable {
        case connected(Device)
        case disconnected(Device)
    }

    let events = PassthroughSubject<Event, Never>()

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]

    func start() {
        guard connectNotification == nil else { return }
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        for device in IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [] where device.isConnected() {
            watchDisconnect(of: device)
        }
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications = [:]
    }

    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        watchDisconnect(of: device)
        let name = device.name ?? "Bluetooth device"
        let address = device.addressString ?? ""
        Task { @MainActor in
            let battery = await BluetoothBattery.level(address: address, name: name)
            events.send(.connected(Device(name: name, address: address, battery: battery)))
        }
    }

    @objc private func disconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        disconnectNotifications.removeValue(forKey: address)?.unregister()
        events.send(.disconnected(Device(name: device.name ?? "Bluetooth device", address: address, battery: nil)))
    }

    private func watchDisconnect(of device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        guard disconnectNotifications[address] == nil else { return }
        disconnectNotifications[address] = device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
    }
}

/// Battery of a Bluetooth accessory: the IORegistry knows Apple devices
/// straight away; anything else goes through the system profiler.
enum BluetoothBattery {
    static func level(address: String, name: String) async -> Int? {
        try? await Task.sleep(for: .seconds(1.5))
        if let level = registryLevel(address: address) { return level }
        return await profilerLevel(name: name)
    }

    private static func registryLevel(address: String) -> Int? {
        let wanted = normalise(address)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"), &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: Any],
                  let found = dict["DeviceAddress"] as? String, normalise(found) == wanted
            else { continue }
            let levels = ["BatteryPercent", "BatteryPercentLeft", "BatteryPercentRight"].compactMap { dict[$0] as? Int }.filter { $0 > 0 }
            return levels.min()
        }
        return nil
    }

    private static func profilerLevel(name: String) async -> Int? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                process.arguments = ["SPBluetoothDataType", "-json"]
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                guard (try? process.run()) != nil else { return continuation.resume(returning: nil) }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: parse(data, name: name))
            }
        }
    }

    private static func parse(_ data: Data, name: String) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return nil }
        for section in sections {
            for entry in section["device_connected"] as? [[String: Any]] ?? [] {
                guard let fields = entry[name] as? [String: Any] else { continue }
                let levels = ["device_batteryLevelMain", "device_batteryLevelLeft", "device_batteryLevelRight"]
                    .compactMap { fields[$0] as? String }
                    .compactMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) }
                return levels.min()
            }
        }
        return nil
    }

    private static func normalise(_ address: String) -> String {
        address.lowercased().filter(\.isHexDigit)
    }
}
