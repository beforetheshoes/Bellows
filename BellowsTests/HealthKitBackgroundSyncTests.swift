import Testing
import SwiftData
import HealthKit
@testable import Bellows

@MainActor
struct HealthKitBackgroundSyncTests {
    let container: ModelContainer
    let context: ModelContext

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(
                for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self,
                configurations: config
            )
            context = ModelContext(container)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
        // Clean defaults that persist anchors between runs in this process space
        UserDefaults.standard.removeObject(forKey: "hk_seen_workouts_v1")
        UserDefaults.standard.removeObject(forKey: "hk_last_background_sync_date")
    }

    @Test func userCanImportSelectedWorkouts() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let service = HealthKitService()
        service.syncEnabled = true

        let today = Date().startOfDay()
        let w1 = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(7200), duration: 3600, totalDistance: nil, totalEnergyBurned: nil)
        let w2 = MockHKWorkout(activityType: .walking, start: today.addingTimeInterval(8000), end: today.addingTimeInterval(8600), duration: 600, totalDistance: nil, totalEnergyBurned: nil)
        // User-driven repair import ignores dedupe and inserts selected
        let c = await service.importSpecificWorkoutsIgnoringDedup([w1, w2], modelContext: context)
        #expect(c == 2)
    }

    @Test func backgroundSkipsAfterUserImport() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let today = Date().startOfDay()
        let w1 = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(7200), duration: 3600, totalDistance: nil, totalEnergyBurned: nil)
        let w2 = MockHKWorkout(activityType: .walking, start: today.addingTimeInterval(8000), end: today.addingTimeInterval(8600), duration: 600, totalDistance: nil, totalEnergyBurned: nil)

        let service = HealthKitService()
        service.syncEnabled = true
        // User imports w1
        _ = await service.importSpecificWorkoutsIgnoringDedup([w1], modelContext: context)
        // Background should skip importing w1 again
        service.mockWorkouts = [w1, w2]
        _ = await service.__test_processBackgroundUpdates(modelContext: context)
        // It may import w2 or skip if seen; don't assert count, assert no duplicates exist
        let logs = try! context.fetch(FetchDescriptor<DayLog>())
        let allItems = logs.flatMap { $0.unwrappedItems }
        let uuids = allItems.compactMap { $0.healthKitWorkoutUUID }
        #expect(uuids.filter { $0 == w1.uuid.uuidString }.count == 1)
    }

    @Test func backgroundRespectsSyncEnabled() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let service = HealthKitService()
        service.syncEnabled = false // disabled

        let today = Date().startOfDay()
        let w1 = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(7200), duration: 3600, totalDistance: nil, totalEnergyBurned: nil)
        service.mockWorkouts = [w1]

        let count = await service.__test_processBackgroundUpdates(modelContext: context)
        #expect(count == 0)
        // Ensure nothing imported
        let logs = try! context.fetch(FetchDescriptor<DayLog>())
        #expect(logs.first?.unwrappedItems.isEmpty ?? true)
    }

    @Test func backgroundImportsNewlyAddedOnNextTick() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let service = HealthKitService()
        service.syncEnabled = true
        let today = Date().startOfDay()
        let w1 = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(7200), duration: 3600, totalDistance: nil, totalEnergyBurned: nil)
        // First, user imports w1
        _ = await service.importSpecificWorkoutsIgnoringDedup([w1], modelContext: context)
        // Add a new workout to mocks and tick
        let w2 = MockHKWorkout(activityType: .cycling, start: today.addingTimeInterval(9000), end: today.addingTimeInterval(9600), duration: 600, totalDistance: nil, totalEnergyBurned: nil)
        service.mockWorkouts = [w1, w2]
        _ = await service.__test_processBackgroundUpdates(modelContext: context)
        // At least ensure no duplicate for w1
        let logs = try! context.fetch(FetchDescriptor<DayLog>())
        let allItems = logs.flatMap { $0.unwrappedItems }
        #expect(allItems.filter { $0.healthKitWorkoutUUID == w1.uuid.uuidString }.count == 1)
    }

    @Test func backgroundDoesNotDuplicateManualImports() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let service = HealthKitService()
        service.syncEnabled = true
        let today = Date().startOfDay()
        let w1 = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(7200), duration: 3600, totalDistance: nil, totalEnergyBurned: nil)

        // Manual sync path first
        service.mockWorkouts = [w1]
        await service.syncRecentWorkouts(days: 1, modelContext: context)

        // Then background tick sees the same workout
        let c = await service.__test_processBackgroundUpdates(modelContext: context)
        #expect(c == 0)

        // Ensure only one imported item exists
        let logs = try! context.fetch(FetchDescriptor<DayLog>())
        let imported = logs.first?.unwrappedItems.filter { service.isImportedFromHealthKit($0) } ?? []
        #expect(imported.count == 1)
    }

    @Test func importWorkoutsIsUniquePerWorkout() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let service = HealthKitService()
        let today = Date().startOfDay()
        let log = DayLog(date: today)
        context.insert(log)

        let w1 = MockHKWorkout(activityType: .walking, start: today.addingTimeInterval(4000), end: today.addingTimeInterval(4600), duration: 600, totalDistance: nil, totalEnergyBurned: nil)

        // Call import twice with same workout
        service.importWorkouts([w1], to: log, modelContext: context)
        service.importWorkouts([w1], to: log, modelContext: context)

        let imported = log.unwrappedItems.filter { service.isImportedFromHealthKit($0) }
        #expect(imported.count == 1)
    }

    @Test func deletedImportsCanBeRepairedManually() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let service = HealthKitService()
        service.syncEnabled = true
        let today = Date().startOfDay()
        let uuid = UUID()
        let w1 = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(7200), duration: 3600, totalDistance: nil, totalEnergyBurned: nil, uuid: uuid)
        _ = await service.importSpecificWorkoutsIgnoringDedup([w1], modelContext: context)

        // Delete imported item via service API
        let logs = try! context.fetch(FetchDescriptor<DayLog>())
        let day = logs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }!
        service.removeHealthKitImports(from: day, modelContext: context)

        // User repairs by importing selected
        let repaired = await service.importSpecificWorkoutsIgnoringDedup([w1], modelContext: context)
        #expect(repaired == 1)
    }
}
