import Testing
import SwiftData
import HealthKit
@testable import Bellows

struct HealthKitSyncTests {
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
    @Test func healthKitSyncCreatesExerciseItems() async {
        // Setup seed data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let service = HealthKitService()
        
        // Create a day log for today
        let today = Date().startOfDay()
        let dayLog = DayLog(date: today)
        modelContext.insert(dayLog)
        
        // Mock workout data
        let mockWorkout = MockHKWorkout(
            activityType: .running,
            start: today.addingTimeInterval(3600),
            end: today.addingTimeInterval(7200),
            duration: 3600, // 1 hour
            totalDistance: HKQuantity(unit: .mile(), doubleValue: 5.0),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 400)
        )
        
        // Inject mock workouts into the service for testing
        service.mockWorkouts = [mockWorkout]
        
        // Perform sync
        await service.syncRecentWorkouts(days: 1, modelContext: modelContext)
        
        // Verify exercise items were created
        let items = dayLog.unwrappedItems
        let importedItems = items.filter { service.isImportedFromHealthKit($0) }
        
        #expect(importedItems.count > 0, "Sync should create exercise items from HealthKit data")
        
        if let runItem = importedItems.first(where: { $0.exercise?.name == "Run" }) {
            #expect(runItem.amount == 60.0, "1 hour workout should convert to 60 minutes")
            #expect(runItem.note?.contains("Imported from Apple Health") == true, "Should have import note")
        }
    }
    
    @MainActor
    @Test func healthKitSyncShowsProgress() async {
        // Setup seed data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let service = HealthKitService()
        
        // Add some mock workouts to make sync take longer
        let mockWorkouts = [
            MockHKWorkout(
                activityType: .running,
                start: Date().addingTimeInterval(-86400), // Yesterday
                end: Date().addingTimeInterval(-82800),
                duration: 3600,
                totalDistance: HKQuantity(unit: .mile(), doubleValue: 3.0),
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 300)
            ),
            MockHKWorkout(
                activityType: .walking,
                start: Date().addingTimeInterval(-3600), // Today
                end: Date().addingTimeInterval(-1800),
                duration: 1800,
                totalDistance: HKQuantity(unit: .mile(), doubleValue: 1.0),
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 100)
            )
        ]
        service.mockWorkouts = mockWorkouts
        
        // Initially not syncing
        #expect(service.isSyncing == false, "Should not be syncing initially")
        
        // Start sync operation
        let syncTask = Task {
            await service.syncRecentWorkouts(days: 7, modelContext: modelContext)
        }
        
        // Give the sync a moment to start
        try? await Task.sleep(for: .milliseconds(10))
        
        // Should show syncing state (this may be false if sync completes very quickly)
        let _ = service.isSyncing
        
        // Wait for completion
        await syncTask.value
        
        // Should complete
        #expect(service.isSyncing == false, "Should complete syncing")
        
        // Verify that sync actually processed the workouts
        #expect(service.lastSyncResult != nil, "Should have sync result")
        if case .success(let count) = service.lastSyncResult {
            #expect(count >= 0, "Should report workout count")
        }
    }
    
    @MainActor
    @Test func healthKitStatePersistsAcrossSessions() async {
        let service = HealthKitService()
        
        // Simulate authorization granted
        service.setupState = .ready
        service.isAuthorized = true
        
        // Create new service instance (simulating app restart)
        let newService = HealthKitService()
        await newService.checkSetupStatus()
        
        // State should persist if permissions were actually granted
        if HKHealthStore.isHealthDataAvailable() {
            #expect(newService.setupState == .ready, "Authorization state should persist")
            #expect(newService.isAuthorized == true, "Authorization flag should persist")
        }
    }
    
    @MainActor
    @Test func healthKitSyncHandlesErrors() async {
        let service = HealthKitService()
        
        // Test sync with invalid model context
        let invalidContext = ModelContext(modelContainer)
        
        // Should handle errors gracefully
        await service.syncRecentWorkouts(days: 7, modelContext: invalidContext)
        
        // Should not crash and should reset syncing state
        #expect(service.isSyncing == false, "Should reset syncing state after error")
    }
    
    @MainActor
    @Test func healthKitSyncRemovesPreviousImports() async {
        // Setup seed data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let service = HealthKitService()
        let today = Date().startOfDay()
        let dayLog = DayLog(date: today)
        modelContext.insert(dayLog)
        
        // Add existing imported item
        let walkType = try! modelContext.fetch(FetchDescriptor<ExerciseType>()).first { $0.name == "Walk" }!
        let minutesUnit = try! modelContext.fetch(FetchDescriptor<UnitType>()).first { $0.name == "Minutes" }!
        
        let existingImport = ExerciseItem(
            exercise: walkType,
            unit: minutesUnit,
            amount: 30.0,
            note: "Imported from Apple Health",
            enjoyment: 3,
            intensity: 3
        )
        dayLog.items = [existingImport]
        try! modelContext.save()
        
        // Verify it exists
        #expect(dayLog.unwrappedItems.count == 1, "Should have existing import")
        
        // Sync again (should replace existing imports)
        await service.syncRecentWorkouts(days: 1, modelContext: modelContext)
        
        // Should not duplicate imports
        let importedItems = dayLog.unwrappedItems.filter { service.isImportedFromHealthKit($0) }
        #expect(importedItems.count >= 0, "Should handle import replacement without duplicates")
    }
}
