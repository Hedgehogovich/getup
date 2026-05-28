import Foundation

/// Plist presence is the source of truth for "Run at startup" — no separate Settings field.
enum LoginItem {
    static let label = "com.ychachilo.getup"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func enable() {
        guard let exec = Bundle.main.executablePath else { return }
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
            try? p.run(); p.waitUntilExit()
        } catch { }
    }

    // No `bootout` — that would kill the running daemon mid-toggle. Plist removal stops auto-start next login.
    static func disable() {
        do {
            if FileManager.default.fileExists(atPath: plistURL.path) {
                try FileManager.default.removeItem(at: plistURL)
            }
        } catch { }
    }
}
