import Foundation
import Testing
@testable import getup

@Suite("LocaleHelper — voice-locale mapping")
struct LocaleHelperTests {
    @Test func zhHansMapsToZhCN() {
        // Apple's `say` voices for Simplified Chinese ship under zh_CN.
        #expect(LocaleHelper.voiceLocalePrefix("zh-Hans") == "zh_CN")
    }

    @Test func zhHantMapsToZhTW() {
        #expect(LocaleHelper.voiceLocalePrefix("zh-Hant") == "zh_TW")
    }

    @Test func ptBRPreservesRegion() {
        #expect(LocaleHelper.voiceLocalePrefix("pt-BR") == "pt_BR")
    }

    @Test func plainTwoLetterPassesThrough() {
        #expect(LocaleHelper.voiceLocalePrefix("ru") == "ru")
        #expect(LocaleHelper.voiceLocalePrefix("ja") == "ja")
    }

    @Test func caseInsensitiveOnSpecialCases() {
        // The zh-Hans branch uses .lowercased() so "ZH-Hans" should still resolve.
        #expect(LocaleHelper.voiceLocalePrefix("ZH-HANS") == "zh_CN")
    }
}
