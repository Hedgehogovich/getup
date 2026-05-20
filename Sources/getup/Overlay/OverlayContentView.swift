import AppKit
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

    @State private var visible = false

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
                Text("🚶  " + String(localized: "GET UP & STRETCH"))
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)

                Text(String(localized: "click anywhere or press Esc to dismiss"))
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.78))

                GlassButton(title: String(localized: "Snooze 10 min"), action: onSnooze)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
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
