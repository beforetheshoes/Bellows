import SwiftUI
import SwiftData

@MainActor
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Bindable private var themeManager = ThemeManager.shared
    @Bindable private var hkService = HealthKitService.shared
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
        // Tiny toast for first background import
        .overlay(alignment: .top) {
            if let msg = hkService.backgroundToastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(msg).font(.subheadline)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(radius: 8, y: 4)
                .padding(.top, 16)
            }
        }
        .onChange(of: hkService.backgroundToastMessage) { _, newValue in
            // Auto-dismiss after a short delay
            if newValue != nil {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hkService.backgroundToastMessage = nil
                    }
                }
            }
        }
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
    private let hk = HealthKitService.shared
    
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

                // Start background observers and perform a throttled foreground sync
                hk.startBackgroundObserversIfPossible(modelContext: modelContext)
                Task { await hk.foregroundSyncIfNeeded(modelContext: modelContext) }
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
    private let hk = HealthKitService.shared
    
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

                // Start background observers and perform a throttled foreground sync
                hk.startBackgroundObserversIfPossible(modelContext: modelContext)
                Task { await hk.foregroundSyncIfNeeded(modelContext: modelContext) }
            }
        }
    }
    
    private func cleanupAllDuplicateDayLogs() {
        DedupService.cleanupDuplicateDayLogs(context: modelContext)
    }
}
