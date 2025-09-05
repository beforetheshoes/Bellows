import SwiftData
import Foundation

@MainActor
struct DedupService {
    // Tombstone keys for general ExerciseItem deletions (non-HealthKit specific)
    private static let deletedItemIDsKey = "deleted_item_ids_v1"
    private static let deletedItemHashesKey = "deleted_item_hashes_v1"

    private static func itemContentHash(_ item: ExerciseItem) -> String {
        func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let parts: [String] = [
            norm(item.exercise?.name),
            norm(item.unit?.name),
            String(format: "%.3f", item.amount),
            String(item.enjoyment),
            String(item.intensity),
            String(Int(item.createdAt.timeIntervalSince1970))
        ]
        return parts.joined(separator: "|")
    }

    static func deleteItemWithTombstone(_ item: ExerciseItem, context: ModelContext) {
        // Persist tombstone to KVS and UserDefaults
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        var ids = (kv.array(forKey: deletedItemIDsKey) as? [String]) ?? (UserDefaults.standard.array(forKey: deletedItemIDsKey) as? [String]) ?? []
        var hashes = (kv.array(forKey: deletedItemHashesKey) as? [String]) ?? (UserDefaults.standard.array(forKey: deletedItemHashesKey) as? [String]) ?? []
        if !ids.contains(item.logicalID) { ids.append(item.logicalID) }
        let h = itemContentHash(item)
        if !hashes.contains(h) { hashes.append(h) }
        UserDefaults.standard.set(ids, forKey: deletedItemIDsKey)
        UserDefaults.standard.set(hashes, forKey: deletedItemHashesKey)
        kv.set(ids, forKey: deletedItemIDsKey)
        kv.set(hashes, forKey: deletedItemHashesKey)
        kv.synchronize()

        // Delete the item from the model
        context.delete(item)
        do { try context.save() } catch { print("ERROR: deleteItemWithTombstone save failed: \(error)") }
    }

    static func enforceDeletedItemTombstones(context: ModelContext) {
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        let ids = Set((kv.array(forKey: deletedItemIDsKey) as? [String]) ?? (UserDefaults.standard.array(forKey: deletedItemIDsKey) as? [String]) ?? [])
        // Do not use content-hash for deletions in the live database to avoid false positives.
        do {
            let all = try context.fetch(FetchDescriptor<ExerciseItem>())
            var changed = false
            for item in all {
                if ids.contains(item.logicalID) {
                    context.delete(item)
                    changed = true
                }
            }
            if changed { try context.save() }
        } catch {
            print("ERROR: enforceDeletedItemTombstones failed: \(error)")
        }
    }
    static func cleanupDuplicateDayLogs(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<DayLog>())
            let grouped = Dictionary(grouping: all) { $0.date.startOfDay() }
            
            for (_, logs) in grouped {
                if logs.count > 1 {
                    // Keep the one with the most recent createdAt (or most items if createdAt is same)
                    let keeper = logs.max { a, b in
                        if a.createdAt == b.createdAt {
                            return (a.items?.count ?? 0) < (b.items?.count ?? 0)
                        }
                        return a.createdAt < b.createdAt
                    }
                    
                    for log in logs {
                        if log !== keeper {
                            // Move items from duplicate to keeper before deletion
                            if let items = log.items, let keeperLog = keeper {
                                if keeperLog.items == nil {
                                    keeperLog.items = []
                                }
                                for item in items {
                                    keeperLog.items?.append(item)
                                }
                            }
                            context.delete(log)
                        }
                    }
                }
            }
            
            try context.save()
        } catch {
            print("ERROR: cleanupDuplicateDayLogs failed: \(error)")
        }
    }
    
    static func cleanupDuplicateExerciseTypes(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<ExerciseType>())
            let grouped = Dictionary(grouping: all) { $0.name.lowercased() }
            
            for (_, types) in grouped {
                if types.count > 1 {
                    // Keep the one with the most recent createdAt
                    let keeper = types.max { $0.createdAt < $1.createdAt }
                    
                    for type in types {
                        if type !== keeper {
                            // Reassign any ExerciseItems pointing at the duplicate
                            if let items = type.exerciseItems, let keepRef = keeper {
                                for item in items {
                                    item.exercise = keepRef
                                }
                            }
                            context.delete(type)
                        }
                    }
                }
            }
            
            try context.save()
        } catch {
            print("ERROR: cleanupDuplicateExerciseTypes failed: \(error)")
        }
    }
    
    static func cleanupDuplicateUnitTypes(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<UnitType>())
            let grouped = Dictionary(grouping: all) { $0.name.lowercased() }
            
            for (_, types) in grouped {
                if types.count > 1 {
                    // Keep the one with the most recent createdAt
                    let keeper = types.max { $0.createdAt < $1.createdAt }
                    
                    for type in types {
                        if type !== keeper {
                            // Reassign ExerciseItems and ExerciseTypes defaults
                            if let items = type.exerciseItems, let keepRef = keeper {
                                for item in items { item.unit = keepRef }
                            }
                            if let defaults = type.exerciseTypesUsingAsDefault, let keepRef = keeper {
                                for ex in defaults { ex.defaultUnit = keepRef }
                            }
                            context.delete(type)
                        }
                    }
                }
            }
            
            try context.save()
        } catch {
            print("ERROR: cleanupDuplicateUnitTypes failed: \(error)")
        }
    }

    static func cleanupDuplicateExerciseItems(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<ExerciseItem>())
            // Group only HealthKit-imported items by normalized UUID
            func normalizeUUID(_ s: String) -> String {
                let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return lower.replacingOccurrences(of: "[^a-f0-9]", with: "", options: .regularExpression)
            }
            let hkItems = all.compactMap { item -> (key: String, item: ExerciseItem)? in
                guard let u = item.healthKitWorkoutUUID, !u.isEmpty else { return nil }
                return (normalizeUUID(u), item)
            }
            let grouped = Dictionary(grouping: hkItems, by: { $0.key })

            func isDistanceUnit(_ unit: UnitType?) -> Bool {
                guard let unit else { return false }
                let n = unit.name.lowercased()
                let a = unit.abbreviation.lowercased()
                return n.contains("mile") || n.contains("kilomet") || a == "mi" || a == "km"
            }
            func isTimeUnit(_ unit: UnitType?) -> Bool {
                guard let unit else { return false }
                let n = unit.name.lowercased()
                let a = unit.abbreviation.lowercased()
                return n.contains("minute") || a == "min"
            }
            func tieBreakScore(_ item: ExerciseItem) -> Double {
                // Prefer non-zero amount and presence of note slightly; then recency
                var s = 0.0
                if item.amount > 0 { s += 0.25 }
                if !(item.note ?? "").isEmpty { s += 0.1 }
                s += item.modifiedAt.timeIntervalSince1970 / 1e12 // tiny scaling to keep deterministic
                return s
            }

            for (_, pairs) in grouped where pairs.count > 1 {
                var candidates = pairs.map { $0.item }

                // Step 1: Prefer the item that already existed (older modifiedAt) if timestamps clearly differ
                if let oldest = candidates.min(by: { $0.modifiedAt < $1.modifiedAt }) {
                    let oldestTime = oldest.modifiedAt
                    let clearlyDifferent = candidates.contains { abs($0.modifiedAt.timeIntervalSince(oldestTime)) > 30 }
                    if clearlyDifferent {
                        let keeper = oldest
                        for item in candidates where item !== keeper {
                            if let day = item.dayLog {
                                let id = item.persistentModelID
                                day.items = day.unwrappedItems.filter { $0.persistentModelID != id }
                            }
                            context.delete(item)
                        }
                        continue
                    }
                }

                // Step 2: Ambiguous timing — prefer units matching current user preference
                let pref = HealthKitService.shared.importUnitPreference
                func matchesPreference(_ item: ExerciseItem) -> Bool {
                    switch pref {
                    case .distance:
                        return isDistanceUnit(item.unit)
                    case .time:
                        return isTimeUnit(item.unit)
                    case .auto:
                        if let def = item.exercise?.defaultUnit {
                            if isDistanceUnit(def) { return isDistanceUnit(item.unit) }
                            if isTimeUnit(def) { return isTimeUnit(item.unit) }
                        }
                        return false
                    }
                }
                let prefPool = candidates.filter { matchesPreference($0) }
                if !prefPool.isEmpty { candidates = prefPool }

                // Step 3: If still ambiguous, prefer distance over time (last resort)
                let distancePool = candidates.filter { isDistanceUnit($0.unit) }
                if !distancePool.isEmpty { candidates = distancePool }

                // Step 4: Final tie-breaks
                let keeper = candidates.max { a, b in tieBreakScore(a) < tieBreakScore(b) }
                for item in candidates {
                    guard item !== keeper else { continue }
                    // Remove from owning day to keep UI consistent
                    if let day = item.dayLog {
                        let id = item.persistentModelID
                        day.items = day.unwrappedItems.filter { $0.persistentModelID != id }
                    }
                    context.delete(item)
                }
            }
            try context.save()
        } catch {
            print("ERROR: cleanupDuplicateExerciseItems failed: \(error)")
        }
    }

    static func enforceUnitAmountInvariant(context: ModelContext) {
        // Ensure no ExerciseItem has a non-zero amount while lacking a unit
        do {
            let all = try context.fetch(FetchDescriptor<ExerciseItem>())
            let allUnits = try context.fetch(FetchDescriptor<UnitType>())
            var changed = false
            for item in all where item.amount != 0 && item.unit == nil {
                if let ex = item.exercise {
                    // Prefer the exercise's default unit if present
                    if let def = ex.defaultUnit {
                        item.unit = def
                        changed = true
                        continue
                    }
                    // Otherwise try to infer the best matching unit from existing units
                    if let inferred = findBestMatchingUnit(for: ex, from: allUnits) {
                        item.unit = inferred
                        changed = true
                        continue
                    }
                }
                // Last resort: keep it as intensity-only and zero the amount
                item.amount = 0
                changed = true
            }
            if changed { try context.save() }
        } catch {
            print("ERROR: enforceUnitAmountInvariant failed: \(error)")
        }
    }
}

// MARK: - Data Transfer (Export/Import)

// DTOs
struct UnitTypeDTO: Codable, Equatable {
    var name: String
    var abbreviation: String
    var stepSize: Double
    var displayAsInteger: Bool
    var createdAt: Date?
}

struct ExerciseTypeDTO: Codable, Equatable {
    var name: String
    var baseMET: Double
    var repWeight: Double
    var defaultPaceMinPerMi: Double
    var iconSystemName: String?
    var defaultUnitName: String?
    var createdAt: Date?
}

struct ExerciseItemDTO: Codable, Equatable {
    var logicalID: String?
    var exerciseName: String
    var unitName: String?
    var amount: Double
    var note: String?
    var enjoyment: Int
    var intensity: Int
    var createdAt: Date
    var modifiedAt: Date
    var healthKitWorkoutUUID: String?
}

struct DayLogDTO: Codable, Equatable {
    var date: Date
    var notes: String?
    var items: [ExerciseItemDTO]
}

struct ExportBundleDTO: Codable, Equatable {
    var version: Int
    var exportedAt: Date
    var units: [UnitTypeDTO]
    var exercises: [ExerciseTypeDTO]
    var days: [DayLogDTO]
}

@MainActor
enum DataExportService {
    static func exportAll(modelContext: ModelContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let days = try modelContext.fetch(FetchDescriptor<DayLog>())
        var unitSet = Set<String>()
        var exerciseSet = Set<String>()

        let sortedDays = days.sorted { $0.date < $1.date }
        let dayDTOs: [DayLogDTO] = sortedDays.map { day in
            let items = day.unwrappedItems.sorted { $0.createdAt < $1.createdAt }
            let itemDTOs: [ExerciseItemDTO] = items.map { item in
                if let u = item.unit { unitSet.insert(u.name.lowercased()) }
                if let e = item.exercise { exerciseSet.insert(e.name.lowercased()) }
                return ExerciseItemDTO(
                    logicalID: item.logicalID,
                    exerciseName: item.exercise?.name ?? "Unknown",
                    unitName: item.unit?.name,
                    amount: item.amount,
                    note: item.note,
                    enjoyment: item.enjoyment,
                    intensity: item.intensity,
                    createdAt: item.createdAt,
                    modifiedAt: item.modifiedAt,
                    healthKitWorkoutUUID: item.healthKitWorkoutUUID
                )
            }
            return DayLogDTO(date: day.date.startOfDay(), notes: day.notes, items: itemDTOs)
        }

        let allUnits = try modelContext.fetch(FetchDescriptor<UnitType>())
        let units = allUnits
            .filter { unitSet.isEmpty || unitSet.contains($0.name.lowercased()) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
            .map { u in
                UnitTypeDTO(name: u.name, abbreviation: u.abbreviation, stepSize: u.stepSize, displayAsInteger: u.displayAsInteger, createdAt: u.createdAt)
            }

        let allExercises = try modelContext.fetch(FetchDescriptor<ExerciseType>())
        let exercises = allExercises
            .filter { exerciseSet.isEmpty || exerciseSet.contains($0.name.lowercased()) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
            .map { e in
                ExerciseTypeDTO(
                    name: e.name,
                    baseMET: e.baseMET,
                    repWeight: e.repWeight,
                    defaultPaceMinPerMi: e.defaultPaceMinPerMi,
                    iconSystemName: e.iconSystemName,
                    defaultUnitName: e.defaultUnit?.name,
                    createdAt: e.createdAt
                )
            }

        let bundle = ExportBundleDTO(version: 1, exportedAt: Date(), units: units, exercises: exercises, days: dayDTOs)
        return try encoder.encode(bundle)
    }
}

struct ImportSummary {
    var insertedUnits: Int
    var insertedExercises: Int
    var insertedDays: Int
    var insertedItems: Int
}

@MainActor
enum DataImportService {
    struct ImportPlan: Equatable {
        enum NewerSide: Equatable { case local, importFile, equal }
        struct Snapshot: Equatable {
            let id: String?
            let exerciseName: String
            let unitName: String?
            let amount: Double
            let enjoyment: Int
            let intensity: Int
            let createdAt: Date
            let modifiedAt: Date?
        }
        struct Conflict: Equatable {
            let logicalID: String?
            let hkUUID: String?
            let localModifiedAt: Date?
            let importModifiedAt: Date?
            let newer: NewerSide
            let local: Snapshot
            let incoming: Snapshot
            let sameID: Bool
        }
        struct Insert: Equatable {
            let logicalID: String?
            let hkUUID: String?
            let decisionKey: String
            let snapshot: Snapshot
        }
        struct NearDuplicate: Equatable {
            let logicalID: String?
            let localCreatedAt: Date
            let importCreatedAt: Date
            let exerciseName: String
            let unitName: String?
            let amount: Double
            let enjoyment: Int
            let intensity: Int
        }
        struct AlreadyExists: Equatable {
            let snapshot: Snapshot
            let identityMatched: Bool
        }
        var identityConflicts: [Conflict] = []
        var tombstoneConflicts: [Conflict] = []
        var plannedInserts: [Insert] = []
        var nearDuplicates: [NearDuplicate] = []
        var alreadyExists: [AlreadyExists] = []
    }

    static func planImport(from data: Data, modelContext: ModelContext, restoreMode: Bool) throws -> ImportPlan {
        var plan = ImportPlan()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(ExportBundleDTO.self, from: data)

        // Load current items for matching
        let existingItems = try modelContext.fetch(FetchDescriptor<ExerciseItem>())
        let existingByID = Dictionary(grouping: existingItems, by: { $0.logicalID })
        let existingByHK = Dictionary(grouping: existingItems, by: { $0.healthKitWorkoutUUID ?? "" })

        // Load tombstones (IDs for general items; HK tombstones via KVS)
        let kv = NSUbiquitousKeyValueStore.default; kv.synchronize()
        let deletedIDs = Set((kv.array(forKey: "deleted_item_ids_v1") as? [String]) ?? (UserDefaults.standard.array(forKey: "deleted_item_ids_v1") as? [String]) ?? [])
        let deletedHK = Set((kv.array(forKey: "hk_deleted_workouts_v1") as? [String]) ?? (UserDefaults.standard.array(forKey: "hk_deleted_workouts_v1") as? [String]) ?? [])

        for day in bundle.days {
            for dto in day.items {
                func snapshotForLocal(_ item: ExerciseItem) -> ImportPlan.Snapshot {
                    .init(
                        id: item.healthKitWorkoutUUID ?? item.logicalID,
                        exerciseName: item.exercise?.name ?? dto.exerciseName,
                        unitName: item.unit?.name ?? dto.unitName,
                        amount: item.amount,
                        enjoyment: item.enjoyment,
                        intensity: item.intensity,
                        createdAt: item.createdAt,
                        modifiedAt: item.modifiedAt
                    )
                }
                func snapshotForDTO() -> ImportPlan.Snapshot {
                    .init(
                        id: dto.healthKitWorkoutUUID ?? dto.logicalID,
                        exerciseName: dto.exerciseName,
                        unitName: dto.unitName,
                        amount: dto.amount,
                        enjoyment: dto.enjoyment,
                        intensity: dto.intensity,
                        createdAt: dto.createdAt,
                        modifiedAt: dto.modifiedAt
                    )
                }
                func contentEquals(_ a: ImportPlan.Snapshot, _ b: ImportPlan.Snapshot) -> Bool {
                    let sameEx = a.exerciseName.caseInsensitiveCompare(b.exerciseName) == .orderedSame
                    let sameUnit = (a.unitName ?? "").caseInsensitiveCompare(b.unitName ?? "") == .orderedSame
                    let sameAmt = abs(a.amount - b.amount) < 0.0001
                    // Allow for sub-second rounding differences
                    let sameTime = abs(a.createdAt.timeIntervalSince(b.createdAt)) <= 1.0
                    return sameEx && sameUnit && sameAmt && sameTime
                }
                // Identity via HK UUID first
                if let hk = dto.healthKitWorkoutUUID, !hk.isEmpty {
                    let locals = existingByHK[hk] ?? []
                    if let local = locals.max(by: { $0.modifiedAt < $1.modifiedAt }) {
                        // Identity exists locally; compute newer side
                        let l = local.modifiedAt
                        let r = dto.modifiedAt
                        let newer: ImportPlan.NewerSide = (r == l) ? .equal : (r > l ? .importFile : .local)
                        let locSS = snapshotForLocal(local)
                        let inSS = snapshotForDTO()
                        // For identity matches, only consider 'Already Exists' when content AND modifiedAt match
                        if contentEquals(locSS, inSS), r == l {
                            plan.alreadyExists.append(.init(snapshot: inSS, identityMatched: true))
                        } else {
                            plan.identityConflicts.append(.init(logicalID: dto.logicalID, hkUUID: hk, localModifiedAt: l, importModifiedAt: r, newer: newer, local: locSS, incoming: inSS, sameID: true))
                        }
                    } else {
                        if !restoreMode && deletedHK.contains(hk) {
                            let inSS = snapshotForDTO()
                            plan.tombstoneConflicts.append(.init(logicalID: dto.logicalID, hkUUID: hk, localModifiedAt: nil, importModifiedAt: dto.modifiedAt, newer: .importFile, local: inSS, incoming: inSS, sameID: true))
                        } else {
                            let inSS = snapshotForDTO()
                            let key = "hk:\(hk)"
                            plan.plannedInserts.append(.init(logicalID: dto.logicalID, hkUUID: hk, decisionKey: key, snapshot: inSS))
                        }
                    }
                    continue
                }

                // Non-HK identity via logicalID
                if let lid = dto.logicalID, !(lid.isEmpty) {
                    let locals = existingByID[lid] ?? []
                    if let local = locals.max(by: { $0.modifiedAt < $1.modifiedAt }) {
                        let l = local.modifiedAt
                        let r = dto.modifiedAt
                        let newer: ImportPlan.NewerSide = (r == l) ? .equal : (r > l ? .importFile : .local)
                        let locSS = snapshotForLocal(local)
                        let inSS = snapshotForDTO()
                        if contentEquals(locSS, inSS), r == l {
                            plan.alreadyExists.append(.init(snapshot: inSS, identityMatched: true))
                        } else {
                            plan.identityConflicts.append(.init(logicalID: lid, hkUUID: nil, localModifiedAt: l, importModifiedAt: r, newer: newer, local: locSS, incoming: inSS, sameID: true))
                        }
                    } else {
                        if !restoreMode && deletedIDs.contains(lid) {
                            let inSS = snapshotForDTO()
                            plan.tombstoneConflicts.append(.init(logicalID: lid, hkUUID: nil, localModifiedAt: nil, importModifiedAt: dto.modifiedAt, newer: .importFile, local: inSS, incoming: inSS, sameID: true))
                        } else {
                            let inSS = snapshotForDTO()
                            let key = "id:\(lid)"
                            plan.plannedInserts.append(.init(logicalID: lid, hkUUID: nil, decisionKey: key, snapshot: inSS))
                        }
                    }
                } else {
                    // Legacy export without logicalID
                    // Detect exact exists: same content and exact timestamp
                    let exactLocals = existingItems.filter { local in
                        let ls = snapshotForLocal(local)
                        return contentEquals(ls, snapshotForDTO())
                    }
                    if !exactLocals.isEmpty {
                        plan.alreadyExists.append(.init(snapshot: snapshotForDTO(), identityMatched: false))
                        continue
                    }
                    // Detect near duplicate: same exercise/unit/amount/enjoyment/intensity/note and createdAt within 15s
                    let locals = existingItems.filter { local in
                        let sameExercise = (local.exercise?.name ?? "").caseInsensitiveCompare(dto.exerciseName) == .orderedSame
                        let sameUnit = (local.unit?.name ?? "").caseInsensitiveCompare(dto.unitName ?? "") == .orderedSame
                        let sameAmount = abs(local.amount - dto.amount) < 0.0001
                        let sameEnjoy = local.enjoyment == dto.enjoyment
                        let sameIntensity = local.intensity == dto.intensity
                        let sameNote = (local.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == (dto.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let closeInTime = abs(local.createdAt.timeIntervalSince(dto.createdAt)) <= 15
                        return sameExercise && sameUnit && sameAmount && sameEnjoy && sameIntensity && sameNote && closeInTime
                    }
                    if let nd = locals.first {
                        plan.nearDuplicates.append(.init(
                            logicalID: nil,
                            localCreatedAt: nd.createdAt,
                            importCreatedAt: dto.createdAt,
                            exerciseName: dto.exerciseName,
                            unitName: dto.unitName,
                            amount: dto.amount,
                            enjoyment: dto.enjoyment,
                            intensity: dto.intensity
                        ))
                    } else {
                        let inSS = snapshotForDTO()
                        let key = "legacy:" + [
                            inSS.exerciseName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                            (inSS.unitName ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                            String(format: "%.3f", inSS.amount),
                            String(inSS.enjoyment),
                            String(inSS.intensity),
                            String(Int(inSS.createdAt.timeIntervalSince1970))
                        ].joined(separator: "|")
                        plan.plannedInserts.append(.init(logicalID: nil, hkUUID: nil, decisionKey: key, snapshot: inSS))
                    }
                }
            }
        }
        return plan
    }

    struct ImportDecisions {
        // Keys are "id:<logicalID>" for non-HK and "hk:<uuid>" for HK
        var keepImport: Set<String> = []     // for identity conflicts: choose Import side
        var restoreKeys: Set<String> = []    // for tombstoned: allow restore and clear tombstone
        // For legacy items (no identity), allow explicit insertion when planner flagged as near-duplicate
        var insertLegacyKeys: Set<String> = [] // keys like "legacy:<hash>"
        // For planned inserts (identity or legacy), allow explicit skip
        var skipInsertKeys: Set<String> = []
    }

    private static func keyFor(dto: ExerciseItemDTO) -> String? {
        if let hk = dto.healthKitWorkoutUUID, !hk.isEmpty { return "hk:\(hk)" }
        if let lid = dto.logicalID, !lid.isEmpty { return "id:\(lid)" }
        return nil
    }

    private static func removeFromTombstones(key: String) {
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        if key.hasPrefix("id:") {
            let id = String(key.dropFirst(3))
            var ids = (kv.array(forKey: "deleted_item_ids_v1") as? [String]) ?? (UserDefaults.standard.array(forKey: "deleted_item_ids_v1") as? [String]) ?? []
            ids.removeAll { $0 == id }
            UserDefaults.standard.set(ids, forKey: "deleted_item_ids_v1")
            kv.set(ids, forKey: "deleted_item_ids_v1")
            kv.synchronize()
        } else if key.hasPrefix("hk:") {
            let hk = String(key.dropFirst(3))
            var arr = (kv.array(forKey: "hk_deleted_workouts_v1") as? [String]) ?? []
            arr.removeAll { $0 == hk }
            kv.set(arr, forKey: "hk_deleted_workouts_v1")
            kv.synchronize()
        }
    }

    private static func legacyKey(for dto: ExerciseItemDTO) -> String {
        func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let parts: [String] = [
            norm(dto.exerciseName),
            norm(dto.unitName),
            String(format: "%.3f", dto.amount),
            String(dto.enjoyment),
            String(dto.intensity),
            String(Int(dto.createdAt.timeIntervalSince1970))
        ]
        return "legacy:" + parts.joined(separator: "|")
    }

    // Public helper for tests/UI to compute the decision key for legacy (non-identity) items
    static func decisionKeyForLegacy(exerciseName: String, unitName: String?, amount: Double, enjoyment: Int, intensity: Int, createdAt: Date) -> String {
        func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let parts: [String] = [
            norm(exerciseName),
            norm(unitName),
            String(format: "%.3f", amount),
            String(enjoyment),
            String(intensity),
            String(Int(createdAt.timeIntervalSince1970))
        ]
        return "legacy:" + parts.joined(separator: "|")
    }

    static func applyImport(from data: Data, modelContext: ModelContext, restoreMode: Bool, decisions: ImportDecisions) throws {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let bundle = try decoder.decode(ExportBundleDTO.self, from: data)

        let existingItems = try modelContext.fetch(FetchDescriptor<ExerciseItem>())
        func findExercise(_ name: String) -> ExerciseType? {
            let all = try? modelContext.fetch(FetchDescriptor<ExerciseType>())
            return all?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        func findUnit(_ name: String?) -> UnitType? {
            guard let n = name else { return nil }
            let all = try? modelContext.fetch(FetchDescriptor<UnitType>())
            return all?.first { $0.name.caseInsensitiveCompare(n) == .orderedSame }
        }

        // Build quick lookups by identity
        func byLogicalID(_ id: String) -> ExerciseItem? { existingItems.first { $0.logicalID == id } }
        func byHK(_ hk: String) -> ExerciseItem? { existingItems.first { $0.healthKitWorkoutUUID == hk } }

        for dayDTO in bundle.days {
            // ensure day exists
            let day: DayLog = {
                let all = (try? modelContext.fetch(FetchDescriptor<DayLog>())) ?? []
                if let found = all.first(where: { Calendar.current.isDate($0.date, inSameDayAs: dayDTO.date.startOfDay()) }) { return found }
                let d = DayLog(date: dayDTO.date.startOfDay()); modelContext.insert(d); return d
            }()

            for dto in dayDTO.items {
                let key = keyFor(dto: dto)

                if let hk = dto.healthKitWorkoutUUID, !hk.isEmpty {
                    if let local = byHK(hk) {
                        // Identity conflict: update only if chosen to keep import
                        if let k = key, decisions.keepImport.contains(k) {
                            if let ex = findExercise(dto.exerciseName) {
                                local.exercise = ex
                                local.unit = findUnit(dto.unitName) ?? local.unit ?? ex.defaultUnit
                                local.amount = dto.amount
                                local.note = dto.note
                                local.enjoyment = dto.enjoyment
                                local.intensity = dto.intensity
                                local.createdAt = dto.createdAt
                                local.modifiedAt = dto.modifiedAt
                                local.dayLog = day
                            }
                        }
                    } else {
                        // Not present locally; insert if restore or not tombstoned, or explicitly chosen restore
                        let tombstonedHK = Set((NSUbiquitousKeyValueStore.default.array(forKey: "hk_deleted_workouts_v1") as? [String]) ?? [])
                        let allowed = restoreMode || (key != nil && decisions.restoreKeys.contains(key!)) || !tombstonedHK.contains(hk)
                        if allowed, let ex = findExercise(dto.exerciseName) {
                            if let k = key, decisions.skipInsertKeys.contains(k) { continue }
                            let unitCandidate = findUnit(dto.unitName) ?? ex.defaultUnit ?? ((try? modelContext.fetch(FetchDescriptor<UnitType>()))?.first)
                            guard let resolvedUnit = unitCandidate else { continue }
                            let item = ExerciseItem(exercise: ex, unit: resolvedUnit, amount: dto.amount, note: dto.note, enjoyment: dto.enjoyment, intensity: dto.intensity, at: dto.createdAt)
                            item.modifiedAt = dto.modifiedAt
                            item.healthKitWorkoutUUID = hk
                            item.dayLog = day
                            modelContext.insert(item)
                            if let k = key { removeFromTombstones(key: k) }
                        }
                    }
                    continue
                }

                if let lid = dto.logicalID, !lid.isEmpty {
                    if let local = byLogicalID(lid) {
                        if let k = key, decisions.keepImport.contains(k) {
                            if let ex = findExercise(dto.exerciseName) {
                                local.exercise = ex
                                local.unit = findUnit(dto.unitName) ?? local.unit ?? ex.defaultUnit
                                local.amount = dto.amount
                                local.note = dto.note
                                local.enjoyment = dto.enjoyment
                                local.intensity = dto.intensity
                                local.createdAt = dto.createdAt
                                local.modifiedAt = dto.modifiedAt
                                local.dayLog = day
                            }
                        }
                    } else {
                        // Insert if not tombstoned, or restore allowed
                        let ids = Set((NSUbiquitousKeyValueStore.default.array(forKey: "deleted_item_ids_v1") as? [String]) ?? (UserDefaults.standard.array(forKey: "deleted_item_ids_v1") as? [String]) ?? [])
                        let allowed = restoreMode || (key != nil && decisions.restoreKeys.contains(key!)) || !ids.contains(lid)
                        if allowed, let ex = findExercise(dto.exerciseName) {
                            if let k = key, decisions.skipInsertKeys.contains(k) { continue }
                            let unitCandidate = findUnit(dto.unitName) ?? ex.defaultUnit ?? ((try? modelContext.fetch(FetchDescriptor<UnitType>()))?.first)
                            guard let resolvedUnit = unitCandidate else { continue }
                            let item = ExerciseItem(exercise: ex, unit: resolvedUnit, amount: dto.amount, note: dto.note, enjoyment: dto.enjoyment, intensity: dto.intensity, at: dto.createdAt)
                            item.modifiedAt = dto.modifiedAt
                            item.logicalID = lid
                            item.dayLog = day
                            modelContext.insert(item)
                            if let k = key { removeFromTombstones(key: k) }
                        }
                    }
                } else {
                    // Legacy insert (no identity): if it's a near duplicate of an existing local item within 15s, skip unless explicitly allowed
                    let isNearDup = existingItems.contains { local in
                        let sameExercise = (local.exercise?.name ?? "").caseInsensitiveCompare(dto.exerciseName) == .orderedSame
                        let sameUnit = (local.unit?.name ?? "").caseInsensitiveCompare(dto.unitName ?? "") == .orderedSame
                        let sameAmount = abs(local.amount - dto.amount) < 0.0001
                        let sameEnjoy = local.enjoyment == dto.enjoyment
                        let sameIntensity = local.intensity == dto.intensity
                        let sameNote = (local.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == (dto.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let closeInTime = abs(local.createdAt.timeIntervalSince(dto.createdAt)) <= 15
                        return sameExercise && sameUnit && sameAmount && sameEnjoy && sameIntensity && sameNote && closeInTime
                    }
                    let allow = decisions.insertLegacyKeys.contains(legacyKey(for: dto)) || !isNearDup
                    if allow, let ex = findExercise(dto.exerciseName) {
                        let k = legacyKey(for: dto)
                        if decisions.skipInsertKeys.contains(k) { continue }
                        let unitCandidate = findUnit(dto.unitName) ?? ex.defaultUnit ?? ((try? modelContext.fetch(FetchDescriptor<UnitType>()))?.first)
                        guard let resolvedUnit = unitCandidate else { continue }
                        let item = ExerciseItem(exercise: ex, unit: resolvedUnit, amount: dto.amount, note: dto.note, enjoyment: dto.enjoyment, intensity: dto.intensity, at: dto.createdAt)
                        item.modifiedAt = dto.modifiedAt
                        item.dayLog = day
                        modelContext.insert(item)
                    }
                }
            }
        }
        try modelContext.save()
    }
    private static func loadDeletedItemSets() -> (ids: Set<String>, hashes: Set<String>) {
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        let idArr = (kv.array(forKey: "deleted_item_ids_v1") as? [String]) ?? (UserDefaults.standard.array(forKey: "deleted_item_ids_v1") as? [String]) ?? []
        let hashArr = (kv.array(forKey: "deleted_item_hashes_v1") as? [String]) ?? (UserDefaults.standard.array(forKey: "deleted_item_hashes_v1") as? [String]) ?? []
        return (Set(idArr), Set(hashArr))
    }

    private static func dtoContentHash(_ dto: ExerciseItemDTO) -> String {
        func norm(_ s: String?) -> String { (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let parts: [String] = [
            norm(dto.exerciseName),
            norm(dto.unitName),
            String(format: "%.3f", dto.amount),
            String(dto.enjoyment),
            String(dto.intensity),
            String(Int(dto.createdAt.timeIntervalSince1970))
        ]
        return parts.joined(separator: "|")
    }
    private static func cleanJSONData(_ data: Data) -> Data {
        // Strip UTF-8 BOM if present to avoid JSONDecoder failures
        if data.count >= 3 && data.prefix(3) == Data([0xEF, 0xBB, 0xBF]) { return data.dropFirst(3) }
        return data
    }

    static func importFromJSON(_ data: Data, modelContext: ModelContext) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let clean = cleanJSONData(data)

        if clean.isEmpty {
            throw NSError(domain: "BellowsImport", code: 104, userInfo: [NSLocalizedDescriptionKey: "Selected file is empty."])
        }

        let bundle: ExportBundleDTO
        do {
            bundle = try decoder.decode(ExportBundleDTO.self, from: clean)
        } catch {
            // Try to provide a more helpful error by peeking at top-level structure
            if let obj = try? JSONSerialization.jsonObject(with: clean, options: []) as? [String: Any] {
                var missing: [String] = []
                for k in ["version","exportedAt","units","exercises","days"] where obj[k] == nil { missing.append(k) }
                if !missing.isEmpty {
                    throw NSError(
                        domain: "BellowsImport",
                        code: 102,
                        userInfo: [NSLocalizedDescriptionKey: "This file does not appear to be a Bellows export (missing keys: \(missing.joined(separator: ", ")))."]
                    )
                }
            } else if let _ = try? JSONSerialization.jsonObject(with: clean, options: []) as? [Any] {
                throw NSError(
                    domain: "BellowsImport",
                    code: 103,
                    userInfo: [NSLocalizedDescriptionKey: "This file’s JSON is an array, but a Bellows export should be an object."]
                )
            }
            // Fall back to the original decoding error description
            throw NSError(domain: "BellowsImport", code: 101, userInfo: [NSLocalizedDescriptionKey: "Invalid or unsupported Bellows export (\(error.localizedDescription))."])
        }
        guard bundle.version == 1 else { throw NSError(domain: "BellowsImport", code: 100, userInfo: [NSLocalizedDescriptionKey: "Unsupported export version \(bundle.version)"]) }

        var existingUnits = try modelContext.fetch(FetchDescriptor<UnitType>())
        var existingExercises = try modelContext.fetch(FetchDescriptor<ExerciseType>())
        var existingDays = try modelContext.fetch(FetchDescriptor<DayLog>())

        var insertedUnits = 0
        var insertedExercises = 0
        var insertedDays = 0
        var insertedItems = 0

        for u in bundle.units {
            if let found = existingUnits.first(where: { $0.name.caseInsensitiveCompare(u.name) == .orderedSame }) {
                if found.abbreviation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    found.abbreviation = u.abbreviation
                }
                continue
            }
            let nu = UnitType(name: u.name, abbreviation: u.abbreviation, stepSize: u.stepSize, displayAsInteger: u.displayAsInteger)
            modelContext.insert(nu)
            existingUnits.append(nu)
            insertedUnits += 1
        }

        for e in bundle.exercises {
            if let found = existingExercises.first(where: { $0.name.caseInsensitiveCompare(e.name) == .orderedSame }) {
                if found.defaultUnit == nil, let duName = e.defaultUnitName,
                   let resolved = existingUnits.first(where: { $0.name.caseInsensitiveCompare(duName) == .orderedSame }) {
                    found.defaultUnit = resolved
                }
                continue
            }
            let defaultUnit = e.defaultUnitName.flatMap { name in existingUnits.first { $0.name.caseInsensitiveCompare(name) == .orderedSame } }
            let ne = ExerciseType(
                name: e.name,
                baseMET: e.baseMET,
                repWeight: e.repWeight,
                defaultPaceMinPerMi: e.defaultPaceMinPerMi,
                iconSystemName: e.iconSystemName,
                defaultUnit: defaultUnit
            )
            modelContext.insert(ne)
            existingExercises.append(ne)
            insertedExercises += 1
        }

        func findUnit(_ name: String?) -> UnitType? {
            guard let name else { return nil }
            return existingUnits.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        func findExercise(_ name: String) -> ExerciseType? {
            return existingExercises.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        }
        func findOrCreateDay(_ date: Date) -> DayLog {
            if let found = existingDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date.startOfDay()) }) {
                return found
            }
            let d = DayLog(date: date.startOfDay())
            modelContext.insert(d)
            existingDays.append(d)
            insertedDays += 1
            return d
        }

        let existingItems = try modelContext.fetch(FetchDescriptor<ExerciseItem>())

        func normalizeUUID(_ s: String) -> String {
            let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return lower.replacingOccurrences(of: "[^a-f0-9]", with: "", options: .regularExpression)
        }

        func isDuplicate(day: DayLog, dto: ExerciseItemDTO) -> Bool {
            if let hk = dto.healthKitWorkoutUUID, !hk.isEmpty {
                let normHK = normalizeUUID(hk)
                if existingItems.contains(where: { normalizeUUID($0.healthKitWorkoutUUID ?? "") == normHK }) { return true }
                if day.unwrappedItems.contains(where: { normalizeUUID($0.healthKitWorkoutUUID ?? "") == normHK }) { return true }
            }
            let ex = findExercise(dto.exerciseName)
            let un = findUnit(dto.unitName)
            let trimmedNote = (dto.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let epsilon = 0.0001
            // Strict match (same exercise, unit, amount, enjoyment, intensity, note) AND createdAt very close (<= 15s)
            if day.unwrappedItems.contains(where: { item in
                let notesEqual = (item.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == trimmedNote
                let sameUnit: Bool = (item.unit == nil && un == nil) || (item.unit?.name.caseInsensitiveCompare(un?.name ?? "") == .orderedSame)
                let closeInTime = abs(item.createdAt.timeIntervalSince(dto.createdAt)) <= 15 // seconds
                return item.exercise?.name.caseInsensitiveCompare(ex?.name ?? "") == .orderedSame
                && sameUnit
                && abs(item.amount - dto.amount) < epsilon
                && item.enjoyment == dto.enjoyment
                && item.intensity == dto.intensity
                && notesEqual
                && closeInTime
            }) { return true }

            // Fallback: Time-based dedup for HealthKit-imported items
            // If the day already has an item imported from HealthKit for the same exercise
            // within a short window of the DTO's timestamp, consider it a duplicate even if units differ.
            let timeWindow: TimeInterval = 10 * 60
            func normalize(_ s: String) -> String {
                var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                t = t.replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
                if t.hasSuffix("s") { t.removeLast() }
                return t
            }
            let exerciseName = ex?.name ?? dto.exerciseName
            let normTarget = normalize(exerciseName)
            let hasHKNearBy = day.unwrappedItems.contains { item in
                let isHKImported = (item.healthKitWorkoutUUID != nil) || ((item.note ?? "").localizedCaseInsensitiveContains("Imported from Apple Health"))
                guard isHKImported else { return false }
                let sameExercise: Bool = {
                    let lhs = normalize(item.exercise?.name ?? "")
                    return lhs == normTarget || lhs.contains(normTarget) || normTarget.contains(lhs)
                }()
                let closeInTime = abs(item.createdAt.timeIntervalSince(dto.createdAt)) <= timeWindow
                return sameExercise && closeInTime
            }
            if hasHKNearBy { return true }

            // Global fallback across all logs: an HK-imported item for same exercise within time window exists elsewhere
            let hasHKGlobalNearBy = existingItems.contains { item in
                let isHKImported = (item.healthKitWorkoutUUID != nil) || ((item.note ?? "").localizedCaseInsensitiveContains("Imported from Apple Health"))
                guard isHKImported else { return false }
                let lhs = normalize(item.exercise?.name ?? "")
                let sameExercise = lhs == normTarget || lhs.contains(normTarget) || normTarget.contains(lhs)
                let closeInTime = abs(item.createdAt.timeIntervalSince(dto.createdAt)) <= timeWindow
                return sameExercise && closeInTime
            }
            if hasHKGlobalNearBy { return true }

            return false
        }

        let tombstones = loadDeletedItemSets()

        for dayDTO in bundle.days {
            let day = findOrCreateDay(dayDTO.date)
            if (day.notes?.isEmpty ?? true), let n = dayDTO.notes, !n.isEmpty { day.notes = n }

            for itemDTO in dayDTO.items {
                // Global tombstone check by logicalID or content hash
                if let lid = itemDTO.logicalID, tombstones.ids.contains(lid) { continue }
                if tombstones.hashes.contains(dtoContentHash(itemDTO)) { continue }
                // If this record references a HealthKit workout UUID that already exists anywhere,
                // move the existing item into this day (repair) and skip creating a duplicate.
                if let hk = itemDTO.healthKitWorkoutUUID, !hk.isEmpty {
                    let normHK = normalizeUUID(hk)
                    // Skip importing if this HK UUID has been explicitly deleted/hidden by user on any device
                    let kv = NSUbiquitousKeyValueStore.default
                    let deleted = (kv.array(forKey: "hk_deleted_workouts_v1") as? [String]) ?? []
                    if deleted.contains(hk) || deleted.contains(normHK) {
                        continue
                    }
                    if let existingItem = existingItems.first(where: { normalizeUUID($0.healthKitWorkoutUUID ?? "") == normHK }) {
                        if existingItem.dayLog !== day {
                            // Remove from old day list to keep UI consistent
                            if let oldDay = existingItem.dayLog {
                                let id = existingItem.persistentModelID
                                oldDay.items = oldDay.unwrappedItems.filter { $0.persistentModelID != id }
                            }
                            // Append to target day if not already present
                            if day.items == nil { day.items = [] }
                            let existsInTarget = day.items?.contains(where: { $0.persistentModelID == existingItem.persistentModelID }) ?? false
                            if !existsInTarget { day.items?.append(existingItem) }
                            existingItem.dayLog = day
                        }
                        // Already have this HK workout; skip creating a new one
                        continue
                    }
                    // If the same HK UUID is already in this day, skip
                    if day.unwrappedItems.contains(where: { normalizeUUID($0.healthKitWorkoutUUID ?? "") == normHK }) { continue }
                }
                guard let ex = findExercise(itemDTO.exerciseName) else { continue }
                let un = findUnit(itemDTO.unitName)
                if isDuplicate(day: day, dto: itemDTO) { continue }
                let newItem: ExerciseItem
                if let resolvedUnit = (un ?? ex.defaultUnit) {
                    newItem = ExerciseItem(
                        exercise: ex,
                        unit: resolvedUnit,
                        amount: itemDTO.amount,
                        note: itemDTO.note,
                        enjoyment: itemDTO.enjoyment,
                        intensity: itemDTO.intensity,
                        at: itemDTO.createdAt
                    )
                } else {
                    // No explicit unit in export and exercise has no default; try to infer a best matching unit.
                    if let inferredUnit = findBestMatchingUnit(for: ex, from: existingUnits) {
                        newItem = ExerciseItem(
                            exercise: ex,
                            unit: inferredUnit,
                            amount: itemDTO.amount,
                            note: itemDTO.note,
                            enjoyment: itemDTO.enjoyment,
                            intensity: itemDTO.intensity,
                            at: itemDTO.createdAt
                        )
                    } else {
                        // Fall back to intensity-only item; ensure amount is zero to keep invariants
                        newItem = ExerciseItem(
                            exercise: ex,
                            note: itemDTO.note,
                            enjoyment: itemDTO.enjoyment,
                            intensity: itemDTO.intensity,
                            at: itemDTO.createdAt
                        )
                        newItem.amount = 0
                    }
                }
                // Preserve logical identity if present
                if let lid = itemDTO.logicalID, !lid.isEmpty { newItem.logicalID = lid }
                newItem.modifiedAt = itemDTO.modifiedAt
                newItem.healthKitWorkoutUUID = itemDTO.healthKitWorkoutUUID
                newItem.dayLog = day
                if day.items == nil { day.items = [] }
                day.items?.append(newItem)
                modelContext.insert(newItem)
                insertedItems += 1
            }
        }

        try modelContext.save()

        // Ensure no duplicate HK items crept in (e.g., via CloudKit merges)
        DedupService.cleanupDuplicateExerciseItems(context: modelContext)
        DedupService.cleanupDuplicateUnitTypes(context: modelContext)
        DedupService.cleanupDuplicateExerciseTypes(context: modelContext)
        DedupService.cleanupDuplicateDayLogs(context: modelContext)
        DedupService.enforceUnitAmountInvariant(context: modelContext)
        DedupService.enforceDeletedItemTombstones(context: modelContext)

        return ImportSummary(insertedUnits: insertedUnits, insertedExercises: insertedExercises, insertedDays: insertedDays, insertedItems: insertedItems)
    }
}
