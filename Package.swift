// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "getup",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.2"),
    ],
    targets: [
        .executableTarget(
            name: "getup",
            path: "Sources/getup",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Tests use Swift Testing (`@Suite` + `@Test` + `#expect`). They build + run on
        // any Mac with full Xcode installed (the test runner needs `xctest` from Xcode).
        // CLT-only Macs can't run `swift test` because the `xctest` runner binary is
        // Xcode-bundled. Local CLT users `swift build` the executable; CI runs the suite.
        .testTarget(
            name: "getupTests",
            dependencies: [
                "getup",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/getupTests"
        ),
    ]
)
