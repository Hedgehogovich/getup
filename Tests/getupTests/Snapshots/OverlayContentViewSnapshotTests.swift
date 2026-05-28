import AppKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import getup

/// Snapshot test for OverlayContentView across en/ru/el locales.
/// `.all` mode always writes PNGs; Argos CI integration owns visual diffing + approval.
@MainActor
@Suite(.snapshots(record: .all))
struct OverlayContentViewSnapshotTests {
    static let plainSize = CGSize(width: 600, height: 460)
    static let mediaSize = CGSize(width: 600, height: 720)

    private static func bundle(for code: String) -> Bundle {
        // Tests/getupTests/Snapshots/file.swift → repo root = 4 deletions.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(code).lproj")
        return Bundle(path: url.path)!
    }

    private static func hosted(_ view: some View, size: CGSize) -> NSView {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        return host
    }

    /// Solid-color PNG written to a tmp path. Deterministic, no fixture file checked-in.
    private static func tempImagePNG() throws -> URL {
        let size = NSSize(width: 240, height: 140)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else { fatalError("Could not encode tmp PNG") }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("overlay-snap-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    @Test(arguments: ["en", "ru", "el"])
    func defaultVariant(locale: String) {
        let view = OverlayContentView(
            onDismiss: {},
            onSnooze: {},
            initiallyVisible: true,
            bundle: Self.bundle(for: locale)
        )
        let host = Self.hosted(view, size: Self.plainSize)
        withKnownIssue { assertSnapshot(of: host, as: .image(precision: 0.98, perceptualPrecision: 0.98), named: locale) }
    }

    @Test(arguments: ["en", "ru", "el"])
    func withImageMedia(locale: String) throws {
        let url = try Self.tempImagePNG()
        defer { try? FileManager.default.removeItem(at: url) }

        let view = OverlayContentView(
            onDismiss: {},
            onSnooze: {},
            mediaURL: url,
            initiallyVisible: true,
            bundle: Self.bundle(for: locale)
        )
        let host = Self.hosted(view, size: Self.mediaSize)
        withKnownIssue { assertSnapshot(of: host, as: .image(precision: 0.98, perceptualPrecision: 0.98), named: locale) }
    }
}
