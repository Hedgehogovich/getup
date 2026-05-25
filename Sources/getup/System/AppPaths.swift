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

    /// Custom overlay media. First match wins. GIFs/videos preserved as-is.
    static let mediaExtensions = ["png", "jpg", "jpeg", "gif", "mp4", "mov"]

    static var mediaFileCandidates: [URL] {
        mediaExtensions.map { supportDir.appendingPathComponent("overlay.\($0)") }
    }

    static var existingMediaFile: URL? {
        mediaFileCandidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static var stdoutLog: URL { supportDir.appendingPathComponent("getup.log") }
    static var stderrLog: URL { supportDir.appendingPathComponent("getup.err") }
}
