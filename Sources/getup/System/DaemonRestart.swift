import AppKit
import Foundation

enum DaemonRestart {
    /// Detached `launchctl kickstart -k` after we've quit — brings up a fresh process that
    /// re-reads `AppleLanguages` at startup (the only way to apply a language switch live).
    static func restart() {
        let uid = getuid()
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 1 && /bin/launchctl kickstart -k gui/\(uid)/com.ychachilo.getup"]
        do { try task.run() } catch {
            NSLog("getup: failed to spawn restart task: \(error)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }
}
