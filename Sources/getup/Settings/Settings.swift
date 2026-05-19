import Foundation

struct Settings: Codable, Equatable {
    var audioMode: AudioMode = .headphonesOnly  // headphones-only is the safe default for shared spaces
    var fireMinute: Int = 50                    // matches Apple Watch Stand reminders
    var volume: Double = 0.7                    // 0.0 ... 1.0; applied to AVAudioPlayer
    var voice: String = "Zarvox"                // `say -v <voice>` — must exist locally
    var customPhrase: String = "Movement protocol initiated. Please stand and stretch. Resistance is futile."
    var language: String? = nil                 // nil = follow macOS; otherwise a CFBundleLocalizations code (en, es, el, ...)
    var showInDock: Bool = false                // false = LSUIElement-only (menu bar); true = also show in Dock + Cmd-Tab

    // Forward-compat: decodeIfPresent on every field so adding new non-optional fields doesn't
    // discard a returning user's existing JSON. Synthesized init(from:) would throw on the first
    // missing key — see SettingsCodableTests.decodesLegacyJSONMissingNewField.
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        self.audioMode    = try c.decodeIfPresent(AudioMode.self, forKey: .audioMode)    ?? d.audioMode
        self.fireMinute   = try c.decodeIfPresent(Int.self,       forKey: .fireMinute)   ?? d.fireMinute
        self.volume       = try c.decodeIfPresent(Double.self,    forKey: .volume)       ?? d.volume
        self.voice        = try c.decodeIfPresent(String.self,    forKey: .voice)        ?? d.voice
        self.customPhrase = try c.decodeIfPresent(String.self,    forKey: .customPhrase) ?? d.customPhrase
        self.language     = try c.decodeIfPresent(String.self,    forKey: .language)
        self.showInDock   = try c.decodeIfPresent(Bool.self,      forKey: .showInDock)   ?? d.showInDock
    }
}
