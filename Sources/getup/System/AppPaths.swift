import Foundation

enum AppPaths {
    static var supportDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/getup")
    }

    /// First existing file wins; `SaySynth.saveLoop` must remove the others before writing aiff.
    static let soundExtensions = ["mp3", "m4a", "wav", "aiff"]

    static var soundFileCandidates: [URL] {
        soundExtensions.map { supportDir.appendingPathComponent("sound.\($0)") }
    }

    /// First match wins — same order as the AVAudioPlayer loader at fire time.
    static var existingSoundFile: URL? {
        soundFileCandidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static var loopAIFF: URL {
        supportDir.appendingPathComponent("sound.aiff")
    }

    static var stdoutLog: URL { supportDir.appendingPathComponent("getup.log") }
    static var stderrLog: URL { supportDir.appendingPathComponent("getup.err") }
}
