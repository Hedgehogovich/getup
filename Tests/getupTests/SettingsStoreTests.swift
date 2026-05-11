import Foundation
import Testing
@testable import getup

/// Tests use a unique-per-suite `UserDefaults` so they don't touch the real
/// `com.ychachilo.getup` domain or contaminate each other.
@Suite("SettingsStore — persistence + migration + first-run flag")
struct SettingsStoreTests {
    private static func makeDefaults() -> (UserDefaults, String) {
        let suite = "test-getup-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test func freshInstall_defaultsAndFirstRunFlag() {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil
        )
        #expect(store.current == Settings())
        #expect(store.isFirstRun == true)
    }

    @Test func priorData_skipsFirstRunWizard() throws {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        var seed = Settings()
        seed.fireMinute = 30
        seed.voice = "Alex"
        defaults.set(try JSONEncoder().encode(seed), forKey: "test.settings")

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil
        )
        #expect(store.current.fireMinute == 30)
        #expect(store.current.voice == "Alex")
        #expect(store.isFirstRun == false)
    }

    @Test func legacySuiteMigratesOnce() throws {
        let (defaults, suite) = Self.makeDefaults()
        let legacySuite = "test-legacy-\(UUID().uuidString)"
        let legacy = UserDefaults(suiteName: legacySuite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
            legacy.removePersistentDomain(forName: legacySuite)
        }

        var seed = Settings()
        seed.audioMode = .always
        legacy.set(try JSONEncoder().encode(seed), forKey: "test.settings")

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: legacySuite
        )

        #expect(store.current.audioMode == .always)
        #expect(legacy.data(forKey: "test.settings") == nil) // moved out of legacy
        #expect(defaults.data(forKey: "test.settings") != nil) // and into the new domain
        #expect(store.isFirstRun == false) // migrated user shouldn't re-see the wizard
    }

    @Test func mutationsPersistViaDidSet() throws {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil
        )
        store.current.fireMinute = 15

        let raw = try #require(defaults.data(forKey: "test.settings"))
        let decoded = try JSONDecoder().decode(Settings.self, from: raw)
        #expect(decoded.fireMinute == 15)
    }

    @Test func languageOverride_writesAppleLanguagesArray() {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil
        )
        store.current.language = "el"
        #expect(defaults.array(forKey: "AppleLanguages") as? [String] == ["el"])
    }

    @Test func languageNil_clearsAppleLanguagesArray() throws {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        var seed = Settings()
        seed.language = "el"
        defaults.set(try JSONEncoder().encode(seed), forKey: "test.settings")
        defaults.set(["el"], forKey: "AppleLanguages")

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil
        )
        // init reconciles AppleLanguages with stored language — so it's still ["el"]
        #expect(defaults.array(forKey: "AppleLanguages") as? [String] == ["el"])
        store.current.language = nil
        #expect(defaults.object(forKey: "AppleLanguages") == nil)
    }

    @Test func markFirstRunComplete_persists() {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil
        )
        #expect(store.isFirstRun == true)
        store.markFirstRunComplete()
        #expect(store.isFirstRun == false)
        #expect(defaults.bool(forKey: "test.firstRun") == true)
    }
}
