import Testing
import SwiftData
import HealthKit
@testable import Bellows

@MainActor
struct HealthKitUUIDDedupTests {
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
        } catch { fatalError("Failed to create model container: \(error)") }
    }

    @Test func uuidDedupWithinSameDayLog() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)
        let service = HealthKitService()
        let today = Date().startOfDay()
        let log = DayLog(date: today); context.insert(log)

        let id = UUID()
        let wA = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(3600), end: today.addingTimeInterval(7200), duration: 3600, totalDistance: nil, totalEnergyBurned: nil, uuid: id)
        let wB = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(4000), end: today.addingTimeInterval(7600), duration: 3600, totalDistance: nil, totalEnergyBurned: nil, uuid: id)

        // Seed via user-approved import path
        _ = await service.importSpecificWorkoutsIgnoringDedup([wA], modelContext: context)
        let b = service.importWorkouts([wB], to: log, modelContext: context)

        #expect(b == 0)
        let imported = log.unwrappedItems.filter { service.isImportedFromHealthKit($0) }
        #expect(imported.count == 1)
    }

    @Test func uuidDedupAcrossDayLogs() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)
        let service = HealthKitService()
        let d1 = Date().startOfDay()
        let d2 = Calendar.current.date(byAdding: .day, value: 1, to: d1)!.startOfDay()
        let log1 = DayLog(date: d1); let log2 = DayLog(date: d2)
        context.insert(log1); context.insert(log2)

        let id = UUID()
        let wA = MockHKWorkout(activityType: .walking, start: d1.addingTimeInterval(23*3600+1800), end: d2.addingTimeInterval(1800), duration: 3600, totalDistance: nil, totalEnergyBurned: nil, uuid: id)

        // Seed via user-approved path, then ensure importer avoids duplication
        _ = await service.importSpecificWorkoutsIgnoringDedup([wA], modelContext: context)
        let b = service.importWorkouts([wA], to: log2, modelContext: context)
        #expect(b == 0)

        // Refresh logs from context to avoid stale in-memory arrays
        let all = try! context.fetch(FetchDescriptor<DayLog>())
        let fresh1 = all.first { Calendar.current.isDate($0.date, inSameDayAs: d1) }!
        let fresh2 = all.first { Calendar.current.isDate($0.date, inSameDayAs: d2) }!
        let items1 = fresh1.unwrappedItems.filter { service.isImportedFromHealthKit($0) }
        let items2 = fresh2.unwrappedItems.filter { service.isImportedFromHealthKit($0) }
        #expect(items1.count + items2.count == 1)
    }

    @Test func uuidRepairMovesItemToCorrectDay() async {
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)
        let service = HealthKitService()

        // Create two days and an item with the UUID placed on the wrong day
        let d1 = Date().startOfDay()
        let d2 = Calendar.current.date(byAdding: .day, value: 1, to: d1)!.startOfDay()
        let log1 = DayLog(date: d1); let log2 = DayLog(date: d2)
        context.insert(log1); context.insert(log2)

        let id = UUID()
        let wrongDayWorkout = MockHKWorkout(activityType: .walking, start: d2.addingTimeInterval(3600), end: d2.addingTimeInterval(5400), duration: 1800, totalDistance: nil, totalEnergyBurned: nil, uuid: id)

        // Import into day2 (wrong day for the workout in this scenario)
        _ = await service.importSpecificWorkoutsIgnoringDedup([wrongDayWorkout], modelContext: context)

        // Now attempt import into day1 for the same UUID; should move the item from log2 to log1
        let repairWorkout = MockHKWorkout(activityType: .walking, start: d1.addingTimeInterval(3600), end: d1.addingTimeInterval(5400), duration: 1800, totalDistance: nil, totalEnergyBurned: nil, uuid: id)
        _ = service.importWorkouts([repairWorkout], to: log1, modelContext: context)

        // Refresh logs from context to avoid stale in-memory arrays
        let logs = try! context.fetch(FetchDescriptor<DayLog>())
        let freshLog1 = logs.first { Calendar.current.isDate($0.date, inSameDayAs: d1) }!
        let freshLog2 = logs.first { Calendar.current.isDate($0.date, inSameDayAs: d2) }!
        let c1 = freshLog1.unwrappedItems.filter { $0.healthKitWorkoutUUID == id.uuidString }.count
        let c2 = freshLog2.unwrappedItems.filter { $0.healthKitWorkoutUUID == id.uuidString }.count
        #expect(c1 == 1)
        #expect(c2 == 0)
        #expect(c2 == 0)
    }
}
