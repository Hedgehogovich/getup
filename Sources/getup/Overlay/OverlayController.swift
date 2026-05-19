import AppKit
import AVFoundation
import Foundation

final class OverlayController {
    private var windows: [NSWindow] = []
    private var audioPlayer: AVAudioPlayer?
    private var localKeyMonitor: Any?

    var isShowing: Bool { !windows.isEmpty }

    func show(audioMode: AudioMode, volume: Double) {
        guard !isShowing else { return }

        MainActor.assumeIsolated { PreviewPlayer.shared.stop() }

        let screens = NSScreen.screens
        NSLog("getup: showing on \(screens.count) screen(s), audioMode=\(audioMode.rawValue), volume=\(volume)")
        for (i, screen) in screens.enumerated() {
            let win = makeWindow(for: screen)
            windows.append(win)
            win.orderFrontRegardless()
            NSLog("getup:   screen[\(i)] \(screen.localizedName) frame=\(screen.frame) winFrame=\(win.frame)")
        }

        if let first = windows.first {
            NSApp.activate(ignoringOtherApps: true)
            first.makeKeyAndOrderFront(nil)
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                // Removing the monitor inside its own callback is unsafe.
                DispatchQueue.main.async { self?.dismiss() }
                return nil
            }
            return event
        }

        playAudio(mode: audioMode, volume: volume)
    }

    func dismiss() {
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
        let cardH: CGFloat = 150
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
        win.contentView = view
        win.initialFirstResponder = view
        return win
    }

    private func playAudio(mode: AudioMode, volume: Double) {
        let isHP = isHeadphoneOutput()
        NSLog("getup: playAudio mode=\(mode.rawValue) volume=\(volume) headphones=\(isHP)")
        switch mode {
        case .silent:
            NSLog("getup: silent mode -> no audio")
            return
        case .headphonesOnly:
            guard isHP else {
                NSLog("getup: speakers active, headphonesOnly mode -> skipping audio")
                return
            }
        case .always:
            break
        }
        guard let url = AppPaths.soundFileCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            NSLog("getup: no sound file in \(AppPaths.supportDir.path)")
            return
        }
        NSLog("getup: loading \(url.path)")
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(max(0, min(1, volume)))
            player.prepareToPlay()
            let ok = player.play()
            NSLog("getup: AVAudioPlayer.play() -> \(ok), duration=\(player.duration)s")
            audioPlayer = player
        } catch {
            NSLog("getup: AVAudioPlayer LOAD error: \(error)")
        }
    }
}
