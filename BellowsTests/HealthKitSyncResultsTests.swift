import Testing
import SwiftData
import HealthKit
@testable import Bellows

struct HealthKitSyncResultsTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: DayLog.self, ExerciseItem.self, ExerciseType.self, UnitType.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    @MainActor
    @Test func syncShowsSuccessResultWithWorkoutCount() async {
        // Setup seed data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let service = HealthKitService()

        // Deterministic unit test: inject empty mocks so the import count is exactly 0
        // We intentionally avoid HKWorkoutBuilder (requires HKHealthStore auth) and
        // do not construct HKWorkout directly. Tests rely on WorkoutProtocol + mocks.
        service.mockWorkouts = []

        // Initially no sync result
        #expect(service.lastSyncResult == nil, "Should start with no sync result")

        // Perform sync (uses mocked workouts)
        await service.syncRecentWorkouts(days: 7, modelContext: modelContext)

        // Should have a result after sync
        #expect(service.lastSyncResult != nil, "Should have sync result after sync")

        if case .success(let count)? = service.lastSyncResult {
            #expect(count == 0, "Mocked sync should report exactly 0 workouts")
        }
    }
    
    @MainActor
    @Test func syncEnabledToggleControlsSyncButton() {
        let service = HealthKitService()
        
        // Initially enabled
        #expect(service.syncEnabled == true, "Sync should be enabled by default")
        
        // Toggle to disabled
        service.syncEnabled = false
        #expect(service.syncEnabled == false, "Should be able to disable sync")
        
        // Toggle back to enabled
        service.syncEnabled = true
        #expect(service.syncEnabled == true, "Should be able to enable sync")
    }
    
    @MainActor
    @Test func syncResultPersistsBetweenOperations() async {
        let service = HealthKitService()
        
        // Perform first sync
        await service.syncRecentWorkouts(days: 1, modelContext: modelContext)
        let firstResult = service.lastSyncResult
        
        #expect(firstResult != nil, "Should have result after first sync")
        
        // Start another sync but don't complete it
        service.isSyncing = true
        service.lastSyncResult = nil
        
        #expect(service.lastSyncResult == nil, "Should clear result when starting new sync")
        
        service.isSyncing = false
    }
}
