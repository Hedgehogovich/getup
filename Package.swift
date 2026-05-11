// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "getup",
    platforms: [.macOS(.v14)],
    targets: [
        // Stay in Swift 5 language mode for now: the existing code mixes AppKit + Combine
        // patterns that would each need explicit `@MainActor` annotations under Swift 6
        // strict concurrency. That migration is its own project and is out of scope for
        // the current refactor / testing pass.
        .executableTarget(
            name: "getup",
            path: "Sources/getup",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Tests use Swift Testing (`@Suite` + `@Test` + `#expect`). They build + run on
        // any Mac with full Xcode installed (the test runner needs `xctest` from Xcode).
        // CLT-only Macs can't run `swift test` because the `xctest` runner binary is
        // Xcode-bundled. Local CLT users `swift build` the executable; CI runs the suite.
        .testTarget(
            name: "getupTests",
            dependencies: ["getup"],
            path: "Tests/getupTests"
        ),
    ]
)
