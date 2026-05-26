import Foundation
import Testing
@testable import getup

@Suite("AudioMode — rawValue + displayName")
struct AudioModeTests {
    /// Locks the `rawValue` strings; changing them silently invalidates existing user JSON.
    @Test func rawValueStability() {
        #expect(AudioMode.headphonesOnly.rawValue == "headphonesOnly")
        #expect(AudioMode.always.rawValue == "always")
        #expect(AudioMode.silent.rawValue == "silent")
    }

    @Test func roundTripCodable() throws {
        for mode in AudioMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(AudioMode.self, from: data)
            #expect(decoded == mode)
        }
    }

    @Test func decodesKnownRawValues() throws {
        let pairs: [(String, AudioMode)] = [
            ("\"headphonesOnly\"", .headphonesOnly),
            ("\"always\"", .always),
            ("\"silent\"", .silent),
        ]
        for (json, expected) in pairs {
            let decoded = try JSONDecoder().decode(AudioMode.self, from: Data(json.utf8))
            #expect(decoded == expected)
        }
    }

    @Test func unknownRawValueThrows() {
        let bad = Data("\"loud\"".utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(AudioMode.self, from: bad)
        }
    }

    @Test func allCasesCovered() {
        #expect(AudioMode.allCases.count == 3)
    }

    @Test func displayNamesNonEmpty() {
        for mode in AudioMode.allCases {
            #expect(!mode.displayName.isEmpty)
        }
    }
}
