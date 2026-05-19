import Foundation
import SwiftUI

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

    private let storeKey: String
    private let firstRunKey: String
    private let defaults: UserDefaults

    var isFirstRun: Bool { !defaults.bool(forKey: firstRunKey) }
    func markFirstRunComplete() { defaults.set(true, forKey: firstRunKey) }

    init(
        defaults: UserDefaults = .standard,
        storeKey: String = "getup.settings.v1",
        firstRunKey: String = SettingsStore.firstRunKey,
        legacySuiteName: String? = "getup"
    ) {
        self.defaults = defaults
        self.storeKey = storeKey
        self.firstRunKey = firstRunKey

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
