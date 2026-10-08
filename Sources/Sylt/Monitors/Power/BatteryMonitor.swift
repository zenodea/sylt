import Foundation
import IOKit.ps
import Combine

struct BatterySnapshot: Equatable {
    var percent = 0
    var isCharging = false
    var onAC = false
    var minutesRemaining: Int?
    var hasBattery = true
}

enum BatteryAlert: Hashable {
    case level(Int)
    case powerSource

    func message(onAC: Bool) -> String {
        switch self {
        case .powerSource: onAC ? "Charging" : "On battery"
        case .level(100): "Fully charged"
        case .level(let percent) where percent <= 10: "Critically low"
        case .level(let percent) where percent <= 20: "Low battery"
        case .level: "Battery"
        }
    }
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var snapshot = BatterySnapshot()
    let alerts = PassthroughSubject<BatteryAlert, Never>()

    private static let thresholds = [80, 60, 40, 20, 15, 10, 5, 0]
    private var source: CFRunLoopSource?
    private var hasBaseline = false

    func start() {
        guard source == nil else { return }
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in monitor.refresh() }
        }, context).takeRetainedValue()
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        source = nil
        hasBaseline = false
    }

    private func refresh() {
        let previous = snapshot
        snapshot = Self.read()
        defer { hasBaseline = true }
        guard hasBaseline, snapshot.hasBattery else { return }

        if snapshot.onAC != previous.onAC {
            alerts.send(.powerSource)
        } else if snapshot.isCharging, snapshot.percent == 100, previous.percent < 100 {
            alerts.send(.level(100))
        } else if !snapshot.onAC, let crossed = Self.crossedThreshold(from: previous.percent, to: snapshot.percent) {
            alerts.send(.level(crossed))
        }
    }

    private static func crossedThreshold(from old: Int, to new: Int) -> Int? {
        thresholds.first { new <= $0 && old > $0 }
    }

    private static func read() -> BatterySnapshot {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
        else {
            return BatterySnapshot(hasBattery: false)
        }

        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let capacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
        var snapshot = BatterySnapshot()
        snapshot.percent = capacity > 0 ? Int((Double(current) / Double(capacity) * 100).rounded()) : 0
        snapshot.isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        snapshot.onAC = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue

        let toFull = description[kIOPSTimeToFullChargeKey] as? Int ?? -1
        let toEmpty = description[kIOPSTimeToEmptyKey] as? Int ?? -1
        let minutes = snapshot.isCharging ? toFull : toEmpty
        snapshot.minutesRemaining = minutes > 0 ? minutes : nil
        return snapshot
    }
}
