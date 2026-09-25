import Foundation
import IOKit.ps
import Combine

struct BatterySnapshot: Equatable {
    var percent: Int = 0
    var isCharging = false
    var onAC = false
    var minutesRemaining: Int? = nil
    var hasBattery = true
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var snapshot = BatterySnapshot()
    let chargerChanges = PassthroughSubject<Void, Never>()

    private var source: CFRunLoopSource?

    func start() {
        refresh()
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in monitor.refresh() }
        }, ctx).takeRetainedValue()
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
    }

    func refresh() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        var next = BatterySnapshot()
        guard let ps = list.first,
              let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any]
        else {
            next.hasBattery = false
            snapshot = next
            return
        }
        let cur = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        next.percent = max > 0 ? Int((Double(cur) / Double(max) * 100).rounded()) : 0
        next.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        next.onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let ttf = desc[kIOPSTimeToFullChargeKey] as? Int ?? -1
        let tte = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
        let mins = next.isCharging ? ttf : tte
        next.minutesRemaining = mins > 0 ? mins : nil

        let acChanged = next.onAC != snapshot.onAC
        snapshot = next
        if acChanged { chargerChanges.send() }
    }
}
