@MainActor
protocol Monitor: AnyObject {
    func start()
    func stop()
}

extension BatteryMonitor: Monitor {}
extension VolumeMonitor: Monitor {}
extension BrightnessMonitor: Monitor {}
extension NowPlayingMonitor: Monitor {}
extension SystemNotificationMonitor: Monitor {}
extension BluetoothMonitor: Monitor {}
extension NetworkMonitor: Monitor {}
extension CalendarMonitor: Monitor {}
extension KeyboardMonitor: Monitor {}
extension FocusMonitor: Monitor {}
extension PrivacyMonitor: Monitor {}
extension ThermalMonitor: Monitor {}
