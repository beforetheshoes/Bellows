import Testing
import SwiftData
import Foundation
@testable import Bellows

struct UniquenessTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            modelContainer = try ModelContainer(
                for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self,
                configurations: config
            )
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    @MainActor
    @Test func seedDefaults_isIdempotent() throws {
        __test_seed_defaults(context: modelContext)
        // Capture counts after first seed
        let firstExercises = try modelContext.fetch(FetchDescriptor<ExerciseType>())
        let firstUnits = try modelContext.fetch(FetchDescriptor<UnitType>())

        // Seed again and ensure counts do not grow
        __test_seed_defaults(context: modelContext)
        let secondExercises = try modelContext.fetch(FetchDescriptor<ExerciseType>())
        let secondUnits = try modelContext.fetch(FetchDescriptor<UnitType>())

        #expect(firstExercises.count == secondExercises.count)
        #expect(firstUnits.count == secondUnits.count)

        // Names must be unique (case-insensitive)
        let exerciseNames = Set(secondExercises.map { $0.name.lowercased() })
        let unitNames = Set(secondUnits.map { $0.name.lowercased() })
        #expect(exerciseNames.count == secondExercises.count)
        #expect(unitNames.count == secondUnits.count)
    }

    @MainActor
    @Test func cleanupDuplicateExerciseTypes_mergesAndReassigns() throws {
        // Create duplicates by name
        let a = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let b = ExerciseType(name: "walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let item = ExerciseItem(exercise: a, unit: unit, amount: 10)
        modelContext.insert(a)
        modelContext.insert(b)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()

        // Act: cleanup
        DedupService.cleanupDuplicateExerciseTypes(context: modelContext)

        // Assert: only one "walk" remains
        let all = try modelContext.fetch(FetchDescriptor<ExerciseType>())
        let walks = all.filter { $0.name.lowercased() == "walk" }
        #expect(walks.count == 1)
        #expect(item.exercise === walks.first)
    }

    @MainActor
    @Test func cleanupDuplicateUnitTypes_mergesAndReassigns() throws {
        // Create duplicates by name
        let u1 = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let u2 = UnitType(name: "miles", abbreviation: "m", stepSize: 0.1, displayAsInteger: false)
        let ex = ExerciseType(name: "Run", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 6.0, defaultUnit: nil)
        let item = ExerciseItem(exercise: ex, unit: u1, amount: 3.0)
        modelContext.insert(u1)
        modelContext.insert(u2)
        modelContext.insert(ex)
        modelContext.insert(item)
        try modelContext.save()

        // Act: cleanup
        DedupService.cleanupDuplicateUnitTypes(context: modelContext)

        // Assert: only one "miles" remains and item now points to it
        let all = try modelContext.fetch(FetchDescriptor<UnitType>())
        let miles = all.filter { $0.name.lowercased() == "miles" }
        #expect(miles.count == 1)
        #expect(item.unit === miles.first)
    }

    @MainActor
    @Test func newExerciseTypeSave_preventsDuplicates() throws {
        __test_newExerciseTypeSave(context: modelContext, name: "Yoga", iconSystemName: nil)
        __test_newExerciseTypeSave(context: modelContext, name: "yoga", iconSystemName: nil)
        let all = try modelContext.fetch(FetchDescriptor<ExerciseType>())
        let yogas = all.filter { $0.name.lowercased() == "yoga" }
        #expect(yogas.count == 1)
    }

    @MainActor
    @Test func newUnitTypeSave_updatesExisting() throws {
        __test_newUnitTypeSave(context: modelContext, name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        __test_newUnitTypeSave(context: modelContext, name: "minutes", abbreviation: "mins", stepSize: 0.5, displayAsInteger: false)
        let all = try modelContext.fetch(FetchDescriptor<UnitType>())
        let minutes = all.filter { $0.name.lowercased() == "minutes" }
        #expect(minutes.count == 1)
        #expect(minutes.first?.abbreviation == "mins")
    }
}

