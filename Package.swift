// swift-tools-version: 6.2
import Foundation
import PackageDescription

let sweetCookieKitPath = "../SweetCookieKit"
let useLocalSweetCookieKit =
    ProcessInfo.processInfo.environment["AGENTSBAR_USE_LOCAL_SWEETCOOKIEKIT"] == "1"
let sweetCookieKitDependency: Package.Dependency =
    useLocalSweetCookieKit && FileManager.default.fileExists(atPath: sweetCookieKitPath)
    ? .package(path: sweetCookieKitPath)
    : .package(url: "https://github.com/steipete/SweetCookieKit", from: "0.4.1")

let sqlite3LibDir = ProcessInfo.processInfo.environment["AGENTSBAR_SQLITE3_LIB_DIR"]?
    .trimmingCharacters(in: .whitespacesAndNewlines)
let sqlite3LinkerSettings: [LinkerSetting] = if let sqlite3LibDir, !sqlite3LibDir.isEmpty {
    [.unsafeFlags(["-L\(sqlite3LibDir)"], .when(platforms: [.linux]))]
} else {
    []
}

let package = Package(
    name: "AgentsBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: {
        var products: [Product] = [
            .library(name: "AgentsBarCore", targets: ["AgentsBarCore"]),
            .executable(name: "AgentsBarCLI", targets: ["AgentsBarCLI"]),
            // Offline adaptive-refresh replay harness. Keep the supporting library package-internal.
            .executable(name: "AdaptiveReplayCLI", targets: ["AdaptiveReplayCLI"]),
        ]

        #if os(macOS)
        products.append(contentsOf: [
            .executable(name: "AgentsBar", targets: ["AgentsBar"]),
            .executable(name: "AgentsBarClaudeWatchdog", targets: ["AgentsBarClaudeWatchdog"]),
            .executable(name: "AgentsBarWidget", targets: ["AgentsBarWidget"]),
            .executable(name: "AgentsBarClaudeWebProbe", targets: ["AgentsBarClaudeWebProbe"]),
        ])
        #endif

        return products
    }(),
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3"),
        .package(url: "https://github.com/steipete/Commander", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.13.2"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
        .package(url: "https://github.com/zats/Vortex", revision: "ef5392088d4aeb255c4eee83157dbdafcd31bf07"),
        sweetCookieKitDependency,
    ],
    targets: {
        var targets: [Target] = [
            // Both glibc and static-musl CLI builds use this target; the module map supplies sqlite3 linkage.
            .systemLibrary(
                name: "CSQLite3",
                providers: [
                    .apt(["libsqlite3-dev"]),
                    .brew(["sqlite3"]),
                ]),
            .target(
                name: "AgentsBarCore",
                dependencies: [
                    .target(name: "CSQLite3", condition: .when(platforms: [.linux])),
                    .product(name: "Crypto", package: "swift-crypto"),
                    .product(name: "Logging", package: "swift-log"),
                    .product(name: "SweetCookieKit", package: "SweetCookieKit"),
                ],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ],
                linkerSettings: sqlite3LinkerSettings),
            .executableTarget(
                name: "AgentsBarCLI",
                dependencies: [
                    "AgentsBarCore",
                    .product(name: "Commander", package: "Commander"),
                    .product(name: "Crypto", package: "swift-crypto"),
                ],
                path: "Sources/AgentsBarCLI",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ],
                linkerSettings: sqlite3LinkerSettings),
            // Sole owner of the adaptive refresh decision table. Package-internal so the app and
            // offline replay tool share behavior without publishing another library product.
            .target(
                name: "AdaptiveRefreshCore",
                dependencies: [],
                path: "Sources/AdaptiveRefreshCore",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            // Offline adaptive-refresh replay harness: pure Foundation,
            // no AgentsBar/AgentsBarCore dependency, so it builds anywhere AgentsBarCore does.
            .target(
                name: "AdaptiveReplayKit",
                dependencies: ["AdaptiveRefreshCore"],
                path: "Sources/AdaptiveReplayKit",
                exclude: ["README.md"],
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "AdaptiveReplayCLI",
                dependencies: ["AdaptiveReplayKit"],
                path: "Sources/AdaptiveReplayCLI",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .testTarget(
                name: "AdaptiveReplayCLITests",
                dependencies: ["AdaptiveReplayCLI", "AdaptiveReplayKit"],
                path: "Tests/AdaptiveReplayCLITests",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
            .testTarget(
                name: "AdaptiveReplayKitTests",
                dependencies: ["AdaptiveRefreshCore", "AdaptiveReplayKit"],
                path: "Tests/AdaptiveReplayKitTests",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
            .testTarget(
                name: "AgentsBarLinuxTests",
                dependencies: [
                    "AgentsBarCore",
                    "AgentsBarCLI",
                    .target(name: "CSQLite3", condition: .when(platforms: [.linux])),
                ],
                path: "TestsLinux",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                    .enableExperimentalFeature("SwiftTesting"),
                ]),
        ]

        #if os(macOS)
        targets.append(contentsOf: [
            .executableTarget(
                name: "AgentsBarClaudeWatchdog",
                dependencies: [],
                path: "Sources/AgentsBarClaudeWatchdog",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "AgentsBar",
                dependencies: [
                    .product(name: "Sparkle", package: "Sparkle"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "Vortex", package: "Vortex"),
                    "AdaptiveRefreshCore",
                    "AgentsBarCore",
                ],
                path: "Sources/AgentsBar",
                resources: [
                    .process("Resources"),
                ],
                swiftSettings: [
                    // Opt into Swift 6 strict concurrency (approachable migration path).
                    .enableUpcomingFeature("StrictConcurrency"),
                    .define("ENABLE_SPARKLE"),
                ]),
            .executableTarget(
                name: "AgentsBarWidget",
                dependencies: ["AgentsBarCore"],
                path: "Sources/AgentsBarWidget",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
            .executableTarget(
                name: "AgentsBarClaudeWebProbe",
                dependencies: ["AgentsBarCore"],
                path: "Sources/AgentsBarClaudeWebProbe",
                swiftSettings: [
                    .enableUpcomingFeature("StrictConcurrency"),
                ]),
        ])

        targets.append(.testTarget(
            name: "AgentsBarTests",
            dependencies: ["AgentsBar", "AgentsBarCore", "AgentsBarCLI", "AgentsBarWidget"],
            path: "Tests",
            exclude: ["AdaptiveReplayCLITests", "AdaptiveReplayKitTests"],
            resources: [
                .copy("AgentsBarTests/Fixtures"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]))
        #endif

        return targets
    }())
