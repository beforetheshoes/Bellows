import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ImportReviewViewModel: Identifiable, Hashable {
    let id = UUID()
    let modelContext: ModelContext
    let rawData: Data
    var restoreMode: Bool = false

    private(set) var plan: DataImportService.ImportPlan = .init()

    // User decisions
    private(set) var keepImportKeys: Set<String> = []      // "id:<lid>" or "hk:<uuid>"
    private(set) var restoreKeys: Set<String> = []         // allow restore specific tombstones
    private(set) var insertLegacyKeys: Set<String> = []    // "legacy:<hash>"
    private(set) var skipInsertKeys: Set<String> = []      // matches Insert.decisionKey
    @ObservationIgnored var lastError: Error?

    init(modelContext: ModelContext, data: Data, restoreMode: Bool = false) {
        self.modelContext = modelContext
        self.rawData = data
        self.restoreMode = restoreMode
    }

    nonisolated static func == (lhs: ImportReviewViewModel, rhs: ImportReviewViewModel) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func loadPlan() throws {
        self.plan = try DataImportService.planImport(from: rawData, modelContext: modelContext, restoreMode: restoreMode)
    }

    // MARK: - Decision helpers
    func keyForConflict(_ c: DataImportService.ImportPlan.Conflict) -> String? {
        if let hk = c.hkUUID { return "hk:\(hk)" }
        if let lid = c.logicalID { return "id:\(lid)" }
        return nil
    }
    func keyForLegacy(exerciseName: String, unitName: String?, amount: Double, enjoyment: Int, intensity: Int, createdAt: Date) -> String {
        let secs = Int(createdAt.timeIntervalSince1970)
        let en = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let un = (unitName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "legacy:\(en)|\(un)|\(String(format: "%.3f", amount))|\(enjoyment)|\(intensity)|\(secs)"
    }

    func chooseKeepImport(for conflict: DataImportService.ImportPlan.Conflict) {
        if let k = keyForConflict(conflict) { keepImportKeys.insert(k) }
    }
    func chooseKeepLocal(for conflict: DataImportService.ImportPlan.Conflict) {
        if let k = keyForConflict(conflict) { keepImportKeys.remove(k) }
    }
    func chooseKeepImportForAll() {
        for c in plan.identityConflicts { if let k = keyForConflict(c) { keepImportKeys.insert(k) } }
    }
    func chooseKeepLocalForAll() {
        for c in plan.identityConflicts { if let k = keyForConflict(c) { keepImportKeys.remove(k) } }
    }
    func clearKeepImportDecisions() { keepImportKeys.removeAll() }
    func chooseRecommendedForAllConflicts() {
        for c in plan.identityConflicts {
            guard let k = keyForConflict(c) else { continue }
            switch c.newer {
            case .importFile:
                keepImportKeys.insert(k)
            case .local, .equal:
                keepImportKeys.remove(k)
            }
        }
    }
    func chooseKeepLocal(byKey key: String) {
        // remove from keepImportKeys for the matching conflict
        keepImportKeys.remove(key)
    }
    func chooseKeepImport(byKey key: String) {
        keepImportKeys.insert(key)
    }
    func allowRestore(for conflict: DataImportService.ImportPlan.Conflict) {
        if let k = keyForConflict(conflict) { restoreKeys.insert(k) }
    }
    func disallowRestore(for conflict: DataImportService.ImportPlan.Conflict) {
        if let k = keyForConflict(conflict) { restoreKeys.remove(k) }
    }
    func allowRestoreForAll() {
        for c in plan.tombstoneConflicts { if let k = keyForConflict(c) { restoreKeys.insert(k) } }
    }
    func clearRestoreDecisions() { restoreKeys.removeAll() }
    func forceInsertLegacy(exerciseName: String, unitName: String?, amount: Double, enjoyment: Int, intensity: Int, createdAt: Date) {
        insertLegacyKeys.insert(keyForLegacy(exerciseName: exerciseName, unitName: unitName, amount: amount, enjoyment: enjoyment, intensity: intensity, createdAt: createdAt))
    }
    func toggleInsertLegacy(exerciseName: String, unitName: String?, amount: Double, enjoyment: Int, intensity: Int, createdAt: Date) {
        let k = keyForLegacy(exerciseName: exerciseName, unitName: unitName, amount: amount, enjoyment: enjoyment, intensity: intensity, createdAt: createdAt)
        if insertLegacyKeys.contains(k) { insertLegacyKeys.remove(k) } else { insertLegacyKeys.insert(k) }
    }
    func forceInsertAllNearDuplicates() {
        for nd in plan.nearDuplicates {
            insertLegacyKeys.insert(keyForLegacy(exerciseName: nd.exerciseName, unitName: nd.unitName, amount: nd.amount, enjoyment: nd.enjoyment, intensity: nd.intensity, createdAt: nd.importCreatedAt))
        }
    }
    func clearLegacyInsertDecisions() { insertLegacyKeys.removeAll() }
    func toggleSkipInsert(key: String) {
        if skipInsertKeys.contains(key) { skipInsertKeys.remove(key) } else { skipInsertKeys.insert(key) }
    }

    // MARK: - Summary
    var conflictCount: Int { plan.identityConflicts.count }
    var tombstoneCount: Int { plan.tombstoneConflicts.count }
    var nearDuplicateCount: Int { plan.nearDuplicates.count }
    var insertCount: Int { plan.plannedInserts.count }
    var alreadyExistsCount: Int { plan.alreadyExists.count }

    struct ApplySummary: Equatable {
        var willUpdate: Int = 0
        var willRestore: Int = 0
        var willInsert: Int = 0
        var willSkip: Int = 0
    }

    func predictedSummary() -> ApplySummary {
        var s = ApplySummary()

        // Identity conflicts: update if keepImport chosen; otherwise skip (keep local)
        for c in plan.identityConflicts {
            let k = keyForConflict(c)
            if k != nil && keepImportKeys.contains(k!) { s.willUpdate += 1 } else { s.willSkip += 1 }
        }

        // Tombstone conflicts: restore if restoreMode or chosen; otherwise skip
        for c in plan.tombstoneConflicts {
            let k = keyForConflict(c)
            if restoreMode || (k != nil && restoreKeys.contains(k!)) { s.willRestore += 1 } else { s.willSkip += 1 }
        }

        // Planned inserts are straightforward
        for ins in plan.plannedInserts {
            if skipInsertKeys.contains(ins.decisionKey) { s.willSkip += 1 } else { s.willInsert += 1 }
        }

        // Near duplicates: insert only if forced
        for nd in plan.nearDuplicates {
            let key = keyForLegacy(exerciseName: nd.exerciseName, unitName: nd.unitName, amount: nd.amount, enjoyment: nd.enjoyment, intensity: nd.intensity, createdAt: nd.importCreatedAt)
            if insertLegacyKeys.contains(key) {
                s.willInsert += 1
            } else {
                s.willSkip += 1
            }
        }
        // Already exists: insert only if forced
        for ex in plan.alreadyExists {
            let key = keyForLegacy(exerciseName: ex.snapshot.exerciseName, unitName: ex.snapshot.unitName, amount: ex.snapshot.amount, enjoyment: ex.snapshot.enjoyment, intensity: ex.snapshot.intensity, createdAt: ex.snapshot.createdAt)
            if insertLegacyKeys.contains(key) {
                s.willInsert += 1
            } else {
                s.willSkip += 1
            }
        }
        return s
    }

    // MARK: - Apply
    func apply() throws {
        let decisions = DataImportService.ImportDecisions(keepImport: keepImportKeys, restoreKeys: restoreKeys, insertLegacyKeys: insertLegacyKeys)
        do {
            try DataImportService.applyImport(from: rawData, modelContext: modelContext, restoreMode: restoreMode, decisions: decisions)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }
}
