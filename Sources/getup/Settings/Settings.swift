import Foundation

struct Settings: Codable, Equatable, Sendable {
    var audioMode: AudioMode = .headphonesOnly
    var fireMinute: Int = 50
    var volume: Double = 0.7
    var voice: String = "Zarvox"
    var customPhrase: String = "Movement protocol initiated. Please stand and stretch. Resistance is futile."
    var language: String? = nil  // nil = system default; otherwise a CFBundleLocalizations code
    var showInDock: Bool = false
    var useCustomAudio: Bool = false
    var customAudioFilename: String? = nil
    var overlayAutoDismissSeconds: Int? = nil   // nil = manual dismiss only
    var quietHoursEnabled: Bool = false
    var quietHoursStartMinutes: Int = 22 * 60   // minutes since midnight (10:00 PM)
    var quietHoursEndMinutes: Int = 7 * 60      // minutes since midnight (7:00 AM)

    init() {}

    // decodeIfPresent on every field so adding non-optional fields doesn't discard returning users' JSON.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        self.audioMode           = try c.decodeIfPresent(AudioMode.self, forKey: .audioMode)           ?? d.audioMode
        self.fireMinute          = try c.decodeIfPresent(Int.self,       forKey: .fireMinute)          ?? d.fireMinute
        self.volume              = try c.decodeIfPresent(Double.self,    forKey: .volume)              ?? d.volume
        self.voice               = try c.decodeIfPresent(String.self,    forKey: .voice)               ?? d.voice
        self.customPhrase        = try c.decodeIfPresent(String.self,    forKey: .customPhrase)        ?? d.customPhrase
        self.language            = try c.decodeIfPresent(String.self,    forKey: .language)
        self.showInDock          = try c.decodeIfPresent(Bool.self,      forKey: .showInDock)          ?? d.showInDock
        self.useCustomAudio      = try c.decodeIfPresent(Bool.self,      forKey: .useCustomAudio)      ?? d.useCustomAudio
        self.customAudioFilename = try c.decodeIfPresent(String.self,    forKey: .customAudioFilename)
        self.overlayAutoDismissSeconds = try c.decodeIfPresent(Int.self, forKey: .overlayAutoDismissSeconds)
        self.quietHoursEnabled       = try c.decodeIfPresent(Bool.self,  forKey: .quietHoursEnabled)       ?? d.quietHoursEnabled
        self.quietHoursStartMinutes  = try c.decodeIfPresent(Int.self,   forKey: .quietHoursStartMinutes)  ?? d.quietHoursStartMinutes
        self.quietHoursEndMinutes    = try c.decodeIfPresent(Int.self,   forKey: .quietHoursEndMinutes)    ?? d.quietHoursEndMinutes
    }
}
