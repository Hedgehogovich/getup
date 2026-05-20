import Foundation
import AppKit
import UniformTypeIdentifiers

enum CustomAudio {
    enum InstallError: Error, Equatable {
        case unsupportedExtension(String)
        case ioFailure(String)
    }

    /// Standard macOS Open dialog filtered to audio types. Returns nil on cancel.
    /// Caller hands the URL to `install(from:)` which validates the extension.
    @MainActor
    static func showOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var types: [UTType] = [.audio]
        for t in [UTType.aiff, .mp3, .mpeg4Audio, .wav] { types.append(t) }
        panel.allowedContentTypes = types
        panel.message = NSLocalizedString("Choose an audio file to play during the reminder.",
                                          comment: "Open panel message for custom audio picker")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }

    /// Copy `source` into `dir` as `sound.<ext>`. Removes every other `sound.*` first so the
    /// loader picks the new file (and stale variants don't accumulate). Returns the source's
    /// filename for display in Settings.
    @discardableResult
    static func install(from source: URL, into dir: URL = AppPaths.supportDir) throws -> String {
        let ext = source.pathExtension.lowercased()
        guard AppPaths.soundExtensions.contains(ext) else {
            throw InstallError.unsupportedExtension(ext)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for variant in AppPaths.soundExtensions {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("sound.\(variant)"))
        }
        let dest = dir.appendingPathComponent("sound.\(ext)")
        do {
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            throw InstallError.ioFailure(error.localizedDescription)
        }
        return source.lastPathComponent
    }

    /// Wipe all `sound.*` so SaySynth.saveLoopIfMissing / AudioLoopSync regenerates fresh.
    static func revertToGenerated(in dir: URL = AppPaths.supportDir) {
        for ext in AppPaths.soundExtensions {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("sound.\(ext)"))
        }
    }

    /// One-shot preview via /usr/bin/afplay — matches SaySynth.preview's fire-and-forget pattern.
    @discardableResult
    static func previewCurrent() -> Process? {
        guard let url = AppPaths.existingSoundFile else { return nil }
        let p = Process()
        p.launchPath = "/usr/bin/afplay"
        p.arguments = [url.path]
        do { try p.run() } catch { return nil }
        return p
    }
}
