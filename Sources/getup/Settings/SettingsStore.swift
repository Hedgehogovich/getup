import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var current: Settings {
        didSet {
            guard current != oldValue else { return }
            if current.language != oldValue.language {
                applyLanguageOverride(current.language)
            }
            persist()
        }
    }

    static let firstRunKey = "getup.hasCompletedFirstRun.v1"
    static let customAudioBackfillKey = "getup.customAudioBackfillDone.v1"

    private let storeKey: String
    private let firstRunKey: String
    private let customAudioBackfillKey: String
    private let defaults: UserDefaults

    var isFirstRun: Bool { !defaults.bool(forKey: firstRunKey) }
    func markFirstRunComplete() { defaults.set(true, forKey: firstRunKey) }

    init(
        defaults: UserDefaults = .standard,
        storeKey: String = "getup.settings.v1",
        firstRunKey: String = SettingsStore.firstRunKey,
        legacySuiteName: String? = "getup",
        customAudioBackfillKey: String = SettingsStore.customAudioBackfillKey,
        customAudioDetector: () -> URL? = { AppPaths.existingSoundFile }
    ) {
        self.defaults = defaults
        self.storeKey = storeKey
        self.firstRunKey = firstRunKey
        self.customAudioBackfillKey = customAudioBackfillKey

        // Pre-bundle binary stored under suite "getup" (executable name); now "com.ychachilo.getup".
        var hadLegacy = false
        if defaults.data(forKey: storeKey) == nil,
           let suite = legacySuiteName,
           let legacy = UserDefaults(suiteName: suite),
           let old = legacy.data(forKey: storeKey) {
            defaults.set(old, forKey: storeKey)
            legacy.removeObject(forKey: storeKey)
            NSLog("getup: migrated settings from legacy '\(suite)' UserDefaults suite")
            hadLegacy = true
        }
        let hasPriorData = hadLegacy || defaults.data(forKey: storeKey) != nil
        if let data = defaults.data(forKey: storeKey),
           let s = try? JSONDecoder().decode(Settings.self, from: data) {
            self.current = s
        } else {
            self.current = Settings()
        }
        if hasPriorData && !defaults.bool(forKey: firstRunKey) {
            defaults.set(true, forKey: firstRunKey)
            NSLog("getup: returning user, skipping first-run wizard")
        }
        applyLanguageOverride(current.language)
        runCustomAudioBackfill(detector: customAudioDetector)
    }

    /// One-time: if a pre-existing non-aiff sound.* sits in the support folder (user
    /// manually placed it before the picker UI shipped), tag it as custom audio so
    /// AudioLoopSync doesn't silently overwrite it on the next voice/phrase edit.
    private func runCustomAudioBackfill(detector: () -> URL?) {
        guard !defaults.bool(forKey: customAudioBackfillKey) else { return }
        defer { defaults.set(true, forKey: customAudioBackfillKey) }
        guard !current.useCustomAudio,
              let url = detector(),
              url.pathExtension.lowercased() != "aiff"
        else { return }
        current.useCustomAudio = true
        current.customAudioFilename = url.lastPathComponent
        NSLog("getup: backfilled custom audio from pre-existing \(url.lastPathComponent)")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: storeKey)
        }
    }

    // AppleLanguages override takes effect on next launch — Bundle locale resolves at startup.
    private func applyLanguageOverride(_ lang: String?) {
        if let lang {
            defaults.set([lang], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
