import Foundation

enum LocaleHelper {
    /// Bundle-loaded localizations (excluding "Base"), deduped, sorted by native name.
    /// `Bundle.localizations` returns the union of physical `.lproj` dirs and
    /// `CFBundleLocalizations` without dedup, so we wrap in `Set`.
    static var availableLanguages: [String] {
        Array(Set(Bundle.main.localizations))
            .filter { $0 != "Base" }
            .sorted { nativeName($0).localizedCaseInsensitiveCompare(nativeName($1)) == .orderedAscending }
    }

    /// Language display name in its own locale ("Español", "日本語", ...).
    static func nativeName(_ code: String) -> String {
        let loc = Locale(identifier: code)
        let name = loc.localizedString(forIdentifier: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    /// Loads the bundle for a specific localization. Used to render UI in a not-yet-active
    /// language (e.g. wizard step 2 right after the user picks).
    static func bundle(forLocale code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    /// English baseline phrase used when localization or matching voice is unavailable.
    static let englishLoopPhrase = "Movement protocol initiated. Please stand and stretch. Resistance is futile."

    /// Compute the (phrase, voice) pair to seed for the first-run wizard.
    /// Rule: we pick the localized phrase + matching `say` voice **only if both exist** for
    /// the requested language. Otherwise fall back to English for both — never mix English
    /// audio with localized text or vice versa.
    /// - `language`: explicit pick from settings (e.g. "ru", "pt-BR"); nil = "System default".
    ///   nil resolves through `Bundle.preferredLocalizations` so system pt_BR maps to our pt-BR .lproj.
    /// - `available`: voice list from `SaySynth.listVoices()`.
    static func defaultLoopDefaults(forLanguage language: String?, available: [SayVoice]) -> (phrase: String, voice: String?) {
        let englishVoice = available.first(where: { $0.locale.lowercased().hasPrefix("en_us") })?.name
            ?? available.first?.name
        let resolved = resolveLocalization(forLanguage: language)

        if let lang = resolved,
           let phrase = translatedLoopPhrase(forLanguage: lang),
           let voice = voiceMatching(language: lang, available: available) {
            return (phrase, voice)
        }
        return (englishLoopPhrase, englishVoice)
    }

    /// Apple's localization negotiation: maps explicit picks AND nil-system-default to a
    /// .lproj code that actually exists in the bundle. Returns nil if even English isn't found
    /// (which would be a packaging bug).
    private static func resolveLocalization(forLanguage language: String?) -> String? {
        let bundleLocs = Bundle.main.localizations.filter { $0 != "Base" }
        if let lang = language {
            return Bundle.preferredLocalizations(from: bundleLocs, forPreferences: [lang]).first
        }
        return Bundle.preferredLocalizations(from: bundleLocs).first
    }

    /// Returns the localized "defaultPhrase" string from `<lang>.lproj/Localizable.strings`,
    /// or nil if the bundle has no override. We probe with a sentinel value so we can
    /// distinguish "missing key" from "translation happens to equal the key".
    private static func translatedLoopPhrase(forLanguage language: String) -> String? {
        guard let bundle = LocaleHelper.bundle(forLocale: language) else { return nil }
        let sentinel = "__getup_no_translation__"
        let s = bundle.localizedString(forKey: "defaultPhrase", value: sentinel, table: nil)
        return (s == sentinel || s.isEmpty) ? nil : s
    }

    /// First voice whose locale matches the language. e.g. "ru" → "Milena" (ru_RU),
    /// "zh-Hans" → "Tingting" (zh_CN). Returns nil when no match — caller decides fallback.
    private static func voiceMatching(language: String, available: [SayVoice]) -> String? {
        let prefix = voiceLocalePrefix(language).lowercased()
        return available.first(where: { $0.locale.lowercased().hasPrefix(prefix) })?.name
    }

    /// Map a CFBundleLocalizations code (e.g. "pt-BR", "zh-Hans") to the `say` voice locale
    /// prefix we want to match against (e.g. "pt_BR", "zh_CN"). Apple's TTS voices for
    /// Simplified Chinese ship under zh_CN, not zh_Hans.
    static func voiceLocalePrefix(_ lang: String) -> String {
        switch lang.lowercased() {
        case "zh-hans": return "zh_CN"
        case "zh-hant": return "zh_TW"
        default:        return lang.replacingOccurrences(of: "-", with: "_")
        }
    }
}
