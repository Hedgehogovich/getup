import Foundation
import Testing
@testable import getup

/// Pure file I/O tests for the custom-audio install + revert helpers. NSOpenPanel is
/// not exercised here — that's UI-side and tested manually.
@Suite("CustomAudio — install + revert")
struct CustomAudioTests {
    private static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("getup-customaudio-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes a tiny placeholder file at `url`. Content doesn't have to be valid audio —
    /// `install` only inspects extension + does a copy.
    private static func placePlaceholder(at url: URL, content: String = "hello") throws {
        try content.data(using: .utf8)!.write(to: url)
    }

    @Test func install_copiesSourceAndReturnsFilename() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let src = dir.appendingPathComponent("bell.mp3")
        try Self.placePlaceholder(at: src)

        let filename = try CustomAudio.install(from: src, into: dir)
        #expect(filename == "bell.mp3")

        let installed = dir.appendingPathComponent("sound.mp3")
        #expect(FileManager.default.fileExists(atPath: installed.path))
    }

    @Test func install_removesOtherSoundExtensions() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Seed stale sound.aiff + sound.wav. Both must be removed when an mp3 is installed.
        try Self.placePlaceholder(at: dir.appendingPathComponent("sound.aiff"))
        try Self.placePlaceholder(at: dir.appendingPathComponent("sound.wav"))

        let src = dir.appendingPathComponent("chime.m4a")
        try Self.placePlaceholder(at: src)
        _ = try CustomAudio.install(from: src, into: dir)

        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("sound.m4a").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("sound.aiff").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("sound.wav").path))
    }

    @Test func install_rejectsUnsupportedExtension() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let src = dir.appendingPathComponent("track.flac")
        try Self.placePlaceholder(at: src)

        #expect(throws: CustomAudio.InstallError.self) {
            _ = try CustomAudio.install(from: src, into: dir)
        }
    }

    @Test func install_caseInsensitiveExtensionMatch() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let src = dir.appendingPathComponent("BELL.MP3")
        try Self.placePlaceholder(at: src)
        let filename = try CustomAudio.install(from: src, into: dir)
        #expect(filename == "BELL.MP3")
        // Destination is normalized to lowercase ext so the loader (which iterates
        // lowercase soundExtensions) finds it.
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("sound.mp3").path))
    }

    @Test func revertToGenerated_wipesAllSoundFiles() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Self.placePlaceholder(at: dir.appendingPathComponent("sound.mp3"))
        try Self.placePlaceholder(at: dir.appendingPathComponent("sound.aiff"))

        CustomAudio.revertToGenerated(in: dir)

        for ext in AppPaths.soundExtensions {
            let path = dir.appendingPathComponent("sound.\(ext)").path
            #expect(!FileManager.default.fileExists(atPath: path), "\(ext) should be gone")
        }
    }

    @Test func revertToGenerated_isNoOpWhenEmpty() {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Should not throw, should not crash.
        CustomAudio.revertToGenerated(in: dir)
    }
}
