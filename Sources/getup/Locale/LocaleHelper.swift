import Foundation

enum LocaleHelper {
    static var availableLanguages: [String] {
        // Bundle.localizations dedups inconsistently; wrap in Set.
        Array(Set(Bundle.main.localizations))
            .filter { $0 != "Base" }
            .sorted { nativeName($0).localizedCaseInsensitiveCompare(nativeName($1)) == .orderedAscending }
    }

    static func nativeName(_ code: String) -> String {
        let loc = Locale(identifier: code)
        let name = loc.localizedString(forIdentifier: code) ?? code
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    static func bundle(forLocale code: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    static let englishLoopPhrase = "Movement protocol initiated. Please stand and stretch. Resistance is futile."

    /// Locale-coupling rule: localized phrase + matching `say` voice only if BOTH exist.
    /// Otherwise fall back to English for both — never mix English audio with localized text.
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

    private static func resolveLocalization(forLanguage language: String?) -> String? {
        let bundleLocs = Bundle.main.localizations.filter { $0 != "Base" }
        if let lang = language {
            return Bundle.preferredLocalizations(from: bundleLocs, forPreferences: [lang]).first
        }
        return Bundle.preferredLocalizations(from: bundleLocs).first
    }

    private static func translatedLoopPhrase(forLanguage language: String) -> String? {
        guard let bundle = LocaleHelper.bundle(forLocale: language) else { return nil }
        // Sentinel distinguishes "missing key" from "translation happens to equal the key".
        let sentinel = "__getup_no_translation__"
        let s = bundle.localizedString(forKey: "defaultPhrase", value: sentinel, table: nil)
        return (s == sentinel || s.isEmpty) ? nil : s
    }

    private static func voiceMatching(language: String, available: [SayVoice]) -> String? {
        let prefix = voiceLocalePrefix(language).lowercased()
        return available.first(where: { $0.locale.lowercased().hasPrefix(prefix) })?.name
    }

    /// Apple's TTS voices for Simplified Chinese ship under zh_CN, not zh_Hans.
    static func voiceLocalePrefix(_ lang: String) -> String {
        switch lang.lowercased() {
        case "zh-hans": return "zh_CN"
        case "zh-hant": return "zh_TW"
        default:        return lang.replacingOccurrences(of: "-", with: "_")
        }
    }
}
