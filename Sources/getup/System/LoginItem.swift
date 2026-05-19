import Foundation

/// LaunchAgent install/uninstall from inside the app. The plist's presence is the source of
/// truth for the "Run at startup" toggle — there is no separate Settings field.
enum LoginItem {
    static let label = "com.ychachilo.getup"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Writes the LaunchAgent plist + tries to bootstrap. Idempotent: re-running with the agent
    /// already loaded fails the bootstrap step harmlessly (we ignore the result).
    static func enable() {
        guard let exec = Bundle.main.executablePath else {
            NSLog("getup: LoginItem.enable — Bundle.main.executablePath nil")
            return
        }
        let supportDir = AppPaths.supportDir
        let logPath = AppPaths.stdoutLog.path
        let errPath = AppPaths.stderrLog.path

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(exec)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <dict>
                <key>SuccessfulExit</key>
                <false/>
            </dict>
            <key>ProcessType</key>
            <string>Interactive</string>
            <key>StandardOutPath</key>
            <string>\(logPath)</string>
            <key>StandardErrorPath</key>
            <string>\(errPath)</string>
        </dict>
        </plist>
        """

        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)

            let p = Process()
            p.launchPath = "/bin/launchctl"
            p.arguments = ["bootstrap", "gui/\(getuid())", plistURL.path]
            do { try p.run(); p.waitUntilExit() } catch {
                NSLog("getup: launchctl bootstrap failed: \(error.localizedDescription)")
            }
            NSLog("getup: LoginItem enabled (plist=\(plistURL.path), bootstrap exit=\(p.terminationStatus))")
        } catch {
            NSLog("getup: LoginItem.enable write failed: \(error)")
        }
    }

    /// Removes the LaunchAgent plist file. Does NOT `bootout` — that would kill the running
    /// daemon mid-toggle. The current session continues until the user quits; next login is silent.
    static func disable() {
        do {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
            NSLog("getup: LoginItem disabled (plist removed; current session continues)")
        } catch {
            NSLog("getup: LoginItem.disable failed: \(error)")
        }
    }
}
