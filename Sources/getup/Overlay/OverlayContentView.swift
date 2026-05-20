import SwiftUI

struct OverlayContentView: View {
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0, opacity: 0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )

            VStack(spacing: 10) {
                Text("🚶  " + String(localized: "GET UP & STRETCH"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text(String(localized: "click anywhere or press Esc to dismiss"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.7))

                Button(String(localized: "Snooze 10 min")) {
                    onSnooze()
                }
                .controlSize(.regular)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}
