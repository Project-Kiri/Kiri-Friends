// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "KiriFriendsApple",
    platforms: [
        .watchOS(.v11),
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "KiriFriendsCore",
            targets: ["KiriFriendsCore"]
        ),
        .library(
            name: "KiriFriendsWatchKit",
            targets: ["KiriFriendsWatchKit"]
        ),
        .library(
            name: "KiriFriendsBridge",
            targets: ["KiriFriendsBridge"]
        ),
        .executable(
            name: "KiriFriendsWatchApp",
            targets: ["KiriFriendsWatchApp"]
        ),
        .executable(
            name: "KiriFriendsCLI",
            targets: ["KiriFriendsCLI"]
        )
    ],
    targets: [
        .target(
            name: "KiriFriendsCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "KiriFriendsWatchKit",
            dependencies: ["KiriFriendsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "KiriFriendsBridge",
            dependencies: ["KiriFriendsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "KiriFriendsWatchApp",
            dependencies: ["KiriFriendsCore", "KiriFriendsWatchKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "KiriFriendsCLI",
            dependencies: ["KiriFriendsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "KiriFriendsCoreTests",
            dependencies: ["KiriFriendsCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
