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
            name: "BellowsCore",
            targets: ["BellowsCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BellowsCore",
            path: "Bellows",
            sources: [
                "Models.swift",
                "Analytics.swift",
                "DesignSystem.swift",
                "StreakVisuals.swift",
                "StreakHeaderView.swift",
                "HomeView.swift",
                "SFFitnessSymbols.swift",
                "AppRootView.swift",
                "HistoryView.swift",
                "DayDetailView.swift",
                "ExerciseSheets.swift",
                "BellowsApp.swift"
            ]
        ),
        .testTarget(
            name: "BellowsCoreTests",
            dependencies: ["BellowsCore"],
            path: "BellowsTests",
            sources: [
                "ModelsTests.swift",
                "AnalyticsTests.swift",
                "DesignSystemTests.swift",
                "StreakVisualsTests.swift",
                "ViewTests.swift",
                "BellowsAppTests.swift",
                "ExerciseSheetsTests.swift",
                "UniquenessTests.swift"
            ]
        )
    ]
)
