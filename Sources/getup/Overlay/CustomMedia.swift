import Foundation
import AppKit
import UniformTypeIdentifiers

enum CustomMedia {
    enum InstallError: Error, Equatable {
        case unsupportedExtension(String)
        case ioFailure(String)
    }

    @MainActor
    static func showOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var types: [UTType] = [.image, .gif]
        for t in [UTType.png, .jpeg, .mpeg4Movie, .quickTimeMovie] { types.append(t) }
        panel.allowedContentTypes = types
        panel.message = NSLocalizedString("Choose an image, GIF, or video to show during the reminder.",
                                          comment: "Open panel message for custom overlay media picker")
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url
    }

    /// Copy `source` into `dir` as `overlay.<ext>`. Wipes every other `overlay.*` first so the
    /// renderer picks the new file. Returns source filename for Settings display.
    @discardableResult
    static func install(from source: URL, into dir: URL = AppPaths.supportDir) throws -> String {
        let ext = source.pathExtension.lowercased()
        guard AppPaths.mediaExtensions.contains(ext) else {
            throw InstallError.unsupportedExtension(ext)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for variant in AppPaths.mediaExtensions {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("overlay.\(variant)"))
        }
        let dest = dir.appendingPathComponent("overlay.\(ext)")
        do {
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            throw InstallError.ioFailure(error.localizedDescription)
        }
        return source.lastPathComponent
    }

    static func revertToDefault(in dir: URL = AppPaths.supportDir) {
        for ext in AppPaths.mediaExtensions {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("overlay.\(ext)"))
        }
    }
}
