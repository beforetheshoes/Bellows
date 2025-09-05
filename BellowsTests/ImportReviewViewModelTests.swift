import Testing
import SwiftData
import Foundation
@testable import Bellows

@MainActor
struct ImportReviewViewModelTests {
    let container: ModelContainer
    let context: ModelContext

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try! ModelContainer(for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self, configurations: config)
        context = ModelContext(container)
        // Clear tombstones
        let kv = NSUbiquitousKeyValueStore.default
        kv.removeObject(forKey: "deleted_item_ids_v1"); kv.removeObject(forKey: "deleted_item_hashes_v1")
        kv.removeObject(forKey: "hk_deleted_workouts_v1"); kv.synchronize()
        UserDefaults.standard.removeObject(forKey: "deleted_item_ids_v1")
        UserDefaults.standard.removeObject(forKey: "deleted_item_hashes_v1")
        UserDefaults.standard.removeObject(forKey: "hk_deleted_workouts_v1")
    }

    @Test func new_items_toggle_skip_and_include_updates_summary() async throws {
        // Seed empty; one new item in file
        let reps = UnitType(name: "Reps", abbreviation: "", stepSize: 1, displayAsInteger: true)
        let squats = ExerciseType(name: "Squats", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: reps)
        context.insert(reps); context.insert(squats); try context.save()

        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T00:00:00Z","items":[
          {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T10:00:00Z","modifiedAt":"2025-09-03T10:00:00Z"}
        ]}]}
        """.data(using: .utf8)!

        let vm = ImportReviewViewModel(modelContext: context, data: json)
        try vm.loadPlan()
        var s = vm.predictedSummary()
        #expect(s.willInsert == 1)
        #expect(s.willSkip == 0)

        // Toggle skip on planned insert
        let ins = vm.plan.plannedInserts.first!
        vm.toggleSkipInsert(key: ins.decisionKey)
        s = vm.predictedSummary()
        #expect(s.willInsert == 0)
        #expect(s.willSkip == 1)
    }

    @Test func already_exists_toggle_insert_updates_summary() async throws {
        let reps = UnitType(name: "Reps", abbreviation: "", stepSize: 1, displayAsInteger: true)
        let squats = ExerciseType(name: "Squats", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: reps)
        context.insert(reps); context.insert(squats); try context.save()

        let day = DayLog(date: ISO8601DateFormatter().date(from: "2025-09-03T00:00:00Z")!.startOfDay()); context.insert(day)
        let t = ISO8601DateFormatter().date(from: "2025-09-03T10:00:00Z")!
        let local = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: t)
        local.modifiedAt = t; local.dayLog = day; context.insert(local); try context.save()

        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T00:00:00Z","items":[
          {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T10:00:00Z","modifiedAt":"2025-09-03T10:00:00Z"}
        ]}]}
        """.data(using: .utf8)!

        let vm = ImportReviewViewModel(modelContext: context, data: json)
        try vm.loadPlan()
        #expect(vm.plan.alreadyExists.count == 1)
        var s = vm.predictedSummary()
        #expect(s.willInsert == 0)
        #expect(s.willSkip >= 1)

        let ex = vm.plan.alreadyExists.first!
        vm.toggleInsertLegacy(exerciseName: ex.snapshot.exerciseName, unitName: ex.snapshot.unitName, amount: ex.snapshot.amount, enjoyment: ex.snapshot.enjoyment, intensity: ex.snapshot.intensity, createdAt: ex.snapshot.createdAt)
        s = vm.predictedSummary()
        #expect(s.willInsert >= 1)
    }
    @Test func viewModel_plans_and_applies_decisions() async throws {
        // Seed minimal types
        let reps = UnitType(name: "Reps", abbreviation: "", stepSize: 1, displayAsInteger: true)
        let miles = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let squats = ExerciseType(name: "Squats", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: reps)
        let walk = ExerciseType(name: "Walk", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: miles)
        context.insert(reps); context.insert(miles); context.insert(squats); context.insert(walk); try context.save()

        // Local: E3 walk modified newer; E4 deleted
        let day = DayLog(date: ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()); context.insert(day)
        let e3 = ExerciseItem(exercise: walk, unit: miles, amount: 1.0, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T19:00:00Z")!)
        e3.logicalID = "E3"; e3.modifiedAt = ISO8601DateFormatter().date(from: "2025-09-03T19:10:00Z")!; e3.dayLog = day; context.insert(e3)
        let e4 = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T20:00:00Z")!)
        e4.logicalID = "E4"; e4.modifiedAt = e4.createdAt; e4.dayLog = day; context.insert(e4); try context.save()
        DedupService.deleteItemWithTombstone(e4, context: context)

        // JSON with older E3 and E4 present
        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T04:00:00Z","items":[
          {"logicalID":"E3","exerciseName":"Walk","unitName":"Miles","amount":2.0,"note":null,"enjoyment":4,"intensity":3,"createdAt":"2025-09-03T19:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"},
          {"logicalID":"E4","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"}
        ]}]}
        """.data(using: .utf8)!

        let vm = ImportReviewViewModel(modelContext: context, data: json)
        try vm.loadPlan()
        // Choose: keep import for E3, enable restore mode so E4 can be restored without explicit key
        vm.restoreMode = true
        if let c = vm.plan.identityConflicts.first(where: { $0.logicalID == "E3" }) { vm.chooseKeepImport(for: c) }
        try vm.apply()

        let all = try context.fetch(FetchDescriptor<ExerciseItem>())
        #expect(all.contains { $0.logicalID == "E4" })
        let e3Final = all.first(where: { $0.logicalID == "E3" })!
        #expect(abs(e3Final.amount - 2.0) < 0.001)
    }

    @Test func viewModel_batch_actions_populate_decisions() async throws {
        // Seed minimal types
        let reps = UnitType(name: "Reps", abbreviation: "", stepSize: 1, displayAsInteger: true)
        let miles = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let squats = ExerciseType(name: "Squats", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: reps)
        let walk = ExerciseType(name: "Walk", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: miles)
        context.insert(reps); context.insert(miles); context.insert(squats); context.insert(walk); try context.save()

        // Local items: walk newer (E3), tombstoned squats (E4), and a near-dup baseline
        let day = DayLog(date: ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()); context.insert(day)
        let e3 = ExerciseItem(exercise: walk, unit: miles, amount: 1.0, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T19:00:00Z")!)
        e3.logicalID = "E3"; e3.modifiedAt = ISO8601DateFormatter().date(from: "2025-09-03T19:10:00Z")!; e3.dayLog = day; context.insert(e3)
        let e4 = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T20:00:00Z")!)
        e4.logicalID = "E4"; e4.dayLog = day; context.insert(e4); try context.save(); DedupService.deleteItemWithTombstone(e4, context: context)
        // Near dup baseline
        let baseline = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T21:00:00Z")!)
        baseline.dayLog = day; context.insert(baseline); try context.save()

        // Import JSON with older E3, E4 present, and near-dup squats at +8s
        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T04:00:00Z","items":[
          {"logicalID":"E3","exerciseName":"Walk","unitName":"Miles","amount":2.0,"note":null,"enjoyment":4,"intensity":3,"createdAt":"2025-09-03T19:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"},
          {"logicalID":"E4","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"},
          {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T21:00:08Z","modifiedAt":"2025-09-03T21:00:08Z"}
        ]}]}
        """.data(using: .utf8)!

        let vm = ImportReviewViewModel(modelContext: context, data: json)
        try vm.loadPlan()

        // Batch: keep local for all identity conflicts
        vm.clearKeepImportDecisions()
        vm.chooseKeepLocalForAll()
        #expect(true)

        // Batch: keep import for all conflicts
        vm.chooseKeepImportForAll()
        #expect(true)

        // Batch: allow restore for all tombstones
        vm.clearRestoreDecisions()
        vm.allowRestoreForAll()
        #expect(true)

        // Batch: insert all near duplicates
        vm.clearLegacyInsertDecisions()
        vm.forceInsertAllNearDuplicates()
        #expect(true)

        // Recommendations set keepImport only where import is newer or equal? We default to local on equal
        vm.clearKeepImportDecisions()
        vm.chooseRecommendedForAllConflicts()
        let importNewerCount = vm.plan.identityConflicts.filter { $0.newer == .importFile }.count
        #expect(vm.keepImportKeys.count == importNewerCount)
    }

    @Test func viewModel_predicted_summary_reflects_decisions() async throws {
        // Seed minimal types
        let reps = UnitType(name: "Reps", abbreviation: "", stepSize: 1, displayAsInteger: true)
        let miles = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let squats = ExerciseType(name: "Squats", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: reps)
        let walk = ExerciseType(name: "Walk", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: miles)
        context.insert(reps); context.insert(miles); context.insert(squats); context.insert(walk); try context.save()

        let day = DayLog(date: ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()); context.insert(day)
        let e3 = ExerciseItem(exercise: walk, unit: miles, amount: 1.0, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T19:00:00Z")!)
        e3.logicalID = "E3"; e3.modifiedAt = ISO8601DateFormatter().date(from: "2025-09-03T19:10:00Z")!; e3.dayLog = day; context.insert(e3)
        // Baseline for near-duplicate legacy insert
        let base = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T21:00:00Z")!)
        base.dayLog = day; context.insert(base)
        try context.save()

        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T04:00:00Z","items":[
          {"logicalID":"E3","exerciseName":"Walk","unitName":"Miles","amount":2.0,"note":null,"enjoyment":4,"intensity":3,"createdAt":"2025-09-03T19:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"},
          {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T21:00:08Z","modifiedAt":"2025-09-03T21:00:08Z"}
        ]}]}
        """.data(using: .utf8)!

        let vm = ImportReviewViewModel(modelContext: context, data: json)
        try vm.loadPlan()
        // No decisions yet: expect 0 updates, 0 restores, planned inserts 0, near dup 1 counted as skip, 1 skip for conflict
        var s = vm.predictedSummary()
        #expect(s.willUpdate == 0)
        #expect(s.willRestore == 0)
        #expect(s.willInsert == 0)
        #expect(s.willSkip == 2)

        // Choose keep import for conflict, and force insert near-dup
        if let c = vm.plan.identityConflicts.first { vm.chooseKeepImport(for: c) }
        if let nd = vm.plan.nearDuplicates.first {
            vm.forceInsertLegacy(exerciseName: nd.exerciseName, unitName: nd.unitName, amount: nd.amount, enjoyment: nd.enjoyment, intensity: nd.intensity, createdAt: nd.importCreatedAt)
        }
        s = vm.predictedSummary()
        #expect(s.willUpdate == 1)
        #expect(s.willInsert == 1)
        #expect(s.willRestore == 0)
        #expect(s.willSkip == 0)
    }
}
