import Testing
import SwiftData
import HealthKit
@testable import Bellows

// Additional focused tests to increase coverage for HealthKitService
// and unit matching helpers.

struct HealthKitAndHelpersAdditionalTests {
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
    }

    // MARK: - HealthKit fetch and sync behavior

    @MainActor
    @Test func fetchWorkoutsFiltersByDateRange() async {
        // Seed minimal requirements
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)

        let service = HealthKitService()
        let now = Date()

        // Create three mock workouts: yesterday, today, tomorrow
        let yesterday = now.addingTimeInterval(-86400)
        let today = now
        let tomorrow = now.addingTimeInterval(86400)

        let mocks: [WorkoutProtocol] = [
            MockHKWorkout(activityType: .walking, start: yesterday, end: yesterday.addingTimeInterval(1800), duration: 1800, totalDistance: nil, totalEnergyBurned: nil),
            MockHKWorkout(activityType: .running, start: today, end: today.addingTimeInterval(3600), duration: 3600, totalDistance: nil, totalEnergyBurned: nil),
            MockHKWorkout(activityType: .cycling, start: tomorrow, end: tomorrow.addingTimeInterval(1200), duration: 1200, totalDistance: nil, totalEnergyBurned: nil)
        ]
        service.mockWorkouts = mocks

        // Query only today..now+1s
        let start = Calendar.current.startOfDay(for: now)
        let end = now.addingTimeInterval(1)
        let filtered = await service.fetchWorkouts(from: start, to: end)

        // Expect exactly the workout that starts today
        #expect(filtered.count == 1)
        #expect(filtered.first?.workoutActivityType == .running)
    }

    @MainActor
    @Test func syncIsIdempotentPerDay() async {
        // Seed defaults and create DayLog
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)
        let today = Date().startOfDay()
        let dayLog = DayLog(date: today)
        context.insert(dayLog)

        let service = HealthKitService()
        // Two workouts for the same day
        let w1 = MockHKWorkout(activityType: .running, start: today.addingTimeInterval(60*60), end: today.addingTimeInterval(2*60*60), duration: 3600, totalDistance: nil, totalEnergyBurned: nil)
        let w2 = MockHKWorkout(activityType: .walking, start: today.addingTimeInterval(3*60*60), end: today.addingTimeInterval(3*60*60+1800), duration: 1800, totalDistance: nil, totalEnergyBurned: nil)
        service.mockWorkouts = [w1, w2]

        // First sync
        await service.syncRecentWorkouts(days: 1, modelContext: context)
        let firstImported = dayLog.unwrappedItems.filter { service.isImportedFromHealthKit($0) }.count
        #expect(firstImported == 2)

        // Second sync with the same data should replace existing imports, not duplicate
        await service.syncRecentWorkouts(days: 1, modelContext: context)
        let secondImported = dayLog.unwrappedItems.filter { service.isImportedFromHealthKit($0) }.count
        #expect(secondImported == 2)
    }

    @MainActor
    @Test func importDetectionHandlesNilAndNonHealthNotes() async {
        // Seed defaults
        SeedService.seedDefaultUnits(context: context)
        SeedService.seedDefaultExercises(context: context)
        let service = HealthKitService()

        // Create sample items
        let exercise = ExerciseType(name: "Test", baseMET: 4.0, repWeight: 0.1, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let a = ExerciseItem(exercise: exercise, unit: unit, amount: 10, note: nil)
        let b = ExerciseItem(exercise: exercise, unit: unit, amount: 10, note: "My own note")
        let c = ExerciseItem(exercise: exercise, unit: unit, amount: 10, note: "Imported from Apple Health")

        #expect(service.isImportedFromHealthKit(a) == false)
        #expect(service.isImportedFromHealthKit(b) == false)
        #expect(service.isImportedFromHealthKit(c) == true)
    }

    // MARK: - Unit matching helper coverage

    @MainActor
    @Test func findBestMatchingUnitByIdentityAndName() throws {
        let minutes = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let minutesCopyDifferentInstance = UnitType(name: "Minutes", abbreviation: "m", stepSize: 0.5, displayAsInteger: false)
        let reps = UnitType(name: "Reps", abbreviation: "reps", stepSize: 1.0, displayAsInteger: true)

        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12, iconSystemName: nil, defaultUnit: minutes)

        // Exact identity match
        #expect(findBestMatchingUnit(for: exercise, from: [minutes, reps]) === minutes)

        // No identity; match by equal name
        #expect(findBestMatchingUnit(for: exercise, from: [minutesCopyDifferentInstance, reps])?.name == "Minutes")
    }

    @MainActor
    @Test func findBestMatchingUnitPartialAndCategoryFallbacks() throws {
        // Exercise default unit name is "Minutes"; only similar/partial units exist
        let mins = UnitType(name: "mins", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let minuteWord = UnitType(name: "Minute(s)", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let unknown = UnitType(name: "Unknown", abbreviation: "?", stepSize: 1.0, displayAsInteger: false)

        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12, iconSystemName: nil, defaultUnit: UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false))

        // Partial name match (unit contains expected default name pattern)
        #expect(findBestMatchingUnit(for: exercise, from: [unknown, mins])?.name == "mins")

        // Reverse partial (expected name contains unit name)
        #expect(findBestMatchingUnit(for: exercise, from: [unknown, minuteWord])?.name == "Minute(s)")

        // Category-based fallback (simulate legacy defaultUnitCategory)
        exercise.defaultUnit = nil
        exercise.defaultUnitCategory = .time
        let reps = UnitType(name: "Reps", abbreviation: "reps", stepSize: 1.0, displayAsInteger: true)
        #expect(findBestMatchingUnit(for: exercise, from: [unknown, reps, mins])?.stepSize == 0.5)
    }

    @MainActor
    @Test func findBestMatchingUnitFallbackToFirst() {
        let exercise = ExerciseType(name: "Custom", baseMET: 4.0, repWeight: 0.1, defaultPaceMinPerMi: 10, defaultUnit: nil)
        let a = UnitType(name: "A", abbreviation: "a", stepSize: 1.0, displayAsInteger: false)
        let b = UnitType(name: "B", abbreviation: "b", stepSize: 1.0, displayAsInteger: false)
        #expect(findBestMatchingUnit(for: exercise, from: [a, b]) === a)
    }

    @Test func stepForUnitUsesStepSizeOrDefault() {
        let u = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        #expect(stepForUnit(u) == 0.1)
        #expect(stepForUnit(nil) == 1.0)
    }
}

// MockHKWorkout is defined in TestsSupport.swift for reuse.
