import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show(store: SettingsStore) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(rootView: SettingsView(store: store))
        let w = NSWindow(contentViewController: host)
        w.title = "getup"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}
