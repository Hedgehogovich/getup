import Foundation
import Testing
@testable import getup

@Suite("LogRotation — pure rotateFileIfNeeded")
struct LogRotationTests {
    private static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("getup-logrotation-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// `count` ASCII bytes of repeating filler — distinct head/tail so we can verify
    /// the tail-keeping behavior.
    private static func writeFile(_ url: URL, headBytes: Int, tailBytes: Int) throws {
        var data = Data(count: headBytes)
        for i in 0..<headBytes { data[i] = UInt8(ascii: "A") }
        var tail = Data(count: tailBytes)
        for i in 0..<tailBytes { tail[i] = UInt8(ascii: "B") }
        data.append(tail)
        try data.write(to: url)
    }

    @Test func underThresholdIsNoOp() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("getup.err")
        try Self.writeFile(url, headBytes: 100, tailBytes: 100)
        let before = try Data(contentsOf: url)

        LogRotation.rotateFileIfNeeded(at: url, maxBytes: 1_000)

        let after = try Data(contentsOf: url)
        #expect(after == before)
    }

    @Test func oversizeTruncatesToLastNBytes() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("getup.err")
        // 500 bytes 'A' + 200 bytes 'B'. Rotate to keep last 200.
        try Self.writeFile(url, headBytes: 500, tailBytes: 200)

        LogRotation.rotateFileIfNeeded(at: url, maxBytes: 200)

        let after = try Data(contentsOf: url)
        #expect(after.count == 200)
        for byte in after { #expect(byte == UInt8(ascii: "B")) }
    }

    @Test func equalToThresholdIsNoOp() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("getup.err")
        try Self.writeFile(url, headBytes: 0, tailBytes: 1_000)
        let before = try Data(contentsOf: url)

        LogRotation.rotateFileIfNeeded(at: url, maxBytes: 1_000)

        let after = try Data(contentsOf: url)
        #expect(after == before)
    }

    @Test func missingFileIsNoOpNoThrow() {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("does-not-exist.err")

        LogRotation.rotateFileIfNeeded(at: url, maxBytes: 100)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func zeroByteFileIsNoOp() throws {
        let dir = Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("getup.err")
        try Data().write(to: url)

        LogRotation.rotateFileIfNeeded(at: url, maxBytes: 100)

        let after = try Data(contentsOf: url)
        #expect(after.isEmpty)
    }
}
