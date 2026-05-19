import AppKit
import Combine
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let overlay = OverlayController()
    private let settings = SettingsStore()
    private let settingsWindow = SettingsWindowController()
    private let wizard = WizardWindowController()
    private var scheduler: StretchScheduler!
    private var audioModeCancellable: AnyCancellable?
    private var dockPolicyCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy(showInDock: settings.current.showInDock)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // `isTemplate = true` lets AppKit recolor for dark mode / hover / disabled states.
        if let img = NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: "Getup") {
            img.isTemplate = true
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

        scheduler = StretchScheduler(
            fireMinute: { [weak self] in self?.settings.current.fireMinute ?? 50 },
            onFire: { [weak self] in
                guard let self else { return }
                self.overlay.show(audioMode: self.settings.current.audioMode,
                                  volume: self.settings.current.volume)
            }
        )
        scheduler.start()

        wizard.showIfNeeded(store: settings) { [weak self] in
            // Wizard may have changed audio mode — refresh menu checkmark.
            self?.rebuildMenu()
        }
    }

    /// Dock-icon click opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    /// Right-click on Dock icon mirrors the status-bar menu.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        buildMenu()
    }

    /// Switching from `.regular` to `.accessory` at runtime hides the app's visible windows
    /// (the demoted app is treated as background-only). User toggles this from Settings, so
    /// without re-fronting the window vanishes underneath them. Capture-then-restore.
    private func applyActivationPolicy(showInDock: Bool) {
        let visibleBefore = NSApp.windows.filter { $0.isVisible }
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        guard !showInDock else { return }
        DispatchQueue.main.async {
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
        overlay.show(audioMode: settings.current.audioMode,
                     volume: settings.current.volume)
    }

    @objc private func setAudioMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = AudioMode(rawValue: raw) else { return }
        settings.current.audioMode = mode   // didSet auto-persists; sink rebuilds menu
        NSLog("getup: audioMode set to \(mode.rawValue)")
    }

    @objc private func openSettings() {
        settingsWindow.show(store: settings)
    }
}
