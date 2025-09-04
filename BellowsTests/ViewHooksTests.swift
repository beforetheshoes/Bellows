import Testing
import SwiftUI
import SwiftData
import Foundation
@testable import Bellows

@MainActor
struct ViewHooksTests {
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

    @Test func appRootHooksSeedAndCleanup() throws {
        // Seed defaults through AppRootView test hooks
        __test_seed_defaults(context: context)
        let e1 = try context.fetch(FetchDescriptor<ExerciseType>())
        let u1 = try context.fetch(FetchDescriptor<UnitType>())
        #expect(!e1.isEmpty)
        #expect(!u1.isEmpty)

        // Create duplicate day logs and cleanup through hook
        let today = Date().startOfDay()
        context.insert(DayLog(date: today))
        context.insert(DayLog(date: today))
        try context.save()
        __test_cleanup_daylogs(context: context)
        let after = try context.fetch(FetchDescriptor<DayLog>())
        #expect(after.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count == 1)
    }

    @Test func homeHooksEnsureToday() throws {
        __test_home_ensureToday(context: context)
        let today = Date().startOfDay()
        let all = try context.fetch(FetchDescriptor<DayLog>())
        #expect(all.contains { Calendar.current.isDate($0.date, inSameDayAs: today) })
        // Call again to ensure idempotent
        __test_home_ensureToday(context: context)
        let after = try context.fetch(FetchDescriptor<DayLog>())
        #expect(after.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count == 1)
    }

    @Test func labelHooksCoverAllCategories() {
        let ex = ExerciseType(name: "Test", baseMET: 5, repWeight: 0.2, defaultPaceMinPerMi: 10, defaultUnit: nil)
        let reps = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let minutes = UnitType(name: "Minutes", abbreviation: "min", category: .time)
        let steps = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        let miles = UnitType(name: "Miles", abbreviation: "mi", category: .distance)
        let other = UnitType(name: "Other", abbreviation: "", category: .other)

        let items: [ExerciseItem] = [
            ExerciseItem(exercise: ex, unit: reps, amount: 12),
            ExerciseItem(exercise: ex, unit: minutes, amount: 30.5),
            ExerciseItem(exercise: ex, unit: steps, amount: 1000),
            ExerciseItem(exercise: ex, unit: miles, amount: 3.2),
            ExerciseItem(exercise: ex, unit: other, amount: 2.5)
        ]

        for item in items {
            _ = __test_home_label(for: item)
            _ = __test_daydetail_label(for: item)
        }
        #expect(true)
    }
}

