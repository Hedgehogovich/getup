import Foundation
import Testing
@testable import getup

@Suite("E2E — launch + IPC", .serialized)
struct E2ETests {

    // Prefer release build; fall back to debug.
    static let binaryURL: URL? = {
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()    // getupTests/
            .deletingLastPathComponent()    // Tests/
            .deletingLastPathComponent()    // repo root
        for sub in [".build/release/getup", ".build/debug/getup"] {
            let u = root.appendingPathComponent(sub)
            if FileManager.default.isExecutableFile(atPath: u.path) { return u }
        }
        return nil
    }()

    static var binaryExists: Bool { binaryURL != nil }

    // Launch the app in test mode, wait for status JSON, return decoded status.
    private func launch(seedingDefaults seed: [String: Any] = [:]) async throws -> TestModeStatus {
        guard let binary = E2ETests.binaryURL else {
            Issue.record("Binary not found — run `swift build` first")
            throw CancellationError()
        }

        let suite = "getup.e2e.\(UUID().uuidString)"
        let outPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("getup-e2e-\(UUID().uuidString).json").path

        // Seed settings into the isolated suite before launch.
        if !seed.isEmpty, let ud = UserDefaults(suiteName: suite) {
            for (k, v) in seed { ud.set(v, forKey: k) }
            ud.synchronize()
        }

        defer {
            UserDefaults.standard.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(atPath: outPath)
        }

        var env = ProcessInfo.processInfo.environment
        env["GETUP_TEST_OUTPUT"] = outPath
        env["GETUP_TEST_SUITE"] = suite

        let proc = Process()
        proc.executableURL = binary
        proc.environment = env
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()

        // Poll until the status file appears (max 10 s).
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
            if FileManager.default.fileExists(atPath: outPath) { break }
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: outPath)) else {
            proc.terminate()
            throw CocoaError(.fileReadNoSuchFile)
        }

        return try JSONDecoder().decode(TestModeStatus.self, from: data)
    }

    @Test(.enabled(if: E2ETests.binaryExists))
    func launchReportsDefaultSettings() async throws {
        let status = try await launch()
        #expect(status.fireMinute == 50)
        #expect(status.fireIntervalMinutes == 60)
        #expect(status.snoozeMinutes == 10)
        #expect(status.audioMode == "headphonesOnly")
        #expect(status.showInDock == false)
        #expect(status.isFirstRun == true)
    }

    @Test(.enabled(if: E2ETests.binaryExists))
    func launchLoadsPersistedSnoozeMinutes() async throws {
        var s = Settings()
        s.snoozeMinutes = 25
        let data = try JSONEncoder().encode(s)
        let status = try await launch(seedingDefaults: ["getup.settings.v1": data])
        #expect(status.snoozeMinutes == 25)
    }

    @Test(.enabled(if: E2ETests.binaryExists))
    func launchLoadsPersistedAudioMode() async throws {
        var s = Settings()
        s.audioMode = .always
        let data = try JSONEncoder().encode(s)
        let status = try await launch(seedingDefaults: ["getup.settings.v1": data])
        #expect(status.audioMode == "always")
    }
}
