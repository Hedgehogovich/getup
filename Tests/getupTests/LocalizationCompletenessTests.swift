import Foundation
import Testing

/// Loads every `Resources/<lang>.lproj/Localizable.strings` from disk and checks that
/// every key present in the English baseline is also present in every other locale —
/// minus an explicit deferred-translation allowlist.
///
/// Why: macOS Cocoa silently falls back to the base locale when a key is missing, so a
/// regression in a non-English file is only visible at runtime. This test fails fast.
@Suite("Localization completeness")
struct LocalizationCompletenessTests {
    /// Resources/<lang>.lproj root, resolved by walking up from this test file's path.
    private static var resourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Tests/getupTests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // repo root
            .appendingPathComponent("Resources")
    }

    private static let deferredPerLocale: [String: Set<String>] = [:]

    private static func loadKeys(_ url: URL) -> Set<String>? {
        guard let dict = NSDictionary(contentsOf: url) as? [String: String] else { return nil }
        return Set(dict.keys)
    }

    private static func lprojDirs() -> [(code: String, url: URL)] {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(at: resourcesDir, includingPropertiesForKeys: nil)) ?? []
        return entries
            .filter { $0.pathExtension == "lproj" }
            .map { (String($0.lastPathComponent.dropLast(".lproj".count)), $0) }
            .sorted { $0.code < $1.code }
    }

    @Test func englishBaselineIsParseable() throws {
        let en = Self.resourcesDir.appendingPathComponent("en.lproj/Localizable.strings")
        let keys = Self.loadKeys(en)
        #expect(keys != nil, "en.lproj/Localizable.strings missing or unparseable")
        #expect((keys ?? []).isEmpty == false)
    }

    @Test func everyLocaleCoversAllEnglishKeys_minusAllowlist() throws {
        let en = Self.resourcesDir.appendingPathComponent("en.lproj/Localizable.strings")
        let englishKeys = try #require(Self.loadKeys(en))

        var missingByLocale: [String: [String]] = [:]
        for (code, url) in Self.lprojDirs() where code != "en" && code != "Base" {
            let path = url.appendingPathComponent("Localizable.strings")
            guard let keys = Self.loadKeys(path) else {
                Issue.record("Could not parse \(code).lproj/Localizable.strings")
                continue
            }
            let allowed = Self.deferredPerLocale[code] ?? []
            let missing = englishKeys.subtracting(keys).subtracting(allowed)
            if !missing.isEmpty {
                missingByLocale[code] = missing.sorted()
            }
        }

        #expect(missingByLocale.isEmpty, "Locales missing translations: \(missingByLocale)")
    }

    @Test func noLocaleHasOrphanKeysAbsentFromEnglish() throws {
        // Reverse direction: catches keys that were renamed in en/ but left dangling
        // elsewhere. These don't crash anything but waste reviewer attention.
        let en = Self.resourcesDir.appendingPathComponent("en.lproj/Localizable.strings")
        let englishKeys = try #require(Self.loadKeys(en))

        var orphansByLocale: [String: [String]] = [:]
        for (code, url) in Self.lprojDirs() where code != "en" && code != "Base" {
            let path = url.appendingPathComponent("Localizable.strings")
            guard let keys = Self.loadKeys(path) else { continue }
            let orphans = keys.subtracting(englishKeys)
            if !orphans.isEmpty {
                orphansByLocale[code] = orphans.sorted()
            }
        }

        #expect(orphansByLocale.isEmpty, "Locales with keys not in English baseline: \(orphansByLocale)")
    }
}
