import AppKit
import AVFoundation
import AVKit
import SwiftUI

private struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct OverlayContentView: View {
    let onDismiss: () -> Void
    let onSnooze: () -> Void
    var mediaURL: URL? = nil
    var initiallyVisible: Bool = false
    var bundle: Bundle = .main
    var snoozeMinutes: Int = 10

    @State private var visible: Bool

    init(onDismiss: @escaping () -> Void,
         onSnooze: @escaping () -> Void,
         mediaURL: URL? = nil,
         initiallyVisible: Bool = false,
         bundle: Bundle = .main,
         snoozeMinutes: Int = 10) {
        self.onDismiss = onDismiss
        self.onSnooze = onSnooze
        self.mediaURL = mediaURL
        self.initiallyVisible = initiallyVisible
        self.bundle = bundle
        self.snoozeMinutes = snoozeMinutes
        self._visible = State(initialValue: initiallyVisible)
    }

    var body: some View {
        ZStack {
            if visible {
                card.transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            guard !initiallyVisible else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                visible = true
            }
        }
    }

    private var card: some View {
        ZStack {
            GlassBackground()
                .overlay(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )

            VStack(spacing: 14) {
                if let url = mediaURL {
                    MediaView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text("🚶  " + String(localized: "GET UP & STRETCH", bundle: bundle))
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)

                Text(String(localized: "click anywhere or press Esc to dismiss", bundle: bundle))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.78))

                GlassButton(title: String(format: String(localized: "Snooze %d min", bundle: bundle), snoozeMinutes), action: onSnooze)
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GlassButton: View {
    let title: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(hovering ? 0.26 : 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// Routes by extension: image / GIF / video.
private struct MediaView: View {
    let url: URL

    var body: some View {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4", "mov":
            VideoMediaView(url: url)
        case "gif":
            // NSImageView handles animated GIFs natively when `animates = true`.
            AnimatedImageView(url: url)
        default:
            if let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
    }
}

private struct AnimatedImageView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.animates = true
        v.image = NSImage(contentsOf: url)
        return v
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image == nil { nsView.image = NSImage(contentsOf: url) }
    }
}

private struct VideoMediaView: NSViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVPlayerView {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        // AVPlayerLooper must be retained; Coordinator holds it so it lives with the view.
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        player.play()
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

    final class Coordinator {
        var looper: AVPlayerLooper?
    }
}
