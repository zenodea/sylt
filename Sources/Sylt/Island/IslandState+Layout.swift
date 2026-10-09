import Combine
import SwiftUI

/// What the monitors, the plugins and the user's layout choices do to the island's shape.
extension IslandState {
    func apply(_ geometry: NotchGeometry) {
        layout.notchWidth = geometry.notchWidth
        layout.notchHeight = geometry.notchHeight
        layout.screenWidth = geometry.screen.frame.width
    }

    /// Turn the expanded view by one spread of pages; `delta` is +1 for the next, -1 for the previous.
    func turnPage(_ delta: Int) {
        let count = layout.spreadCount
        guard count > 1 else { return }
        let next = (layout.currentSpread + delta + count) % count
        pageDirection = delta
        withAnimation(IslandAnimation.expand) { layout.expandedPage = next * layout.columns }
        Haptics.press()
    }

    func bindLayout() {
        preferences.$notchDepth
            .sink { [weak self] in self?.layout.notchDepth = CGFloat($0) }
            .store(in: &cancellables)
        fullscreen.$isFullscreen
            .sink { [weak self] in self?.layout.isFullscreen = $0 }
            .store(in: &cancellables)
        preferences.$spreadsPages
            .sink { [weak self] in self?.layout.spreadsPages = $0 }
            .store(in: &cancellables)
        battery.$snapshot
            .sink { [weak self] in self?.layout.hasBattery = $0.hasBattery }
            .store(in: &cancellables)
        bluetooth.$isOn
            .sink { [weak self] in self?.layout.bluetoothOn = $0 }
            .store(in: &cancellables)

        nowPlaying.$track
            .sink { [weak self] track in
                guard let self else { return }
                layout.showsArtwork = track != nil
                layout.showsAudioBars = track != nil
                layout.showsMediaCard = track != nil
                refreshExpandedPages()
            }
            .store(in: &cancellables)

        calendar.$next
            .combineLatest(calendar.$imminent)
            .sink { [weak self] next, imminent in
                self?.layout.showsNextEvent = next != nil
                self?.layout.showsCalendar = imminent
                self?.refreshExpandedPages()
            }
            .store(in: &cancellables)

        privacy.$use
            .combineLatest(focus.$mode, bluetooth.$connected)
            .sink { [weak self] use, focus, connected in
                guard let self else { return }
                layout.privacyDots = (use.microphone ? 1 : 0) + (use.camera ? 1 : 0)
                layout.showsFocus = focus != nil
                layout.showsHeadphones = connected.contains { $0.isAudio && $0.battery != nil }
            }
            .store(in: &cancellables)
    }

    /// Plugin wings and sections feed the layout; a plugin's HUD goes through the usual gate.
    func bindPlugins() {
        plugins.huds
            .sink { [weak self] plugin, hud in
                if let sound = hud.sound { Sounds.play(sound) }
                self?.showHUD(.external(ExternalHUD(pluginID: plugin.id, hud: hud)))
            }
            .store(in: &cancellables)
        plugins.$plugins
            .map { plugins in
                Publishers.MergeMany(plugins.map { plugin in
                    plugin.$left.combineLatest(plugin.$right, plugin.$section).map { _ in () }
                })
                .prepend(())
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.refreshPluginLayout() }
            .store(in: &cancellables)
        preferences.$wingLayout
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshPluginLayout() }
            .store(in: &cancellables)
        preferences.$expandedLayout
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshExpandedPages() }
            .store(in: &cancellables)
        preferences.$lockShowsStatus
            .sink { [weak self] in self?.layout.lockShowsStatus = $0 }
            .store(in: &cancellables)
    }

    private func refreshPluginLayout() {
        let running = plugins.plugins.filter(\.isRunning)
        layout.pluginWidths = Dictionary(uniqueKeysWithValues: running.map { ($0.id, PluginItem.width(of: $0.wingItems, spacing: $0.wingSpacing)) })
        layout.wings = preferences.wingLayout.resolve(plugins: plugins.plugins.map(\.wingPlugin))
        layout.pluginSectionHeights = Dictionary(uniqueKeysWithValues: running.compactMap { plugin in plugin.section.map { (plugin.id, $0.height) } })
        refreshExpandedPages()
    }

    /// Pages follow the sections available now and the user's grouping.
    private func refreshExpandedPages() {
        layout.expandedPages = preferences.expandedLayout.resolve(available: layout.availableSections)
        layout.expandedPage = min(layout.expandedPage, max(0, layout.expandedPages.count - 1))
    }
}
