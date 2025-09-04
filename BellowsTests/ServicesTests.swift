import Testing
import SwiftData
import Foundation
@testable import Bellows

struct ServicesTests {
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
        let ex = ExerciseType(name: "Test", baseMET: 4, repWeight: 0.1, defaultPaceMinPerMi: 10, defaultUnit: nil)
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
        let e1 = ExerciseType(name: "Walking", baseMET: 3.0, repWeight: 0.1, defaultPaceMinPerMi: 12, defaultUnit: nil)
        let e2 = ExerciseType(name: "walking", baseMET: 4.0, repWeight: 0.2, defaultPaceMinPerMi: 10, defaultUnit: nil)
        let unit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let item = ExerciseItem(exercise: e2, unit: unit, amount: 15)
        context.insert(e1); context.insert(e2); context.insert(unit); context.insert(item)
        try context.save()
        DedupService.cleanupDuplicateExerciseTypes(context: context)
        let all = try context.fetch(FetchDescriptor<ExerciseType>())
        #expect(all.filter { $0.name.lowercased() == "walking" }.count == 1)

        // Verify reassignment: the item's exercise should point to the surviving type
        let items = try context.fetch(FetchDescriptor<ExerciseItem>())
        #expect(items.count == 1)
        #expect(items.first?.exercise?.name.lowercased() == "walking")
    }

    @Test @MainActor func unitTypeDeduplication() throws {
        let u1 = UnitType(name: "Minutes", abbreviation: "min", category: .time)
        let u2 = UnitType(name: "minutes", abbreviation: "mins", category: .time)
        let ex = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12, defaultUnit: u2)
        let item = ExerciseItem(exercise: ex, unit: u2, amount: 30)
        context.insert(u1); context.insert(u2); context.insert(ex); context.insert(item)
        try context.save()
        DedupService.cleanupDuplicateUnitTypes(context: context)
        let all = try context.fetch(FetchDescriptor<UnitType>())
        #expect(all.filter { $0.name.lowercased() == "minutes" }.count == 1)

        // Verify reassignment on ExerciseItem and ExerciseType default
        let items = try context.fetch(FetchDescriptor<ExerciseItem>())
        #expect(items.first?.unit?.name.lowercased() == "minutes")
        let exercises = try context.fetch(FetchDescriptor<ExerciseType>())
        let walk = exercises.first { $0.name == "Walk" }
        #expect(walk?.defaultUnit?.name.lowercased() == "minutes")
    }

    // MARK: - Helpers
    @Test func stepForUnitCategoryHelper() {
        #expect(stepForUnitCategory(.reps) == 1)
        #expect(stepForUnitCategory(.steps) == 1)
        #expect(stepForUnitCategory(.distance) == 0.1)
        #expect(stepForUnitCategory(.time) == 0.5)
        #expect(stepForUnitCategory(.other) == 0.5)
        #expect(stepForUnitCategory(nil) == 0.5)
    }

    @Test func amountOnlyStringHelper() {
        let minutes = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let reps = UnitType(name: "Reps", abbreviation: "reps", stepSize: 1.0, displayAsInteger: true)
        #expect(amountOnlyString(12.34, unit: nil) == "12.3")
        #expect(amountOnlyString(12.34, unit: minutes) == "12.3")
        #expect(amountOnlyString(5.0, unit: reps) == "5")
    }
}
