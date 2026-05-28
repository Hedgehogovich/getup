import Foundation

// Activated by GETUP_TEST_OUTPUT env var. App writes status JSON then exits.
// GETUP_TEST_SUITE selects an isolated UserDefaults suite so tests don't touch real prefs.
enum TestMode {
    static var outputPath: String? { ProcessInfo.processInfo.environment["GETUP_TEST_OUTPUT"] }
    static var defaultsSuite: String? { ProcessInfo.processInfo.environment["GETUP_TEST_SUITE"] }
    static var isActive: Bool { outputPath != nil }
}

struct TestModeStatus: Codable {
    let pid: Int32
    let fireMinute: Int
    let snoozeMinutes: Int
    let audioMode: String
    let volume: Double
    let showInDock: Bool
    let isFirstRun: Bool
}
