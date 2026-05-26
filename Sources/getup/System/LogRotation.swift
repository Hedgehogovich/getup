import Foundation

enum LogRotation {
    static let maxBytes = 1_000_000

    /// launchd never rotates StandardErrorPath; trim the tail at every launch.
    static func rotateIfNeeded(at url: URL = AppPaths.stderrLog) {
        rotateFileIfNeeded(at: url, maxBytes: maxBytes)
    }

    /// Pure helper — truncates `url` to its trailing `maxBytes` bytes if oversize. No-op if
    /// missing, zero-byte, or already under the threshold.
    static func rotateFileIfNeeded(at url: URL, maxBytes: Int) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path),
              let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int,
              size > maxBytes else {
            return
        }
        guard let handle = try? FileHandle(forUpdating: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: UInt64(size - maxBytes))
            let tail = handle.readDataToEndOfFile()
            try handle.seek(toOffset: 0)
            try handle.write(contentsOf: tail)
            try handle.truncate(atOffset: UInt64(tail.count))
            NSLog("getup: rotated \(url.lastPathComponent) (\(size) → \(tail.count) bytes)")
        } catch {
            NSLog("getup: log rotation failed: \(error.localizedDescription)")
        }
    }
}
