@MainActor
protocol Monitor: AnyObject {
    func start()
    func stop()
}

extension BatteryMonitor: Monitor {}
extension VolumeMonitor: Monitor {}
extension BrightnessMonitor: Monitor {}
extension NowPlayingMonitor: Monitor {}
extension HerdrMonitor: Monitor {}
