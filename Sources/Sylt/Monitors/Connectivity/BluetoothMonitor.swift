import Combine
import Foundation
import IOBluetooth

@MainActor
final class BluetoothMonitor: NSObject, ObservableObject {
    struct Device: Hashable {
        let name: String
        let address: String
        /// Percent, when the device reports one.
        var battery: Int?
        var isAudio = false
    }

    enum Event: Hashable {
        case connected(Device)
        case disconnected(Device)

        var device: Device {
            switch self {
            case .connected(let device), .disconnected(let device): device
            }
        }
    }

    let events = PassthroughSubject<Event, Never>()
    /// A connected device dropping to 20 and then 10 percent.
    let lowBattery = PassthroughSubject<Device, Never>()
    /// Connected devices with a known charge, audio devices first.
    @Published var connected: [Device] = []

    var headphones: Device? { connected.first { $0.isAudio && $0.battery != nil } }

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var refresh: Timer?
    private var warned: [String: Int] = [:]

    func start() {
        guard connectNotification == nil else { return }
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        for device in IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [] where device.isConnected() {
            watchDisconnect(of: device)
            Task { @MainActor in await track(device) }
        }
        refresh = .every(5 * 60) { [weak self] in Task { await self?.refreshBatteries() } }
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications = [:]
        refresh?.invalidate()
        refresh = nil
        connected = []
    }

    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        watchDisconnect(of: device)
        Task { @MainActor in
            let tracked = await track(device)
            events.send(.connected(tracked))
        }
    }

    @objc private func disconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        disconnectNotifications.removeValue(forKey: address)?.unregister()
        connected.removeAll { $0.address == address }
        warned[address] = nil
        events.send(.disconnected(Device(name: device.name ?? "Bluetooth device", address: address, battery: nil)))
    }

    @discardableResult
    private func track(_ device: IOBluetoothDevice) async -> Device {
        let name = device.name ?? "Bluetooth device"
        let address = device.addressString ?? ""
        let isAudio = device.deviceClassMajor == kBluetoothDeviceClassMajorAudio
        let battery = await BluetoothBattery.level(address: address, name: name)
        let tracked = Device(name: name, address: address, battery: battery, isAudio: isAudio)
        connected.removeAll { $0.address == address }
        connected.append(tracked)
        connected.sort { $0.isAudio && !$1.isAudio }
        warn(tracked)
        return tracked
    }

    private func refreshBatteries() async {
        for device in connected {
            guard let level = await BluetoothBattery.level(address: device.address, name: device.name, delay: 0),
                  let index = connected.firstIndex(where: { $0.address == device.address })
            else { continue }
            connected[index].battery = level
            warn(connected[index])
        }
    }

    private func warn(_ device: Device) {
        guard let level = device.battery else { return }
        let threshold = level <= 10 ? 10 : level <= 20 ? 20 : 100
        if threshold == 100 { warned[device.address] = nil; return }
        guard warned[device.address] != threshold, (warned[device.address] ?? 100) > threshold else { return }
        warned[device.address] = threshold
        lowBattery.send(device)
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
    static func level(address: String, name: String, delay: Double = 1.5) async -> Int? {
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
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
        guard let data = await Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"]) else { return nil }
        return parse(data, name: name)
    }

    static func parse(_ data: Data, name: String) -> Int? {
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

    static func normalise(_ address: String) -> String {
        address.lowercased().filter(\.isHexDigit)
    }
}
