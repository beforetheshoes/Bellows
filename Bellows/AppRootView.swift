import SwiftUI
import SwiftData

@MainActor
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @ObservedObject private var themeManager = ThemeManager.shared
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]

    var body: some View {
        Group {
            #if os(iOS)
            if hSizeClass == .regular {
                SplitLayout()
            } else {
                PhoneLayout()
            }
            #else
            SplitLayout()
            #endif
        }
        .background(DS.ColorToken.background)
        .preferredColorScheme(themeManager.currentAppearanceMode.colorScheme)
        .onAppear { seedDefaultsIfNeeded() }
    }

    // Idempotent seeding: ensure defaults exist without creating duplicates.
    private func seedDefaultsIfNeeded() {
        SeedService.seedDefaultExercises(context: modelContext)
        SeedService.seedDefaultUnits(context: modelContext)
    }
}

@MainActor
func __test_seed_defaults(context: ModelContext) {
    SeedService.seedDefaultExercises(context: context)
    SeedService.seedDefaultUnits(context: context)
}

@MainActor
func __test_cleanup_daylogs(context: ModelContext) {
    DedupService.cleanupDuplicateDayLogs(context: context)
}

@MainActor
private struct PhoneLayout: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            NavigationStack {
                HistoryView()
                    .navigationDestination(for: Date.self) { date in
                        DayDetailView(date: date)
                    }
            }
                .tabItem { Label("History", systemImage: "calendar") }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Clean up any duplicates that might have been created by CloudKit sync
                DedupService.cleanupDuplicateDayLogs(context: modelContext)
                DedupService.cleanupDuplicateExerciseTypes(context: modelContext)
                DedupService.cleanupDuplicateUnitTypes(context: modelContext)
            }
        }
    }
    
    private func cleanupAllDuplicateDayLogs() {
        DedupService.cleanupDuplicateDayLogs(context: modelContext)
    }
}

@MainActor
private struct SplitLayout: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationSplitView {
            HistoryView()
                .navigationDestination(for: Date.self) { date in
                    DayDetailView(date: date)
                }
        } detail: {
            HomeView()
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Clean up any duplicates that might have been created by CloudKit sync
                DedupService.cleanupDuplicateDayLogs(context: modelContext)
                DedupService.cleanupDuplicateExerciseTypes(context: modelContext)
                DedupService.cleanupDuplicateUnitTypes(context: modelContext)
            }
        }
    }
    
    private func cleanupAllDuplicateDayLogs() {
        DedupService.cleanupDuplicateDayLogs(context: modelContext)
    }
}
