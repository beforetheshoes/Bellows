import Testing
import SwiftData
import Foundation
@testable import Bellows

@MainActor
struct ImportApplyMoreTests {
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

    @Test func hk_keep_import_updates_fields() async throws {
        let miles = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let walk = ExerciseType(name: "Walk", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: miles)
        context.insert(miles); context.insert(walk); try context.save()

        let day = DayLog(date: Date().startOfDay()); context.insert(day)
        let local = ExerciseItem(exercise: walk, unit: miles, amount: 1.0, note: "Imported from Apple Health", enjoyment: 3, intensity: 3, at: Date())
        local.healthKitWorkoutUUID = "HK-ABC"; local.modifiedAt = Date(timeIntervalSince1970: 100); local.dayLog = day
        context.insert(local); try context.save()

        // Import with newer modifiedAt and different amount
        let nowISO = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 200))
        let startISO = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 150))
        let dd = ISO8601DateFormatter().string(from: Date().startOfDay())
        let json = """
        {"version":1,"exportedAt":"\(nowISO)","units":[],"exercises":[],"days":[{"date":"\(dd)","items":[
          {"exerciseName":"Walk","unitName":"Miles","amount":2.0,"note":"Imported from Apple Health","enjoyment":4,"intensity":3,"createdAt":"\(startISO)","modifiedAt":"\(nowISO)","healthKitWorkoutUUID":"HK-ABC"}
        ]}]}
        """.data(using: .utf8)!

        var decisions = DataImportService.ImportDecisions()
        decisions.keepImport = ["hk:HK-ABC"]
        try DataImportService.applyImport(from: json, modelContext: context, restoreMode: false, decisions: decisions)

        let all = try context.fetch(FetchDescriptor<ExerciseItem>())
        let updated = all.first { $0.healthKitWorkoutUUID == "HK-ABC" }!
        #expect(abs(updated.amount - 2.0) < 0.0001)
        #expect(updated.enjoyment == 4)
    }

    @Test func merge_mode_does_not_restore_tombstoned_item() async throws {
        let reps = UnitType(name: "Reps", abbreviation: "", stepSize: 1, displayAsInteger: true)
        let squats = ExerciseType(name: "Squats", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: reps)
        context.insert(reps); context.insert(squats); try context.save()

        let day = DayLog(date: Date().startOfDay()); context.insert(day)
        let e4 = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: Date(timeIntervalSince1970: 100))
        e4.logicalID = "E4"; e4.modifiedAt = e4.createdAt; e4.dayLog = day; context.insert(e4); try context.save()
        DedupService.deleteItemWithTombstone(e4, context: context)

        let dd = ISO8601DateFormatter().string(from: Date().startOfDay())
        let created = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 100))
        let json = """
        {"version":1,"exportedAt":"\(dd)","units":[],"exercises":[],"days":[{"date":"\(dd)","items":[
          {"logicalID":"E4","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"\(created)","modifiedAt":"\(created)"}
        ]}]}
        """.data(using: .utf8)!

        try DataImportService.applyImport(from: json, modelContext: context, restoreMode: false, decisions: .init())
        let all = try context.fetch(FetchDescriptor<ExerciseItem>())
        #expect(!all.contains { $0.logicalID == "E4" })
    }

    @Test func restore_mode_clears_tombstone() async throws {
        let reps = UnitType(name: "Reps", abbreviation: "", stepSize: 1, displayAsInteger: true)
        let squats = ExerciseType(name: "Squats", baseMET: 4, repWeight: 0.15, defaultPaceMinPerMi: 10, iconSystemName: nil, defaultUnit: reps)
        context.insert(reps); context.insert(squats); try context.save()

        let day = DayLog(date: Date().startOfDay()); context.insert(day)
        let e4 = ExerciseItem(exercise: squats, unit: reps, amount: 10, note: nil, enjoyment: 3, intensity: 3, at: Date(timeIntervalSince1970: 100))
        e4.logicalID = "E4"; e4.modifiedAt = e4.createdAt; e4.dayLog = day; context.insert(e4); try context.save()
        DedupService.deleteItemWithTombstone(e4, context: context)

        let dd = ISO8601DateFormatter().string(from: Date().startOfDay())
        let created = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 100))
        let json = """
        {"version":1,"exportedAt":"\(dd)","units":[],"exercises":[],"days":[{"date":"\(dd)","items":[
          {"logicalID":"E4","exerciseName":"Squats","unitName":"Reps","amount":10,"note":null,"enjoyment":3,"intensity":3,"createdAt":"\(created)","modifiedAt":"\(created)"}
        ]}]}
        """.data(using: .utf8)!

        try DataImportService.applyImport(from: json, modelContext: context, restoreMode: true, decisions: .init())
        // Assert item restored
        let all = try context.fetch(FetchDescriptor<ExerciseItem>())
        #expect(all.contains { $0.logicalID == "E4" })
        // Assert tombstone cleared from KVS
        let kv = NSUbiquitousKeyValueStore.default; kv.synchronize()
        let ids = (kv.array(forKey: "deleted_item_ids_v1") as? [String]) ?? []
        #expect(!ids.contains("E4"))
    }
}
