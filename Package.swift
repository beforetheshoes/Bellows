// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bellows",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Bellows",
            targets: ["Bellows"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Bellows",
            path: "Bellows",
            exclude: [
                "Assets.xcassets",
                "Bellows.entitlements",
                "Info.plist",
                "HomeView_old.swift",
                // Old monolithic files replaced by Views/* and Helpers/*
                "BellowsComponents.swift",
                "ExerciseSheets.swift"
            ]
        ),
        .testTarget(
            name: "BellowsTests",
            dependencies: ["Bellows"],
            path: "BellowsTests"
        )
    ]
)
