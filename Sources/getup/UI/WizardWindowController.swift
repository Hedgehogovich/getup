import AppKit
import SwiftUI

@MainActor
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
                DaemonRestart.restart()   // re-read AppleLanguages so menu bar + Settings match.
            } else {
                self?.window?.close()
            }
        })
        let w = NSWindow(contentViewController: host)
        w.title = "Getup"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.delegate = self
        // .floating + canJoinAllSpaces — under LSUIElement=true there's no Dock icon to bring
        // the wizard back if it slips behind another app. Don't promote to runModal().
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }

    // X-close also marks the wizard complete + writes sound.aiff so bailing pre-step-3 still works.
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
