import Testing
import SwiftData
import Foundation
@testable import Bellows

@MainActor
struct ImportConflictPlanningTests {
    let container: ModelContainer
    let context: ModelContext

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try! ModelContainer(for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self, configurations: config)
        context = ModelContext(container)
        // Clear KVS/UserDefaults tombstones for repeatability
        let kv = NSUbiquitousKeyValueStore.default
        kv.removeObject(forKey: "deleted_item_ids_v1"); kv.removeObject(forKey: "deleted_item_hashes_v1")
        kv.removeObject(forKey: "hk_deleted_workouts_v1"); kv.synchronize()
        UserDefaults.standard.removeObject(forKey: "deleted_item_ids_v1")
        UserDefaults.standard.removeObject(forKey: "deleted_item_hashes_v1")
        UserDefaults.standard.removeObject(forKey: "hk_deleted_workouts_v1")
    }

    private func unit(named name: String) -> UnitType {
        let u = UnitType(name: name, abbreviation: name == "Reps" ? "" : (name == "Miles" ? "mi" : name.lowercased()), stepSize: 1, displayAsInteger: name == "Reps")
        context.insert(u); try? context.save(); return u
    }
    private func exercise(named name: String, defaultUnit: UnitType? = nil) -> ExerciseType {
        let e = ExerciseType(name: name, baseMET: 4.0, repWeight: 0.15, defaultPaceMinPerMi: 10.0, iconSystemName: nil, defaultUnit: defaultUnit)
        context.insert(e); try? context.save(); return e
    }

    @Test func plan_merges_and_honors_tombstones_vs_restore() async throws {
        // Setup units and exercises
        let reps = unit(named: "Reps")
        let miles = unit(named: "Miles")
        let minutes = unit(named: "Minutes")
        let squats = exercise(named: "Squats", defaultUnit: reps)
        _ = exercise(named: "Pushups", defaultUnit: reps)
        _ = exercise(named: "Tricep Dip", defaultUnit: reps)
        let walk = exercise(named: "Walk", defaultUnit: miles)

        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)

        func makeItem(ex: ExerciseType, unit: UnitType, amount: Double, created: String, modified: String, logicalID: String, note: String? = nil, hkUUID: String? = nil) -> ExerciseItem {
            let c = ISO8601DateFormatter().date(from: created)!;
            let m = ISO8601DateFormatter().date(from: modified)!;
            let item = ExerciseItem(exercise: ex, unit: unit, amount: amount, note: note, enjoyment: 3, intensity: 3, at: c)
            item.modifiedAt = m
            item.logicalID = logicalID
            item.healthKitWorkoutUUID = hkUUID
            item.dayLog = day
            if day.items == nil { day.items = [] }
            day.items?.append(item); context.insert(item)
            return item
        }

        // Local current state
        _ = makeItem(ex: squats, unit: reps, amount: 10, created: "2025-09-03T17:00:00Z", modified: "2025-09-03T22:10:00Z", logicalID: "E1") // enjoyment updated later (not modeled here, but modified newer)
        _ = makeItem(ex: walk, unit: miles, amount: 1.2102544009, created: "2025-09-03T18:30:00Z", modified: "2025-09-03T18:31:00Z", logicalID: "E2", note: "Imported from Apple Health", hkUUID: "HK-UUID-2")
        _ = makeItem(ex: walk, unit: minutes, amount: 15, created: "2025-09-03T19:00:00Z", modified: "2025-09-03T19:10:00Z", logicalID: "E3")
        let e4 = makeItem(ex: squats, unit: reps, amount: 10, created: "2025-09-03T20:00:00Z", modified: "2025-09-03T20:00:00Z", logicalID: "E4")
        _ = makeItem(ex: squats, unit: reps, amount: 10, created: "2025-09-03T20:01:00Z", modified: "2025-09-03T20:01:00Z", logicalID: "E5")
        try context.save()

        // Delete E4 with tombstone
        DedupService.deleteItemWithTombstone(e4, context: context)

        // Import bundle (JSON) reflecting backup with E1 older, E2 HK, E3 older (1 mile), E4 present, E5 present
        let json = """
        {
          "version": 1,
          "exportedAt": "2025-09-04T12:00:00Z",
          "units": [],
          "exercises": [],
          "days": [
            {
              "date": "2025-09-03T04:00:00Z",
              "items": [
                {"logicalID":"E1","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":2,"intensity":3,"createdAt":"2025-09-03T17:00:00Z","modifiedAt":"2025-09-03T21:00:00Z"},
                {"exerciseName":"Walk","unitName":"Miles","amount":1.210254400872232,"note":"Imported from Apple Health","enjoyment":3,"intensity":3,"createdAt":"2025-09-03T18:30:00Z","modifiedAt":"2025-09-03T18:31:00Z","healthKitWorkoutUUID":"HK-UUID-2"},
                {"logicalID":"E3","exerciseName":"Walk","unitName":"Miles","amount":1.0,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T19:00:00Z","modifiedAt":"2025-09-03T19:05:00Z"},
                {"logicalID":"E4","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"},
                {"logicalID":"E5","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:01:00Z","modifiedAt":"2025-09-03T20:01:00Z"}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        // Plan with merge mode (tombstones respected)
        let planMerge = try DataImportService.planImport(from: json, modelContext: context, restoreMode: false)
        // Identity conflicts should include E1 and E3 with newerSide == .local
        let cE1 = planMerge.identityConflicts.first(where: { $0.logicalID == "E1" })
        let cE3 = planMerge.identityConflicts.first(where: { $0.logicalID == "E3" })
        #expect(cE1?.newer == .local)
        #expect(cE3?.newer == .local)
        // HK item exists locally; if included, it should be equal
        if let cHK = planMerge.identityConflicts.first(where: { $0.hkUUID == "HK-UUID-2" }) {
            #expect(cHK.newer == .equal)
        }
        #expect(planMerge.tombstoneConflicts.contains(where: { $0.logicalID == "E4" }))
        #expect(planMerge.plannedInserts.isEmpty)

        // Plan with restore mode (tombstones ignored and cleared for selected)
        let planRestore = try DataImportService.planImport(from: json, modelContext: context, restoreMode: true)
        #expect(planRestore.plannedInserts.contains(where: { $0.logicalID == "E4" }))
    }

    @Test func plan_detects_hk_newer_side_and_legacy_inserts_and_near_dupes() async throws {
        // Units/exercises
        let reps = unit(named: "Reps")
        let miles = unit(named: "Miles")
        let walk = exercise(named: "Walk", defaultUnit: miles)
        let squats = exercise(named: "Squats", defaultUnit: reps)

        // Local: HK walk with older modifiedAt
        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)
        let hkLocal = ExerciseItem(exercise: walk, unit: miles, amount: 1.0, note: "Imported from Apple Health", enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T18:30:00Z")!)
        hkLocal.modifiedAt = ISO8601DateFormatter().date(from: "2025-09-03T18:31:00Z")!
        hkLocal.healthKitWorkoutUUID = "HK-UUID-A"; hkLocal.dayLog = day; context.insert(hkLocal)

        // Local: a squats at 20:00
        let sqLocal = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T20:00:00Z")!)
        sqLocal.modifiedAt = sqLocal.createdAt; sqLocal.dayLog = day; context.insert(sqLocal)
        try context.save()

        // Import JSON: HK with newer modifiedAt; one legacy without logicalID (insert);
        // one near duplicate squats at 20:00:08 (within tight window) without logicalID
        let json = """
        {
          "version": 1,
          "exportedAt": "2025-09-04T12:00:00Z",
          "units": [],
          "exercises": [],
          "days": [
            {
              "date": "2025-09-03T04:00:00Z",
              "items": [
                {"exerciseName":"Walk","unitName":"Miles","amount":1.0,"note":"Imported from Apple Health","enjoyment":3,"intensity":3,"createdAt":"2025-09-03T18:30:00Z","modifiedAt":"2025-09-03T19:31:00Z","healthKitWorkoutUUID":"HK-UUID-A"},
                {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:00:08Z","modifiedAt":"2025-09-03T20:00:08Z"},
                {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T21:00:00Z","modifiedAt":"2025-09-03T21:00:00Z"}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let plan = try DataImportService.planImport(from: json, modelContext: context, restoreMode: false)
        // HK conflict newer should be importFile
        let hkC = plan.identityConflicts.first(where: { $0.hkUUID == "HK-UUID-A" })
        #expect(hkC?.newer == .importFile)
        // Legacy insert present
        #expect(plan.plannedInserts.contains(where: { $0.logicalID == nil }))
        // Near duplicate detected for the +8s squats
        #expect(plan.nearDuplicates.contains(where: { abs($0.importCreatedAt.timeIntervalSince($0.localCreatedAt)) <= 15 }))
    }

    @Test func identity_exact_content_and_modified_matches_classified_as_already_exists() async throws {
        // Seed
        let reps = unit(named: "Reps"); let squats = exercise(named: "Squats", defaultUnit: reps)
        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T00:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)
        let t = ISO8601DateFormatter().date(from: "2025-09-03T10:00:00Z")!
        let local = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: t)
        local.logicalID = "L1"; local.modifiedAt = t; local.dayLog = day; context.insert(local); try context.save()

        // Import has same logicalID and identical content with same modifiedAt
        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T00:00:00Z","items":[
          {"logicalID":"L1","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T10:00:00Z","modifiedAt":"2025-09-03T10:00:00Z"}
        ]}]}
        """.data(using: .utf8)!

        let plan = try DataImportService.planImport(from: json, modelContext: context, restoreMode: false)
        #expect(plan.identityConflicts.isEmpty)
        #expect(plan.alreadyExists.count == 1)
    }

    @Test func identity_same_content_but_newer_import_is_conflict() async throws {
        let reps = unit(named: "Reps"); let squats = exercise(named: "Squats", defaultUnit: reps)
        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T00:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)
        let t = ISO8601DateFormatter().date(from: "2025-09-03T10:00:00Z")!
        let local = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: t)
        local.logicalID = "L2"; local.modifiedAt = t; local.dayLog = day; context.insert(local); try context.save()

        // Import has same L2 but newer modifiedAt
        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T00:00:00Z","items":[
          {"logicalID":"L2","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T10:00:00Z","modifiedAt":"2025-09-03T11:00:00Z"}
        ]}]}
        """.data(using: .utf8)!

        let plan = try DataImportService.planImport(from: json, modelContext: context, restoreMode: false)
        let c = plan.identityConflicts.first
        #expect(c != nil)
        #expect(c?.newer == .importFile)
    }

    @Test func near_duplicate_window_boundaries_14s_vs_16s() async throws {
        let reps = unit(named: "Reps"); let squats = exercise(named: "Squats", defaultUnit: reps)
        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T00:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)
        let base = ISO8601DateFormatter().date(from: "2025-09-03T10:00:00Z")!
        let local = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: base)
        local.dayLog = day; context.insert(local); try context.save()

        // +14s should be near-dup
        let json14 = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T00:00:00Z","items":[
          {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T10:00:14Z","modifiedAt":"2025-09-03T10:00:14Z"}
        ]}]}
        """.data(using: .utf8)!
        let plan14 = try DataImportService.planImport(from: json14, modelContext: context, restoreMode: false)
        #expect(plan14.nearDuplicates.count == 1)

        // +16s should be a planned insert
        let json16 = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[{"date":"2025-09-03T00:00:00Z","items":[
          {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T10:00:16Z","modifiedAt":"2025-09-03T10:00:16Z"}
        ]}]}
        """.data(using: .utf8)!
        let plan16 = try DataImportService.planImport(from: json16, modelContext: context, restoreMode: false)
        #expect(plan16.plannedInserts.count == 1)
    }

    @Test func apply_import_keep_import_updates_fields_and_restoreMode_restores_without_explicit_key() async throws {
        // Units/exercises
        let reps = unit(named: "Reps")
        let miles = unit(named: "Miles")
        let walk = exercise(named: "Walk", defaultUnit: miles)
        let squats = exercise(named: "Squats", defaultUnit: reps)

        // Local state: E3 walk at 19:00 minutes 15, E4 deleted tombstone
        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)
        let e3 = ExerciseItem(exercise: walk, unit: miles, amount: 1.0, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T19:00:00Z")!)
        e3.logicalID = "E3"; e3.modifiedAt = ISO8601DateFormatter().date(from: "2025-09-03T19:10:00Z")!; context.insert(e3); e3.dayLog = day
        let e4 = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T20:00:00Z")!)
        e4.logicalID = "E4"; e4.modifiedAt = e4.createdAt; context.insert(e4); e4.dayLog = day
        try context.save()
        DedupService.deleteItemWithTombstone(e4, context: context)

        // Import: E3 miles 2.0 newer; E4 present in file
        let json = """
        {
          "version": 1,
          "exportedAt": "2025-09-04T12:00:00Z",
          "units": [],
          "exercises": [],
          "days": [
            {"date":"2025-09-03T04:00:00Z","items":[
              {"logicalID":"E3","exerciseName":"Walk","unitName":"Miles","amount":2.0,"note":null,"enjoyment":4,"intensity":3,"createdAt":"2025-09-03T19:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"},
              {"logicalID":"E4","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"}
            ]}
          ]
        }
        """.data(using: .utf8)!

        // Keep import for E3, and run restoreMode true (should restore E4 without explicit key)
        var decisions = DataImportService.ImportDecisions()
        decisions.keepImport = ["id:E3"]
        try DataImportService.applyImport(from: json, modelContext: context, restoreMode: true, decisions: decisions)

        let all = try context.fetch(FetchDescriptor<ExerciseItem>())
        let e3Final = all.first(where: { $0.logicalID == "E3" })!
        #expect(abs(e3Final.amount - 2.0) < 0.0001)
        #expect(e3Final.enjoyment == 4)
        #expect(all.contains { $0.logicalID == "E4" })
    }

    @Test func apply_import_skips_near_duplicate_legacy_by_default_and_inserts_when_forced() async throws {
        let reps = unit(named: "Reps")
        let squats = exercise(named: "Squats", defaultUnit: reps)

        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)
        let local = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: ISO8601DateFormatter().date(from: "2025-09-03T20:00:00Z")!)
        local.dayLog = day; context.insert(local); try context.save()

        let json = """
        {"version":1,"exportedAt":"2025-09-04T12:00:00Z","units":[],"exercises":[],"days":[
          {"date":"2025-09-03T04:00:00Z","items":[
            {"exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:00:08Z","modifiedAt":"2025-09-03T20:00:08Z"}
          ]}
        ]}
        """.data(using: .utf8)!

        // Default: skip near-duplicate
        try DataImportService.applyImport(from: json, modelContext: context, restoreMode: false, decisions: .init())
        var all = try context.fetch(FetchDescriptor<ExerciseItem>())
        #expect(all.count == 1)

        // Force insert with legacy key
        var decisions = DataImportService.ImportDecisions()
        let created = ISO8601DateFormatter().date(from: "2025-09-03T20:00:08Z")!
        let key = DataImportService.decisionKeyForLegacy(exerciseName: "Squats", unitName: "Reps", amount: 10, enjoyment: 3, intensity: 3, createdAt: created)
        decisions.insertLegacyKeys = [key]
        try DataImportService.applyImport(from: json, modelContext: context, restoreMode: false, decisions: decisions)
        all = try context.fetch(FetchDescriptor<ExerciseItem>())
        #expect(all.count == 2)
    }

    @Test func apply_import_with_decisions_restores_tombstoned_and_keeps_local() async throws {
        // Setup
        let reps = unit(named: "Reps")
        let miles = unit(named: "Miles")
        let squats = exercise(named: "Squats", defaultUnit: reps)
        let walk = exercise(named: "Walk", defaultUnit: miles)

        let dayDate = ISO8601DateFormatter().date(from: "2025-09-03T04:00:00Z")!.startOfDay()
        let day = DayLog(date: dayDate); context.insert(day)

        func makeItem(ex: ExerciseType, unit: UnitType, amount: Double, created: String, modified: String, logicalID: String, note: String? = nil, hkUUID: String? = nil) -> ExerciseItem {
            let c = ISO8601DateFormatter().date(from: created)!;
            let m = ISO8601DateFormatter().date(from: modified)!;
            let item = ExerciseItem(exercise: ex, unit: unit, amount: amount, note: note, enjoyment: 5, intensity: 3, at: c)
            item.modifiedAt = m
            item.logicalID = logicalID
            item.healthKitWorkoutUUID = hkUUID
            item.dayLog = day
            if day.items == nil { day.items = [] }
            day.items?.append(item); context.insert(item)
            return item
        }

        // Local state: E1 enjoyment 5 (newer), E2 HK present, E3 local minutes, E5 present
        _ = makeItem(ex: squats, unit: reps, amount: 10, created: "2025-09-03T17:00:00Z", modified: "2025-09-03T22:10:00Z", logicalID: "E1")
        _ = makeItem(ex: walk, unit: miles, amount: 1.2102, created: "2025-09-03T18:30:00Z", modified: "2025-09-03T18:31:00Z", logicalID: "E2", note: "Imported from Apple Health", hkUUID: "HK-UUID-2")
        _ = makeItem(ex: walk, unit: miles, amount: 1.0, created: "2025-09-03T19:00:00Z", modified: "2025-09-03T19:10:00Z", logicalID: "E3")
        let e4 = makeItem(ex: squats, unit: reps, amount: 10, created: "2025-09-03T20:00:00Z", modified: "2025-09-03T20:00:00Z", logicalID: "E4")
        _ = makeItem(ex: squats, unit: reps, amount: 10, created: "2025-09-03T20:01:00Z", modified: "2025-09-03T20:01:00Z", logicalID: "E5")
        try context.save()

        // Delete E4 with tombstone
        DedupService.deleteItemWithTombstone(e4, context: context)

        // Import JSON from backup (older E1/E3, has E4)
        let json = """
        {
          "version": 1,
          "exportedAt": "2025-09-04T12:00:00Z",
          "units": [],
          "exercises": [],
          "days": [
            {
              "date": "2025-09-03T04:00:00Z",
              "items": [
                {"logicalID":"E1","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":2,"intensity":3,"createdAt":"2025-09-03T17:00:00Z","modifiedAt":"2025-09-03T21:00:00Z"},
                {"exerciseName":"Walk","unitName":"Miles","amount":1.210254400872232,"note":"Imported from Apple Health","enjoyment":3,"intensity":3,"createdAt":"2025-09-03T18:30:00Z","modifiedAt":"2025-09-03T18:31:00Z","healthKitWorkoutUUID":"HK-UUID-2"},
                {"logicalID":"E3","exerciseName":"Walk","unitName":"Miles","amount":1.0,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T19:00:00Z","modifiedAt":"2025-09-03T19:05:00Z"},
                {"logicalID":"E4","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:00:00Z","modifiedAt":"2025-09-03T20:00:00Z"},
                {"logicalID":"E5","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"2025-09-03T20:01:00Z","modifiedAt":"2025-09-03T20:01:00Z"}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        // Decisions: keep local for E1 and E3; restore tombstoned E4
        var decisions = DataImportService.ImportDecisions()
        decisions.keepImport = [] // keep local by default
        decisions.restoreKeys = ["id:E4"]

        try DataImportService.applyImport(from: json, modelContext: context, restoreMode: false, decisions: decisions)

        // Assert final DB contains E1 (unchanged newer), E2 HK present, E3 local variant, E4 restored, E5 existing
        let all = try context.fetch(FetchDescriptor<ExerciseItem>())
        let ids = Set(all.map { $0.logicalID })
        #expect(ids.contains("E1"))
        #expect(ids.contains("E3"))
        #expect(ids.contains("E4"))
        #expect(ids.contains("E5"))
        #expect(all.contains { $0.healthKitWorkoutUUID == "HK-UUID-2" })
    }
}
