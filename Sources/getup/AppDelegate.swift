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
        // SF Symbol = native menu-bar look. `isTemplate = true` makes AppKit render it in the
        // single colour the menu bar wants (light/dark mode aware, inverts on hover, dims when
        // disabled). Falls back to the original emoji glyph if the symbol can't be resolved —
        // belt-and-braces for hypothetical OS variants where `figure.walk.motion` was removed.
        if let img = NSImage(systemSymbolName: "figure.walk.motion", accessibilityDescription: "Getup") {
            img.isTemplate = true
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "🚶"
        }

        rebuildMenu()

        // refresh menu checkmark when audioMode changes from the Settings window
        audioModeCancellable = settings.$current
            .map(\.audioMode)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.rebuildMenu() }

        // toggle Dock presence + ⌘Tab when user flips the Show-in-Dock setting
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

        // Show wizard for fresh installs. Returning users were marked complete in SettingsStore.init.
        wizard.showIfNeeded(store: settings) { [weak self] in
            // Audio mode may have just changed — refresh menu checkmark.
            self?.rebuildMenu()
        }
    }

    /// Dock-icon click (and ⌘Tab activation when Dock is hidden) opens Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    /// Right-click on the Dock icon mirrors the status-bar menu so the Dock-mode user
    /// has the same quick actions without going to the menu bar.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        buildMenu()
    }

    /// `LSUIElement = true` ships in Info.plist as the baseline (menu-bar-only). At runtime
    /// we promote to `.regular` when the user opts into the Dock — this overrides LSUIElement
    /// without re-launch. Demoting back to `.accessory` removes the Dock icon immediately.
    ///
    /// Gotcha: transitioning a running app from `.regular` to `.accessory` causes AppKit to
    /// hide the app's windows (the demoted app is treated like a background-only app, which
    /// shouldn't be "frontmost"). The user toggling Show-in-Dock OFF is doing so FROM the
    /// Settings window — so without intervention, the window they're looking at vanishes.
    /// We capture visible windows before the switch, then re-front them on the next runloop
    /// so the Settings (or Wizard) window stays put.
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

        // Audio mode quick-pick submenu (also reachable from Settings window)
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
