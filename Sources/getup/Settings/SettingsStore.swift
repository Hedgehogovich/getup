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

    /// True when first-run wizard hasn't been completed (or dismissed) yet.
    var isFirstRun: Bool { !defaults.bool(forKey: firstRunKey) }
    func markFirstRunComplete() { defaults.set(true, forKey: firstRunKey) }

    /// Designated init. Parameterized for tests; production path uses defaults that match
    /// the bundled-app domain. `legacySuiteName` triggers the one-time pre-bundle migration.
    init(
        defaults: UserDefaults = .standard,
        storeKey: String = "getup.settings.v1",
        firstRunKey: String = SettingsStore.firstRunKey,
        legacySuiteName: String? = "getup"
    ) {
        self.defaults = defaults
        self.storeKey = storeKey
        self.firstRunKey = firstRunKey

        // One-time migration: pre-bundle binary stored under the suite "getup" (executable name).
        // After bundling, our suite is "com.ychachilo.getup" via CFBundleIdentifier.
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
        // Returning users (any prior settings on disk) skip the wizard.
        if hasPriorData && !defaults.bool(forKey: firstRunKey) {
            defaults.set(true, forKey: firstRunKey)
            NSLog("getup: returning user, skipping first-run wizard")
        }
        // Reconcile AppleLanguages with our setting at launch — handles users who manually
        // wrote AppleLanguages with `defaults` and then reinstalled.
        applyLanguageOverride(current.language)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: storeKey)
        }
    }

    /// Writes/clears the per-app `AppleLanguages` override. Takes effect on next process launch
    /// because NSLocalizedString resolves the bundle's locale at startup.
    private func applyLanguageOverride(_ lang: String?) {
        if let lang {
            defaults.set([lang], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}
