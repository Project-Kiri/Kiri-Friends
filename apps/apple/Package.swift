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
            name: "KiriFriendsPhoneApp",
            targets: ["KiriFriendsPhoneApp"]
        ),
        .executable(
            name: "KiriFriendsWatchApp",
            targets: ["KiriFriendsWatchApp"]
        ),
        .library(
            name: "KiriFriendsWidgets",
            targets: ["KiriFriendsWidgets"]
        ),
        .executable(
            name: "KiriFriendsCLI",
            targets: ["KiriFriendsCLI"]
        ),
        .library(
            name: "KiriFriendsMacBuddyKit",
            targets: ["KiriFriendsMacBuddyKit"]
        ),
        .executable(
            name: "KiriFriendsBuddyMac",
            targets: ["KiriFriendsBuddyMac"]
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
            exclude: ["LICENSE"],
            resources: [
                // Theme packs derived from clawd-on-desk; redistributed
                // under AGPL-3.0 along with the rest of KiriFriendsWatchKit.
                // Stored as an Asset Catalog so the iOS / watchOS asset
                // compiler renders the SVGs natively (UIImage cannot
                // decode raw SVG files; the compiler can).
                .process("Resources/Themes.xcassets")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "KiriFriendsBridge",
            dependencies: ["KiriFriendsCore"],
            exclude: ["LICENSE"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "KiriFriendsPhoneApp",
            dependencies: ["KiriFriendsCore", "KiriFriendsBridge", "KiriFriendsWatchKit"],
            exclude: ["LICENSE"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "KiriFriendsWatchApp",
            dependencies: ["KiriFriendsCore", "KiriFriendsWatchKit"],
            exclude: ["LICENSE"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "KiriFriendsWidgets",
            dependencies: ["KiriFriendsCore"],
            exclude: ["LICENSE"],
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
        .target(
            name: "KiriFriendsMacBuddyKit",
            dependencies: ["KiriFriendsCore"],
            exclude: ["LICENSE"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "KiriFriendsBuddyMac",
            dependencies: ["KiriFriendsCore", "KiriFriendsMacBuddyKit"],
            exclude: ["LICENSE"],
            resources: [
                .copy("Resources/Themes")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "KiriFriendsCoreTests",
            dependencies: ["KiriFriendsCore", "KiriFriendsWatchKit", "KiriFriendsBridge"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "KiriFriendsMacBuddyKitTests",
            dependencies: ["KiriFriendsCore", "KiriFriendsMacBuddyKit"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
