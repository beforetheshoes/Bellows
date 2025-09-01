import Testing
import SwiftData
import Foundation
@testable import Bellows

struct ServicesTests {
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

    // MARK: - Seeding
    @Test @MainActor func seedDefaultsCreatesAndIsIdempotent() throws {
        // No data initially
        #expect(try context.fetch(FetchDescriptor<ExerciseType>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<UnitType>()).isEmpty)

        // Seed
        SeedService.seedDefaultExercises(context: context)
        SeedService.seedDefaultUnits(context: context)

        let e1 = try context.fetch(FetchDescriptor<ExerciseType>())
        let u1 = try context.fetch(FetchDescriptor<UnitType>())
        #expect(e1.count > 0)
        #expect(u1.count > 0)

        // Run again shouldn't change counts
        SeedService.seedDefaultExercises(context: context)
        SeedService.seedDefaultUnits(context: context)
        let e2 = try context.fetch(FetchDescriptor<ExerciseType>())
        let u2 = try context.fetch(FetchDescriptor<UnitType>())
        #expect(e2.count == e1.count)
        #expect(u2.count == u1.count)
    }

    @Test @MainActor func seedingFillsBlankAbbreviations() throws {
        let blank = UnitType(name: "Minutes", abbreviation: "", category: .other)
        context.insert(blank)
        try context.save()

        SeedService.seedDefaultUnits(context: context)
        let units = try context.fetch(FetchDescriptor<UnitType>())
        let minutes = units.first { $0.name.lowercased() == "minutes" }
        #expect(minutes != nil)
        #expect(minutes?.abbreviation == "min")
    }

    // MARK: - Deduplication
    @Test @MainActor func dayLogDeduplicationKeepsWithItems() throws {
        let today = Date().startOfDay()
        let a = DayLog(date: today)
        let b = DayLog(date: today)
        let c = DayLog(date: today)
        let ex = ExerciseType(name: "Test", baseMET: 4, repWeight: 0.1, defaultPaceMinPerMi: 10)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let item = ExerciseItem(exercise: ex, unit: unit, amount: 10)
        b.items = [item]; item.dayLog = b
        context.insert(a); context.insert(b); context.insert(c)
        context.insert(ex); context.insert(unit); context.insert(item)
        try context.save()

        DedupService.cleanupDuplicateDayLogs(context: context)
        let after = try context.fetch(FetchDescriptor<DayLog>())
        let todays = after.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        #expect(todays.count == 1)
        #expect(!todays.first!.unwrappedItems.isEmpty)
    }

    @Test @MainActor func exerciseTypeDeduplication() throws {
        let e1 = ExerciseType(name: "Walking", baseMET: 3.0, repWeight: 0.1, defaultPaceMinPerMi: 12)
        let e2 = ExerciseType(name: "walking", baseMET: 4.0, repWeight: 0.2, defaultPaceMinPerMi: 10)
        context.insert(e1); context.insert(e2)
        try context.save()
        DedupService.cleanupDuplicateExerciseTypes(context: context)
        let all = try context.fetch(FetchDescriptor<ExerciseType>())
        #expect(all.filter { $0.name.lowercased() == "walking" }.count == 1)
    }

    @Test @MainActor func unitTypeDeduplication() throws {
        let u1 = UnitType(name: "Minutes", abbreviation: "min", category: .minutes)
        let u2 = UnitType(name: "minutes", abbreviation: "mins", category: .minutes)
        context.insert(u1); context.insert(u2)
        try context.save()
        DedupService.cleanupDuplicateUnitTypes(context: context)
        let all = try context.fetch(FetchDescriptor<UnitType>())
        #expect(all.filter { $0.name.lowercased() == "minutes" }.count == 1)
    }

    // MARK: - Helpers
    @Test func stepForUnitCategoryHelper() {
        #expect(stepForUnitCategory(.reps) == 1)
        #expect(stepForUnitCategory(.steps) == 1)
        #expect(stepForUnitCategory(.distanceMi) == 0.1)
        #expect(stepForUnitCategory(.minutes) == 0.5)
        #expect(stepForUnitCategory(.other) == 0.5)
        #expect(stepForUnitCategory(nil) == 0.5)
    }

    @Test func amountOnlyStringHelper() {
        let minutes = UnitType(name: "Minutes", abbreviation: "min", category: .minutes)
        let reps = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        #expect(amountOnlyString(12.34, unit: nil) == "12")
        #expect(amountOnlyString(12.34, unit: minutes) == "12.3")
        #expect(amountOnlyString(5.0, unit: reps) == "5")
    }
}
