import AppKit
import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class OverlayController {
    private var windows: [NSWindow] = []
    private var audioPlayer: AVAudioPlayer?
    private var localKeyMonitor: Any?
    private var autoDismissTimer: Timer?
    private var stashedWindows: [NSWindow] = []
    private var previousFrontmostApp: NSRunningApplication?
    private var hideFromScreenCapture = true
    private var mediaURL: URL?
    private var snoozeMinutes: Int = 10

    var onSnooze: (() -> Void)?

    var isShowing: Bool { !windows.isEmpty }

    func show(audioMode: AudioMode,
              volume: Double,
              snoozeMinutes: Int = 10,
              autoDismissSeconds: Int? = nil,
              hideFromScreenCapture: Bool = true,
              mediaURL: URL? = nil) {
        guard !isShowing else { return }

        self.hideFromScreenCapture = hideFromScreenCapture
        self.mediaURL = mediaURL
        self.snoozeMinutes = snoozeMinutes
        PreviewPlayer.shared.stop()

        // Capture the foreground app so we can restore it on dismiss — otherwise the user
        // returns to our app instead of whatever they were using when the overlay fired.
        let me = NSRunningApplication.current.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication
        previousFrontmostApp = (front?.processIdentifier == me) ? nil : front

        // NSApp.activate brings ALL app windows forward (incl. Settings in dock mode).
        // Stash visible non-overlay windows so they don't pop into focus.
        stashedWindows = NSApp.windows.filter { $0.isVisible && !($0 is OverlayWindow) }
        for w in stashedWindows { w.orderOut(nil) }

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
            switch event.keyCode {
            case 53:   // Esc — removing monitor inside its own callback is unsafe.
                Task { @MainActor in self?.dismiss() }
                return nil
            case 1:    // 'S' — snooze
                Task { @MainActor in
                    guard let self else { return }
                    self.dismiss()
                    self.onSnooze?()
                }
                return nil
            default:
                return event
            }
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
        for w in stashedWindows { w.orderFront(nil) }
        stashedWindows.removeAll()
        if let prev = previousFrontmostApp {
            prev.activate(options: [])
            previousFrontmostApp = nil
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let frame = screen.frame
        let cardW: CGFloat = 520
        let cardH: CGFloat = mediaURL == nil ? 190 : 460
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
        win.hasShadow = false   // AppKit shadow follows window rect; SwiftUI shadow follows the rounded card instead.
        win.sharingType = hideFromScreenCapture ? .none : .readOnly   // .none hides from Teams / QuickTime / any screen capture.
        win.ignoresMouseEvents = false
        win.isMovable = false
        win.acceptsMouseMovedEvents = false
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false   // we hold the ref; default true would over-release on close().

        let content = OverlayContentView(
            onDismiss: { [weak self] in
                Task { @MainActor in self?.dismiss() }
            },
            onSnooze: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.dismiss()
                    self.onSnooze?()
                }
            },
            mediaURL: mediaURL,
            snoozeMinutes: snoozeMinutes
        )
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: cardW, height: cardH)
        host.autoresizingMask = [.width, .height]
        // Without this, hosting view paints opaque in the corners outside the rounded card,
        // and the window's drop shadow follows the rectangle instead of the rounded shape.
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        win.contentView = host
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
