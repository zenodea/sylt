import Combine
import Foundation

/// Which events show a HUD, and how long it stays.
extension IslandState {
    func bindAlerts() {
        show(volume.changes) { .volume }
        show(brightness.changes) { .brightness }
        show(battery.alerts) { .battery($0) }
        show(nowPlaying.trackChanges.merge(with: nowPlaying.playbackResumed)) { .nowPlaying }
        show(notifications.notifications) { .notification($0) }
        show(volume.muteChanges) { .mute($0) }
        show(bluetooth.events) { .bluetooth($0) }
        show(bluetooth.lowBattery) { .peripheralBattery($0) }
        show(network.changes) { .network($0) }
        show(calendar.reminders) { .calendar($0) }
        show(keyboard.capsLock) { .capsLock($0) }
        show(keyboard.inputSource) { .inputSource($0) }
        show(focus.changes) { .focus($0) }
        show(privacy.changes) { .privacy($0) }
        show(thermal.changes) { .thermal($0) }
        lock.$isLocked
            .dropFirst()
            .sink { [weak self] in $0 ? self?.locked() : self?.unlocked() }
            .store(in: &cancellables)
    }

    func showHUD(_ kind: HUDKind) {
        guard mode != .expanded, preferences.enabledHUDs.contains(kind.category) else { return }
        transition(to: .hud(kind))
        scheduleHUDDismissal(after: kind.duration * preferences.hudDurationScale)
    }

    func scheduleHUDDismissal(after duration: TimeInterval) {
        hudTimer?.invalidate()
        hudTimer = .after(duration) { [weak self] in
            guard let self, case .hud = mode, !isHovering else { return }
            transition(to: restingMode)
        }
    }

    private func show<P: Publisher>(_ publisher: P, as kind: @escaping (P.Output) -> HUDKind) where P.Failure == Never {
        publisher
            .sink { [weak self] in self?.showHUD(kind($0)) }
            .store(in: &cancellables)
    }

    private func locked() {
        hudTimer?.invalidate()
        collapseTimer?.invalidate()
        if preferences.playsLockSound { Sounds.lock() }
        transition(to: .locked)
    }

    private func unlocked() {
        if preferences.playsUnlockSound { Sounds.unlock() }
        if preferences.enabledHUDs.contains(.unlock) { showHUD(.unlocked) } else { transition(to: .closed) }
    }
}
