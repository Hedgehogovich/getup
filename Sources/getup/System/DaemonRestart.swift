import AppKit
import Foundation

enum DaemonRestart {
    /// Spawns a detached `launchctl kickstart -k` after a short delay, then quits the current
    /// process cleanly. The kickstart fires after we've exited and brings up a fresh instance
    /// that re-reads `AppleLanguages` at startup.
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
