import Foundation

/// Shared filesystem paths. Centralized so the audio loader, the loop writer, the wizard
/// safety-net, and the LaunchAgent installer all agree on locations and extension priority.
enum AppPaths {
    /// `~/Library/Application Support/getup`. Holds the loop audio file and launchd stdout/stderr
    /// logs. Settings themselves live in UserDefaults, not here.
    static var supportDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/getup")
    }

    /// Audio loader priority order. The first existing file wins, so writing
    /// `sound.aiff` while a stale `sound.mp3` is still on disk silently no-ops.
    /// Keep `saveLoop` aligned with this list — it must remove every other extension
    /// before writing the new aiff.
    static let soundExtensions = ["mp3", "m4a", "wav", "aiff"]

    static var soundFileCandidates: [URL] {
        soundExtensions.map { supportDir.appendingPathComponent("sound.\($0)") }
    }

    static var loopAIFF: URL {
        supportDir.appendingPathComponent("sound.aiff")
    }

    static var stdoutLog: URL { supportDir.appendingPathComponent("getup.log") }
    static var stderrLog: URL { supportDir.appendingPathComponent("getup.err") }
}
