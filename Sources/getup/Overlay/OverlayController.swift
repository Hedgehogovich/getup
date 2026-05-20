import AppKit
import AVFoundation
import Foundation

@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private var audioPlayer: AVAudioPlayer?
    private var localKeyMonitor: Any?
    private var autoDismissTimer: Timer?

    var onSnooze: (() -> Void)?

    var isShowing: Bool { !windows.isEmpty }

    func show(audioMode: AudioMode, volume: Double, autoDismissSeconds: Int? = nil) {
        guard !isShowing else { return }

        PreviewPlayer.shared.stop()

        let screens = NSScreen.screens
        for screen in screens {
            let win = makeWindow(for: screen)
            windows.append(win)
            win.orderFrontRegardless()
        }

        if let first = windows.first {
            NSApp.activate(ignoringOtherApps: true)
            first.makeKeyAndOrderFront(nil)
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                // Removing the monitor inside its own callback is unsafe.
                Task { @MainActor in self?.dismiss() }
                return nil
            }
            return event
        }

        playAudio(mode: audioMode, volume: volume)

        if let secs = autoDismissSeconds, secs > 0 {
            autoDismissTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(secs),
                                                   repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss() }
            }
        }
    }

    func dismiss() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        for w in windows { w.orderOut(nil); w.close() }
        windows.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        if let m = localKeyMonitor {
            NSEvent.removeMonitor(m)
            localKeyMonitor = nil
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let frame = screen.frame
        let cardW: CGFloat = 520
        let cardH: CGFloat = 190
        // contentRect is in GLOBAL coords. Don't pass `screen:` — it would double-offset by screen.origin.
        let x = frame.origin.x + (frame.width - cardW) / 2
        let y = frame.origin.y + frame.height - cardH - 90

        let win = OverlayWindow(
            contentRect: NSRect(x: x, y: y, width: cardW, height: cardH),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.setFrameOrigin(NSPoint(x: x, y: y))
        win.level = .screenSaver   // .shielding would route the window to a single display only.
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true
        win.sharingType = .none   // hides from Teams / QuickTime / any screen capture.
        win.ignoresMouseEvents = false
        win.isMovable = false
        win.acceptsMouseMovedEvents = false
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false   // we hold the ref; default true would over-release on close().

        let view = OverlayView(frame: NSRect(x: 0, y: 0, width: cardW, height: cardH))
        view.onDismiss = { [weak self] in self?.dismiss() }
        view.onSnooze = { [weak self] in
            self?.dismiss()
            self?.onSnooze?()
        }
        win.contentView = view
        win.initialFirstResponder = view
        return win
    }

    private func playAudio(mode: AudioMode, volume: Double) {
        switch mode {
        case .silent:
            return
        case .headphonesOnly:
            guard isHeadphoneOutput() else { return }
        case .always:
            break
        }
        guard let url = AppPaths.existingSoundFile else {
            NSLog("getup: no sound file in \(AppPaths.supportDir.path)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(max(0, min(1, volume)))
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            NSLog("getup: AVAudioPlayer load error: \(error)")
        }
    }
}
