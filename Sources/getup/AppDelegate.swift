import AppKit
import Combine
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let overlay = OverlayController()
    private let settings: SettingsStore = {
        if let suite = TestMode.defaultsSuite, let ud = UserDefaults(suiteName: suite) {
            return SettingsStore(defaults: ud, legacySuiteName: nil, customAudioDetector: { nil })
        }
        return SettingsStore()
    }()
    private let settingsWindow = SettingsWindowController()
    private let wizard = WizardWindowController()
    private var scheduler: StretchScheduler!
    private var audioModeCancellable: AnyCancellable?
    private var dockPolicyCancellable: AnyCancellable?
    private var fireMinuteCancellable: AnyCancellable?
    private var snoozeTimer: Timer?
    private var snoozeIntendedFireDate: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if TestMode.isActive { writeTestStatusAndExit() }
        LogRotation.rotateIfNeeded()
        applyActivationPolicy(showInDock: settings.current.showInDock)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let img = NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: "Getup") {
            img.isTemplate = true   // adapt to dark mode / hover / disabled
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "🚶"
        }

        rebuildMenu()

        audioModeCancellable = settings.$current
            .map(\.audioMode)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.rebuildMenu() }

        dockPolicyCancellable = settings.$current
            .map(\.showInDock)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] show in self?.applyActivationPolicy(showInDock: show) }

        overlay.onSnooze = { [weak self] in self?.armSnooze() }

        scheduler = StretchScheduler(
            fireMinute: { [weak self] in self?.settings.current.fireMinute ?? 50 },
            onFire: { [weak self] in self?.fireOverlay() }
        )
        scheduler.start()

        // @Published emits on willSet — defer one runloop turn so the closure inside
        // reschedule reads the committed (didSet) value, not the still-old one.
        fireMinuteCancellable = settings.$current
            .map(\.fireMinute)
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduler.reschedule() }

        wizard.showIfNeeded(store: settings) { [weak self] in
            self?.rebuildMenu()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        PreviewPlayer.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        buildMenu()
    }

    private func applyActivationPolicy(showInDock: Bool) {
        // .regular → .accessory at runtime hides visible windows; re-front to keep Settings up.
        let visibleBefore = NSApp.windows.filter { $0.isVisible }
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        guard !showInDock else { return }
        Task { @MainActor in
            for w in visibleBefore where !w.isVisible {
                w.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let stretchNow = NSMenuItem(title: String(localized: "Stretch now"),
                                    action: #selector(stretchNow),
                                    keyEquivalent: "")
        stretchNow.target = self
        menu.addItem(stretchNow)

        let settingsItem = NSMenuItem(title: String(localized: "Settings…"),
                                      action: #selector(openSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let audioRoot = NSMenuItem(title: String(localized: "Audio mode"),
                                   action: nil, keyEquivalent: "")
        let audioSub = NSMenu()
        for mode in AudioMode.allCases {
            let item = NSMenuItem(title: mode.displayName,
                                  action: #selector(setAudioMode(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = (mode == settings.current.audioMode) ? .on : .off
            audioSub.addItem(item)
        }
        audioRoot.submenu = audioSub
        menu.addItem(audioRoot)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: String(localized: "Quit Getup"),
                              action: #selector(NSApp.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    private func rebuildMenu() {
        statusItem.menu = buildMenu()
    }

    @objc private func stretchNow() {
        showOverlay()   // manual trigger bypasses quiet hours
    }

    private func fireOverlay() {
        guard OverlayDispatch.shouldFire(now: Date(), settings: settings.current) else { return }
        showOverlay()
    }

    private func showOverlay() {
        let s = settings.current
        let media = s.overlayMediaEnabled ? AppPaths.existingMediaFile : nil
        overlay.show(audioMode: s.audioMode,
                     volume: s.volume,
                     snoozeMinutes: s.snoozeMinutes,
                     autoDismissSeconds: s.overlayAutoDismissSeconds,
                     hideFromScreenCapture: s.hideFromScreenCapture,
                     mediaURL: media)
    }

    private func armSnooze() {
        snoozeTimer?.invalidate()
        let now = Date()
        let intended = SnoozeDecision.fireDate(from: now, snoozeMinutes: settings.current.snoozeMinutes)
        snoozeIntendedFireDate = intended
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: intended.timeIntervalSince(now),
                                           repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.snoozeFired() }
        }
    }

    private func snoozeFired() {
        let now = Date()
        defer { snoozeIntendedFireDate = nil }
        guard let intended = snoozeIntendedFireDate else { return }
        guard StretchScheduler.shouldFire(now: now,
                                          intended: intended,
                                          graceSeconds: StretchScheduler.defaultGraceSeconds) else {
            NSLog("getup: skipped stale snooze — \(Int(now.timeIntervalSince(intended)))s past intended \(intended)")
            return
        }
        fireOverlay()
    }

    @objc private func setAudioMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = AudioMode(rawValue: raw) else { return }
        settings.current.audioMode = mode
        NSLog("getup: audioMode set to \(mode.rawValue)")
    }

    @objc private func openSettings() {
        settingsWindow.show(store: settings)
    }

    private func writeTestStatusAndExit() -> Never {
        let s = settings.current
        let status = TestModeStatus(
            pid: ProcessInfo.processInfo.processIdentifier,
            fireMinute: s.fireMinute,
            snoozeMinutes: s.snoozeMinutes,
            audioMode: s.audioMode.rawValue,
            volume: s.volume,
            showInDock: s.showInDock,
            isFirstRun: settings.isFirstRun
        )
        if let path = TestMode.outputPath,
           let data = try? JSONEncoder().encode(status) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
        exit(0)
    }
}
