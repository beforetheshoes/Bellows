import Testing
import SwiftData
import Foundation
@testable import Bellows

@MainActor
struct ExerciseSheetsHookTests {
    let container: ModelContainer
    let context: ModelContext

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
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

    @Test func newExerciseTypeSaveCreatesOnce() throws {
        __test_newExerciseTypeSave(context: context, name: "Custom", iconSystemName: nil)
        __test_newExerciseTypeSave(context: context, name: "custom", iconSystemName: nil)
        let all = try context.fetch(FetchDescriptor<ExerciseType>())
        #expect(all.filter { $0.name.lowercased() == "custom" }.count == 1)
    }

    @Test func newUnitTypeSaveCreatesAndUpdates() throws {
        __test_newUnitTypeSave(context: context, name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        __test_newUnitTypeSave(context: context, name: "minutes", abbreviation: "m", stepSize: 0.5, displayAsInteger: false)
        let all = try context.fetch(FetchDescriptor<UnitType>())
        let minutes = all.first { $0.name.lowercased() == "minutes" }
        #expect(minutes?.abbreviation == "m")
        #expect(all.filter { $0.name.lowercased() == "minutes" }.count == 1)
    }

    @Test func addExerciseCreatesDayLogWhenMissing() throws {
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12, defaultUnit: nil)
        let unit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        context.insert(exercise); context.insert(unit)
        try context.save()
        let date = Date()
        __test_addExercise(context: context, date: date, dayLog: nil, exercise: exercise, unit: unit, amount: 25, enjoyment: 4, intensity: 3, note: "Nice")
        let logs = try context.fetch(FetchDescriptor<DayLog>())
        #expect(!logs.isEmpty)
        #expect(logs.first?.unwrappedItems.count == 1)
    }

    @Test func editExerciseUpdatesFields() throws {
        let ex = ExerciseType(name: "Run", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 6, defaultUnit: nil)
        let u = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let item = ExerciseItem(exercise: ex, unit: u, amount: 2.0, enjoyment: 3, intensity: 3)
        context.insert(ex); context.insert(u); context.insert(item)
        try context.save()
        __test_editExerciseSave(context: context, item: item, exercise: ex, unit: u, amount: 4.5, enjoyment: 5, intensity: 4, note: "Updated")
        #expect(item.amount == 4.5)
        #expect(item.enjoyment == 5)
        #expect(item.intensity == 4)
        #expect(item.note == "Updated")
    }
}

