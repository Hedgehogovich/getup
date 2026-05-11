import AppKit

final class OverlayView: NSView {
    var onDismiss: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        buildContent()
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    private func buildContent() {
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.88).cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 1, alpha: 0.25).cgColor

        let title = NSTextField(labelWithString: "🚶  " + String(localized: "GET UP & STRETCH"))
        title.font = .systemFont(ofSize: 30, weight: .bold)
        title.textColor = .white
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        let hint = NSTextField(labelWithString: String(localized: "click anywhere or press Esc to dismiss"))
        hint.font = .systemFont(ofSize: 13, weight: .regular)
        hint.textColor = NSColor(white: 1, alpha: 0.7)
        hint.alignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hint)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            title.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -12),
            hint.centerXAnchor.constraint(equalTo: centerXAnchor),
            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
        ])
    }

    override func mouseDown(with event: NSEvent) {
        // defer to next tick — closing window inside its own event handler segfaults
        DispatchQueue.main.async { [weak self] in self?.onDismiss?() }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            DispatchQueue.main.async { [weak self] in self?.onDismiss?() }
        } else {
            super.keyDown(with: event)
        }
    }
}
