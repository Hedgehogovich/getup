import AppKit

final class OverlayView: NSView {
    var onDismiss: (() -> Void)?
    var onSnooze: (() -> Void)?

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

        let snooze = NSButton(title: String(localized: "Snooze 10 min"),
                              target: self,
                              action: #selector(snoozeClicked))
        snooze.bezelStyle = .rounded
        snooze.translatesAutoresizingMaskIntoConstraints = false
        addSubview(snooze)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            title.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            hint.centerXAnchor.constraint(equalTo: centerXAnchor),
            hint.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            snooze.centerXAnchor.constraint(equalTo: centerXAnchor),
            snooze.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 10),
        ])
    }

    @objc private func snoozeClicked() {
        DispatchQueue.main.async { [weak self] in self?.onSnooze?() }
    }

    override func mouseDown(with event: NSEvent) {
        // Closing the window inside its own event handler segfaults — defer.
        DispatchQueue.main.async { [weak self] in self?.onDismiss?() }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:  // Esc
            DispatchQueue.main.async { [weak self] in self?.onDismiss?() }
        case 1:   // 'S'
            DispatchQueue.main.async { [weak self] in self?.onSnooze?() }
        default:
            super.keyDown(with: event)
        }
    }
}
