import AppKit
import SwiftUI

final class WizardWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onComplete: (() -> Void)?

    func showIfNeeded(store: SettingsStore, onComplete: @escaping () -> Void) {
        guard store.isFirstRun else { onComplete(); return }
        present(store: store, onComplete: onComplete)
    }

    private func present(store: SettingsStore, onComplete: @escaping () -> Void) {
        if window != nil { return }
        self.onComplete = onComplete

        let host = NSHostingController(rootView: WizardView(store: store) { [weak self] languageChanged in
            store.markFirstRunComplete()
            if languageChanged {
                // Relaunch so menu bar + Settings strings pick up the new locale.
                DaemonRestart.restart()
            } else {
                self?.window?.close()
            }
        })
        let w = NSWindow(contentViewController: host)
        w.title = "getup"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.delegate = self
        // LSUIElement = true means we have no Dock icon — once the user clicks another app
        // and our wizard slips behind it, there is no obvious way to bring it back. Pinning
        // the window above other apps and across spaces ensures it stays reachable until the
        // user explicitly engages with it. This is NOT modal (the user can still click out and
        // do other work) — see CLAUDE.md tripwire about not making the wizard modal/required.
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    // Closing via the title-bar X also marks the wizard complete — don't nag forever.
    // We also auto-write a default `sound.aiff` here so a user who dismisses the wizard
    // before reaching step 3 still gets audio at xx:50. saveLoopIfMissing is a no-op when
    // a sound file already exists, so this is safe to call regardless of which step they bailed at.
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        if let store = (window?.contentViewController as? NSHostingController<WizardView>)?.rootView.store {
            store.markFirstRunComplete()
            SaySynth.saveLoopIfMissing(voice: store.current.voice,
                                       phrase: store.current.customPhrase)
        }
        window = nil
        onComplete?()
        onComplete = nil
    }
}
