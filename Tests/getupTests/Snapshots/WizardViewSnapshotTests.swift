import AppKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import getup

/// Snapshot test for WizardView across en/ru/el locales × language/audio/voice steps.
/// Voices async-load via `say -v ?`; tests render before that completes so voice-step
/// picker shows only the seeded voice — deterministic. `.all` mode always writes PNGs;
/// Argos CI integration owns visual diffing + approval.
@MainActor
@Suite(.snapshots(record: .all))
struct WizardViewSnapshotTests {
    static let size = CGSize(width: 420, height: 460)

    private static func bundle(for code: String) -> Bundle {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(code).lproj")
        return Bundle(path: url.path)!
    }

    private static func testStore() -> SettingsStore {
        let suite = "snap-wizard-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = SettingsStore(defaults: defaults, legacySuiteName: nil)
        store.current.voice = "Samantha"
        store.current.customPhrase = "Movement protocol initiated."
        return store
    }

    private static func hosted(_ view: some View, size: CGSize) -> NSView {
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        return host
    }

    @Test(arguments: ["en", "ru", "el"])
    func languageStep(locale: String) {
        let store = Self.testStore()
        let view = WizardView(store: store,
                              onComplete: { _ in },
                              initialStep: .language,
                              initialBundle: Self.bundle(for: locale))
        let host = Self.hosted(view, size: Self.size)
        withKnownIssue { assertSnapshot(of: host, as: .image(precision: 0.98, perceptualPrecision: 0.98), named: locale) }
    }

    @Test(arguments: ["en", "ru", "el"])
    func audioStep(locale: String) {
        let store = Self.testStore()
        let view = WizardView(store: store,
                              onComplete: { _ in },
                              initialStep: .audio,
                              initialBundle: Self.bundle(for: locale))
        let host = Self.hosted(view, size: Self.size)
        withKnownIssue { assertSnapshot(of: host, as: .image(precision: 0.98, perceptualPrecision: 0.98), named: locale) }
    }

    @Test(arguments: ["en", "ru", "el"])
    func voiceStep(locale: String) {
        let store = Self.testStore()
        let view = WizardView(store: store,
                              onComplete: { _ in },
                              initialStep: .voice,
                              initialBundle: Self.bundle(for: locale))
        let host = Self.hosted(view, size: Self.size)
        withKnownIssue { assertSnapshot(of: host, as: .image(precision: 0.98, perceptualPrecision: 0.98), named: locale) }
    }
}
