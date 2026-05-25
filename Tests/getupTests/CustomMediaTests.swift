import Foundation
import Testing
@testable import getup

@Suite("CustomMedia — install + revert")
struct CustomMediaTests {
    private static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("getup-custommedia-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func placePlaceholder(at url: URL, content: String = "blob") throws {
        try content.data(using: .utf8)!.write(to: url)
    }

    @Test func install_copiesSourceAndReturnsFilename() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let src = dir.appendingPathComponent("reaction.gif")
        try Self.placePlaceholder(at: src)

        let filename = try CustomMedia.install(from: src, into: dir)
        #expect(filename == "reaction.gif")
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("overlay.gif").path))
    }

    @Test func install_removesOtherMediaExtensions() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Self.placePlaceholder(at: dir.appendingPathComponent("overlay.png"))
        try Self.placePlaceholder(at: dir.appendingPathComponent("overlay.mp4"))

        let src = dir.appendingPathComponent("new.gif")
        try Self.placePlaceholder(at: src)
        _ = try CustomMedia.install(from: src, into: dir)

        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("overlay.gif").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("overlay.png").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("overlay.mp4").path))
    }

    @Test func install_rejectsUnsupportedExtension() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let src = dir.appendingPathComponent("clip.webm")
        try Self.placePlaceholder(at: src)

        #expect(throws: CustomMedia.InstallError.self) {
            _ = try CustomMedia.install(from: src, into: dir)
        }
    }

    @Test func install_caseInsensitiveExtensionMatch() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let src = dir.appendingPathComponent("PIC.JPG")
        try Self.placePlaceholder(at: src)
        let filename = try CustomMedia.install(from: src, into: dir)
        #expect(filename == "PIC.JPG")
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("overlay.jpg").path))
    }

    @Test func revertToDefault_wipesAllMediaFiles() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Self.placePlaceholder(at: dir.appendingPathComponent("overlay.gif"))
        try Self.placePlaceholder(at: dir.appendingPathComponent("overlay.mp4"))

        CustomMedia.revertToDefault(in: dir)

        for ext in AppPaths.mediaExtensions {
            #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("overlay.\(ext)").path))
        }
    }

    @Test func revertToDefault_isNoOpWhenEmpty() {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        CustomMedia.revertToDefault(in: dir)
    }
}
