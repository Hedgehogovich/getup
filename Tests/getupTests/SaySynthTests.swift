import Foundation
import Testing
@testable import getup

@Suite("SaySynth — voice-list parser")
struct SaySynthTests {
    private static let canned = """
    Albert              en_US    # I have a frog in my throat. Sorry.
    Alice               it_IT    # Salve, mi chiamo Alice e sono una voce italiana.
    Bahh                en_US    # Do not pull the wool over my eyes.
    Milena              ru_RU    # Здравствуйте, меня зовут Милена. Я — русский голос.
    Tingting            zh_CN    # 您好，我叫 Tingting。我讲中文普通话。
    Bahh (Enhanced)     en_US    # Multi-word voice name with parens.
    Zarvox              en_US    # That looks like a peaceful planet.

    """

    @Test func parsesCannedSayOutput() {
        let voices = SaySynth.parseVoices(from: Self.canned)
        #expect(voices.count == 7)
    }

    @Test func handlesMultiWordVoiceName() {
        let voices = SaySynth.parseVoices(from: Self.canned)
        let bahhEnhanced = voices.first { $0.name == "Bahh (Enhanced)" }
        #expect(bahhEnhanced?.locale == "en_US")
    }

    @Test func sortedByNameCaseInsensitive() {
        let voices = SaySynth.parseVoices(from: Self.canned)
        let names = voices.map(\.name)
        // Albert, Alice, Bahh, Bahh (Enhanced), Milena, Tingting, Zarvox
        #expect(names == names.sorted { $0.lowercased() < $1.lowercased() })
    }

    @Test func handlesBlankAndCommentLines() {
        let input = """

        # this is a comment
        Albert              en_US    # blah

        Alice               it_IT
        """
        let voices = SaySynth.parseVoices(from: input)
        #expect(voices.count == 2)
        #expect(voices.contains { $0.name == "Albert" })
        #expect(voices.contains { $0.name == "Alice" })
    }

    @Test func emptyInputYieldsEmptyArray() {
        #expect(SaySynth.parseVoices(from: "").isEmpty)
    }

    @Test func handlesWhitespaceVarianceBetweenColumns() {
        // Apple's actual output uses padding to a fixed column; tabs vs spaces don't matter.
        let input = "Bahh\ten_US\t# tab-separated"
        let voices = SaySynth.parseVoices(from: input)
        #expect(voices.first?.name == "Bahh")
        #expect(voices.first?.locale == "en_US")
    }
}
