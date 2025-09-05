import Testing
import SwiftData
import Foundation
@testable import Bellows

struct ExportImportTests {
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

    @Test @MainActor func roundTripExportImport() throws {
        // Seed minimal units and exercises
        let minutes = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let reps = UnitType(name: "Reps", abbreviation: "reps", stepSize: 1.0, displayAsInteger: true)
        let walk = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12, defaultUnit: minutes)
        let pushups = ExerciseType(name: "Pushups", baseMET: 6.0, repWeight: 0.25, defaultPaceMinPerMi: 10, defaultUnit: reps)
        context.insert(minutes); context.insert(reps); context.insert(walk); context.insert(pushups)

        let today = Date().startOfDay()
        let log = DayLog(date: today)
        let i1 = ExerciseItem(exercise: walk, unit: minutes, amount: 30, note: "Evening walk", enjoyment: 4, intensity: 3, at: today.addingTimeInterval(60))
        let i2 = ExerciseItem(exercise: pushups, unit: reps, amount: 20, note: "", enjoyment: 3, intensity: 4, at: today.addingTimeInterval(120))
        log.items = [i1, i2]
        i1.dayLog = log; i2.dayLog = log
        context.insert(log); context.insert(i1); context.insert(i2)
        try context.save()

        // Export
        let data = try DataExportService.exportAll(modelContext: context)
        #expect(data.count > 0)

        // Import into a fresh store
        let fresh = try ModelContainer(
            for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let freshCtx = ModelContext(fresh)
        let summary = try DataImportService.importFromJSON(data, modelContext: freshCtx)

        #expect(summary.insertedDays >= 1)
        #expect(summary.insertedItems >= 2)

        // Validate entities
        let units = try freshCtx.fetch(FetchDescriptor<UnitType>())
        let exercises = try freshCtx.fetch(FetchDescriptor<ExerciseType>())
        let days = try freshCtx.fetch(FetchDescriptor<DayLog>())
        let items = try freshCtx.fetch(FetchDescriptor<ExerciseItem>())

        #expect(units.map { $0.name }.sorted() == ["Minutes", "Reps"])
        #expect(exercises.map { $0.name }.sorted() == ["Pushups", "Walk"])
        #expect(days.count == 1)
        #expect(items.count == 2)

        let importedLog = days.first!
        #expect(Calendar.current.isDate(importedLog.date, inSameDayAs: today))
        let walkItem = items.first { $0.exercise?.name == "Walk" }!
        #expect(walkItem.amount == 30)
        #expect(walkItem.unit?.name == "Minutes")
        #expect(walkItem.enjoyment == 4 && walkItem.intensity == 3)
    }

    @Test @MainActor func importingSameBundleTwiceIsIdempotent() throws {
        // Prepare initial dataset
        let minutes = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let walk = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12, defaultUnit: minutes)
        context.insert(minutes); context.insert(walk)
        let d = DayLog(date: Date().startOfDay())
        let item = ExerciseItem(exercise: walk, unit: minutes, amount: 10, note: "", enjoyment: 3, intensity: 3)
        d.items = [item]; item.dayLog = d
        context.insert(d); context.insert(item)
        try context.save()

        // Export
        let data = try DataExportService.exportAll(modelContext: context)

        // Fresh context
        let fresh = try ModelContainer(
            for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let freshCtx = ModelContext(fresh)

        // Import twice
        _ = try DataImportService.importFromJSON(data, modelContext: freshCtx)
        let after1Items = try freshCtx.fetch(FetchDescriptor<ExerciseItem>())
        #expect(after1Items.count == 1)
        _ = try DataImportService.importFromJSON(data, modelContext: freshCtx)
        let after2Items = try freshCtx.fetch(FetchDescriptor<ExerciseItem>())
        #expect(after2Items.count == 1)

        // Ensure dedup services didn't create duplicates of units/exercises
        #expect(try freshCtx.fetch(FetchDescriptor<UnitType>()).count == 1)
        #expect(try freshCtx.fetch(FetchDescriptor<ExerciseType>()).count == 1)
        #expect(try freshCtx.fetch(FetchDescriptor<DayLog>()).count == 1)
    }

    @Test @MainActor func importDoesNotOverwriteExistingFields() throws {
        // Create local exercise with specific baseMET
        let minutes = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let walk = ExerciseType(name: "Walk", baseMET: 5.5, repWeight: 0.2, defaultPaceMinPerMi: 9.5, defaultUnit: minutes)
        context.insert(minutes); context.insert(walk)
        let data = try DataExportService.exportAll(modelContext: context)

        // Fresh context with different baseMET for Walk
        let fresh = try ModelContainer(
            for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let freshCtx = ModelContext(fresh)
        let freshMinutes = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let freshWalk = ExerciseType(name: "Walk", baseMET: 10.0, repWeight: 0.3, defaultPaceMinPerMi: 8.0, defaultUnit: freshMinutes)
        freshCtx.insert(freshMinutes); freshCtx.insert(freshWalk)
        try freshCtx.save()

        _ = try DataImportService.importFromJSON(data, modelContext: freshCtx)

        // Ensure values were not overwritten
        let walks = try freshCtx.fetch(FetchDescriptor<ExerciseType>())
        let w = walks.first { $0.name == "Walk" }!
        #expect(w.baseMET == 10.0)
        #expect(w.repWeight == 0.3)
        #expect(w.defaultPaceMinPerMi == 8.0)
    }
}

