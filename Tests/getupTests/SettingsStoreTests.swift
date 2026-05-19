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
        // Check the suite's OWN persistent domain rather than `object(forKey:)`, because
        // UserDefaults reads cascade through NSGlobalDomain and Apple's other domains —
        // CI runners ship with `AppleLanguages=["en-US"]` in NSGlobalDomain, which would
        // bubble up to a cascaded read even after our suite's key is removed.
        let storedDomain = UserDefaults().persistentDomain(forName: suite) ?? [:]
        #expect(storedDomain["AppleLanguages"] == nil)
    }

    @Test func customAudioBackfill_detectsPreExistingMP3() throws {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let detectedURL = URL(fileURLWithPath: "/tmp/sound.mp3")
        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil,
            customAudioBackfillKey: "test.customAudioBackfill",
            customAudioDetector: { detectedURL }
        )

        #expect(store.current.useCustomAudio == true)
        #expect(store.current.customAudioFilename == "sound.mp3")
        #expect(defaults.bool(forKey: "test.customAudioBackfill") == true)
    }

    @Test func customAudioBackfill_isIdempotent() {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // Mark backfill done before init. Detector returning an mp3 must NOT re-flip the flag.
        defaults.set(true, forKey: "test.customAudioBackfill")

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil,
            customAudioBackfillKey: "test.customAudioBackfill",
            customAudioDetector: { URL(fileURLWithPath: "/tmp/sound.mp3") }
        )

        #expect(store.current.useCustomAudio == false)
        #expect(store.current.customAudioFilename == nil)
    }

    @Test func customAudioBackfill_ignoresAIFF() {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // AIFF = generated. Backfill must NOT misclassify it as custom.
        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil,
            customAudioBackfillKey: "test.customAudioBackfill",
            customAudioDetector: { URL(fileURLWithPath: "/tmp/sound.aiff") }
        )

        #expect(store.current.useCustomAudio == false)
        #expect(store.current.customAudioFilename == nil)
        // Flag still gets set so we don't re-run the detector forever.
        #expect(defaults.bool(forKey: "test.customAudioBackfill") == true)
    }

    @Test func customAudioBackfill_noFileNoOp() {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil,
            customAudioBackfillKey: "test.customAudioBackfill",
            customAudioDetector: { nil }
        )

        #expect(store.current.useCustomAudio == false)
        #expect(defaults.bool(forKey: "test.customAudioBackfill") == true)
    }

    @Test func customAudioBackfill_doesNotOverrideExplicitTrue() throws {
        let (defaults, suite) = Self.makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        // User explicitly picked an mp3 via the picker — useCustomAudio already true.
        // The detector finding a different file MUST NOT clobber the persisted filename.
        var seed = Settings()
        seed.useCustomAudio = true
        seed.customAudioFilename = "user-pick.mp3"
        defaults.set(try JSONEncoder().encode(seed), forKey: "test.settings")

        let store = SettingsStore(
            defaults: defaults,
            storeKey: "test.settings",
            firstRunKey: "test.firstRun",
            legacySuiteName: nil,
            customAudioBackfillKey: "test.customAudioBackfill",
            customAudioDetector: { URL(fileURLWithPath: "/tmp/something-else.wav") }
        )

        #expect(store.current.customAudioFilename == "user-pick.mp3")
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
