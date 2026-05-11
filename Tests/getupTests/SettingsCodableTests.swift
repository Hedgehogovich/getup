import Foundation
import Testing
@testable import getup

@Suite("Settings Codable round-trip")
struct SettingsCodableTests {
    @Test func defaultRoundTrip() throws {
        let s = Settings()
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded == s)
    }

    @Test func mutatedRoundTrip() throws {
        var s = Settings()
        s.audioMode = .always
        s.fireMinute = 30
        s.volume = 0.42
        s.voice = "Alex"
        s.customPhrase = "stand up"
        s.language = "el"
        s.showInDock = true
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded == s)
    }

    /// Forward-compat: settings JSON written before a new field was added must still decode,
    /// using defaults for the missing field. Catches the case where someone adds a non-optional
    /// field without supplying a default in the model.
    @Test func decodesLegacyJSONMissingNewField() throws {
        // Pre-language-field shape (from before Step 3 i18n landed).
        let json = Data("""
        {
          "audioMode": "headphonesOnly",
          "fireMinute": 50,
          "volume": 0.7,
          "voice": "Zarvox",
          "customPhrase": "hi"
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: json)
        #expect(decoded.language == nil)
        #expect(decoded.fireMinute == 50)
        #expect(decoded.customPhrase == "hi")
    }

    /// Same forward-compat guarantee for the non-optional `showInDock` field added later.
    /// Without the custom decodeIfPresent-based init, existing users' JSON (written before
    /// the Dock toggle existed) would fail to decode and silently revert to defaults.
    @Test func decodesLegacyJSONMissingShowInDock() throws {
        let json = Data("""
        {
          "audioMode": "always",
          "fireMinute": 50,
          "volume": 0.7,
          "voice": "Zarvox",
          "customPhrase": "hi",
          "language": "fr"
        }
        """.utf8)
        let decoded = try JSONDecoder().decode(Settings.self, from: json)
        #expect(decoded.showInDock == false)            // default kicks in
        #expect(decoded.audioMode == .always)           // existing fields preserved
        #expect(decoded.language == "fr")
    }

    @Test func decodingGarbageThrows() {
        let bad = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(Settings.self, from: bad)
        }
    }
}
