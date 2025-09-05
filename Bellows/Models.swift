import Foundation
import SwiftData
import CloudKit
import HealthKit
import Observation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Model
final class DayLog {
    var date: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \ExerciseItem.dayLog) var items: [ExerciseItem]? = []
    var notes: String? = nil
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(date: Date) {
        self.date = date.startOfDay()
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    var unwrappedItems: [ExerciseItem] {
        items ?? []
    }

    var didMove: Bool { !unwrappedItems.isEmpty }

}

enum UnitCategory: String, CaseIterable, Identifiable {
    case time, reps, steps, distance, other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .time: return "Time"
        case .reps: return "Reps"
        case .steps: return "Steps"
        case .distance: return "Distance"
        case .other: return "Other"
        }
    }
}

// Custom Codable conformance to handle migration from old enum values
extension UnitCategory: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        // Handle migration from old enum values
        switch rawValue {
        case "minutes":
            self = .time
        case "distanceMi":
            self = .distance
        case "time", "reps", "steps", "distance", "other":
            self = UnitCategory(rawValue: rawValue) ?? .other
        default:
            self = .other
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

@Model
final class UnitType {
    var name: String = "Unknown"
    var abbreviation: String = ""
    var stepSize: Double = 1.0
    var displayAsInteger: Bool = false
    @Relationship(inverse: \ExerciseItem.unit) var exerciseItems: [ExerciseItem]? = []
    @Relationship(inverse: \ExerciseType.defaultUnit) var exerciseTypesUsingAsDefault: [ExerciseType]? = []
    var createdAt: Date = Date()

    init(name: String, abbreviation: String, stepSize: Double, displayAsInteger: Bool) {
        self.name = name
        self.abbreviation = abbreviation
        self.stepSize = stepSize
        self.displayAsInteger = displayAsInteger
        self.createdAt = Date()
    }
    
    // Migration support: keep category-based init for backward compatibility during transition
    init(name: String, abbreviation: String, category: UnitCategory) {
        self.name = name
        self.abbreviation = abbreviation
        self.createdAt = Date()
        
        // Convert old category to new properties
        switch category {
        case .time:
            self.stepSize = 0.5
            self.displayAsInteger = false
        case .distance:
            self.stepSize = 0.1
            self.displayAsInteger = false
        case .reps, .steps:
            self.stepSize = 1.0
            self.displayAsInteger = true
        case .other:
            self.stepSize = 1.0
            self.displayAsInteger = false
        }
    }
}

@Model
final class ExerciseType {
    var name: String = "Unknown"
    var baseMET: Double = 4.0
    var repWeight: Double = 0.15
    var defaultPaceMinPerMi: Double = 10.0
    @Relationship(inverse: \ExerciseItem.exercise) var exerciseItems: [ExerciseItem]? = []
    var iconSystemName: String?
    var defaultUnit: UnitType?
    var createdAt: Date = Date()
    
    // Migration support: keep category-based init for backward compatibility
    var defaultUnitCategory: UnitCategory?

    init(name: String, baseMET: Double, repWeight: Double, defaultPaceMinPerMi: Double, iconSystemName: String? = nil, defaultUnit: UnitType? = nil) {
        self.name = name
        self.baseMET = baseMET
        self.repWeight = repWeight
        self.defaultPaceMinPerMi = defaultPaceMinPerMi
        self.iconSystemName = iconSystemName
        self.defaultUnit = defaultUnit
        self.defaultUnitCategory = nil  // Explicitly set to nil when using direct unit reference
        self.createdAt = Date()
    }
    
    // Migration support: keep category-based init for backward compatibility during transition
    init(name: String, baseMET: Double, repWeight: Double, defaultPaceMinPerMi: Double, iconSystemName: String? = nil, defaultUnitCategory: UnitCategory? = nil) {
        self.name = name
        self.baseMET = baseMET
        self.repWeight = repWeight
        self.defaultPaceMinPerMi = defaultPaceMinPerMi
        self.iconSystemName = iconSystemName
        self.defaultUnitCategory = defaultUnitCategory
        self.createdAt = Date()
    }
}

@Model
final class ExerciseItem {
    var logicalID: String = UUID().uuidString
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var dayLog: DayLog?
    var exercise: ExerciseType?
    var unit: UnitType?
    var amount: Double = 0.0
    var note: String?
    var enjoyment: Int = 3 // 1..5 per item
    var intensity: Int = 3 // 1..5 per item
    // HealthKit identity for deduplication when imported
    var healthKitWorkoutUUID: String? = nil

    init(exercise: ExerciseType, unit: UnitType, amount: Double, note: String? = nil, enjoyment: Int = 3, intensity: Int = 3, at: Date = .now) {
        self.exercise = exercise
        self.unit = unit
        self.amount = amount
        self.note = note
        self.enjoyment = max(1, min(5, enjoyment))
        self.intensity = max(1, min(5, intensity))
        self.createdAt = at
        self.modifiedAt = Date()
    }

    // Convenience initializer for intensity-only logging (no unit/amount)
    init(exercise: ExerciseType, note: String? = nil, enjoyment: Int = 3, intensity: Int = 3, at: Date = .now) {
        self.exercise = exercise
        self.unit = nil
        self.amount = 0
        self.note = note
        self.enjoyment = max(1, min(5, enjoyment))
        self.intensity = max(1, min(5, intensity))
        self.createdAt = at
        self.modifiedAt = Date()
    }

}

// MARK: - HealthKit Integration Service

// Protocol to abstract HKWorkout for testing
protocol WorkoutProtocol {
    var uuid: UUID { get }
    var workoutActivityType: HKWorkoutActivityType { get }
    var startDate: Date { get }
    var endDate: Date { get }
    var duration: TimeInterval { get }
    var totalDistance: HKQuantity? { get }
    var totalEnergyBurned: HKQuantity? { get }
}

// Extend HKWorkout to conform to our protocol (HKObject already provides uuid)
extension HKWorkout: WorkoutProtocol {}

enum SyncResult {
    case success(workoutCount: Int)
    case error(String)
}

@MainActor
@Observable
class HealthKitService {
    static let shared = HealthKitService()
    private let healthStore = HKHealthStore()
    
    var isAuthorized = false
    var authorizationError: Error?
    var setupState: HealthKitSetupState = .unknown
    var isSyncing = false
    var lastSyncResult: SyncResult?
    var syncEnabled = true { // User preference for auto-sync
        didSet {
            UserDefaults.standard.set(syncEnabled, forKey: "hk_sync_enabled_v1")
            let kv = NSUbiquitousKeyValueStore.default
            kv.set(syncEnabled, forKey: "hk_sync_enabled_v1")
            kv.synchronize()
        }
    }
    var lastSyncDate: Date?
    var debugLogging = false
    var debugLines: [String] = []
    
    // Import preferences
    enum ImportUnitPreference: String, CaseIterable, Identifiable {
        case auto // use exercise default
        case time // minutes
        case distance // miles/km where available

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .auto: return "Auto"
            case .time: return "Time"
            case .distance: return "Distance"
            }
        }
    }
    private let importPreferenceKey = "hk_import_unit_preference_v1"
    var importUnitPreference: ImportUnitPreference = .time {
        didSet {
            UserDefaults.standard.set(importUnitPreference.rawValue, forKey: importPreferenceKey)
            // Mirror to iCloud KVS so other devices stay in sync
            let kv = NSUbiquitousKeyValueStore.default
            kv.set(importUnitPreference.rawValue, forKey: importPreferenceKey)
            kv.synchronize()
        }
    }
    
    // For testing - allows injecting mock workouts instead of querying HealthKit
    var mockWorkouts: [WorkoutProtocol]?

    // Background observer state
    private(set) var isObserving = false
    private var observerQuery: HKObserverQuery?
    private let seenWorkoutsDefaultsKey = "hk_seen_workouts_v1"
    private let deletedWorkoutsDefaultsKey = "hk_deleted_workouts_v1"
    private let lastBackgroundSyncDateKey = "hk_last_background_sync_date"
    private let backgroundToastShownKey = "hk_background_toast_shown_once"
    private var seenWorkoutKeys: Set<String> = []
    private var deletedWorkoutKeys: Set<String> = []
    private var inflightUUIDs: Set<String> = []
    
    // UI signaling
    var backgroundToastMessage: String? = nil
    private weak var observerModelContext: ModelContext?
    
    init() {
        if let d = UserDefaults.standard.object(forKey: lastBackgroundSyncDateKey) as? Date {
            self.lastSyncDate = d
        }
        // Seed from iCloud KVS first if available, else local defaults
        NSUbiquitousKeyValueStore.default.synchronize()
        if let raw = (NSUbiquitousKeyValueStore.default.string(forKey: importPreferenceKey) ?? UserDefaults.standard.string(forKey: importPreferenceKey)),
           let v = ImportUnitPreference(rawValue: raw) {
            self.importUnitPreference = v
        } else {
            // Ensure default is Time for consistent test behavior and backwards compatibility
            self.importUnitPreference = .time
        }
        if NSUbiquitousKeyValueStore.default.object(forKey: "hk_sync_enabled_v1") != nil {
            self.syncEnabled = NSUbiquitousKeyValueStore.default.bool(forKey: "hk_sync_enabled_v1")
        } else if UserDefaults.standard.object(forKey: "hk_sync_enabled_v1") != nil {
            self.syncEnabled = UserDefaults.standard.bool(forKey: "hk_sync_enabled_v1")
        }
        // If running under unit tests, force minutes to keep tests deterministic
        if NSClassFromString("XCTestCase") != nil {
            self.importUnitPreference = .time
        }
        // Observe iCloud KVS changes
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default, queue: .main) { [weak self] note in
            guard let self else { return }
            guard let userInfo = note.userInfo,
                  let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
            Task { @MainActor in
                if keys.contains(self.importPreferenceKey) {
                    if let raw = NSUbiquitousKeyValueStore.default.string(forKey: self.importPreferenceKey),
                       let pref = ImportUnitPreference(rawValue: raw), pref != self.importUnitPreference {
                        self.importUnitPreference = pref
                    }
                }
                if keys.contains("hk_sync_enabled_v1") {
                    let v = NSUbiquitousKeyValueStore.default.bool(forKey: "hk_sync_enabled_v1")
                    if v != self.syncEnabled { self.syncEnabled = v }
                }
                if keys.contains(self.seenWorkoutsDefaultsKey) {
                    // Merge remote seen keys and persist
                    self.loadSeenWorkoutKeys()
                    self.persistSeenWorkoutKeys()
                }
                if keys.contains(self.deletedWorkoutsDefaultsKey) {
                    self.loadDeletedWorkoutKeys()
                    self.persistDeletedWorkoutKeys()
                }
            }
        }
    }

    private func dlog(_ message: String) {
        guard debugLogging else { return }
        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[HKSync] \(ts) - \(message)"
        print(line)
        debugLines.append(line)
        if debugLines.count > 300 { debugLines.removeFirst(debugLines.count - 300) }
    }

    // MARK: - Setup & Authorization
    
    func checkSetupStatus() async {
        setupState = .unknown
        
        let isAvailable = HKHealthStore.isHealthDataAvailable()
        
        // Platform-specific handling
        #if os(macOS)
        // On macOS, HealthKit framework exists but data is never available
        // This is expected behavior, not an error
        if !isAvailable {
            setupState = .unsupported
            return
        }
        #endif
        
        // For iOS/iPadOS/watchOS - check if data is actually available
        guard isAvailable else {
            setupState = .unsupported
            return
        }
        
        // For read permissions, HealthKit doesn't reliably report authorization status
        // for privacy reasons. Instead, we try to query for data to determine access.
        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-86400), // Last 24 hours
            end: Date(),
            options: .strictStartDate
        )
        
        // Try to query for workouts - this will succeed if we have permission
        let hasAccess = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                // If we get results OR get a specific "no data" response (not permission error),
                // then we have access
                if error == nil {
                    continuation.resume(returning: true)
                } else if let hkError = error as? HKError {
                    // Check if it's a permission error
                    switch hkError.code {
                    case .errorAuthorizationDenied, .errorAuthorizationNotDetermined:
                        continuation.resume(returning: false)
                    default:
                        // Other errors (like no data) suggest we do have permission
                        continuation.resume(returning: true)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
            healthStore.execute(query)
        }
        
        if hasAccess {
            setupState = .ready
            isAuthorized = true
        } else {
            setupState = .needsPermission
            isAuthorized = false
        }
    }

    // MARK: - Background Delivery & Observers

    func startBackgroundObserversIfPossible(modelContext: ModelContext) {
        guard syncEnabled else { return }
        guard !isObserving else { return }

        // Load seen keys persisted across runs
        loadSeenWorkoutKeys()

        // Store context for use in observer callbacks without capturing in @Sendable closures
        observerModelContext = modelContext

        // If running with mocks or HealthKit is unavailable, we don't set a real observer.
        // Tests drive background processing via __test_processBackgroundUpdates.
        guard mockWorkouts == nil, HKHealthStore.isHealthDataAvailable() else {
            isObserving = true
            dlog("Observer not started (mocks or HK unavailable). syncEnabled=\(syncEnabled)")
            return
        }

        let workoutType = HKObjectType.workoutType()

        // Enable background delivery for workouts (completion-based API to avoid async requirement)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            Task { @MainActor in
                self.dlog("enableBackgroundDelivery: success=\(success) error=\(String(describing: error))")
            }
        }

        // Observer query: whenever HealthKit notifies of changes, import deltas via anchored query
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else { completionHandler(); return }
            Task { @MainActor in
                if let ctx = self.observerModelContext {
                    _ = await self.processBackgroundUpdates(modelContext: ctx)
                }
                completionHandler()
            }
        }
        healthStore.execute(query)
        observerQuery = query
        isObserving = true
        dlog("Observer started for workoutType")
    }

    func stopBackgroundObservers() {
        if let q = observerQuery { healthStore.stop(q) }
        observerQuery = nil
        isObserving = false
    }

    private func loadSeenWorkoutKeys() {
        // Merge from local defaults and iCloud KVS to build a superset
        var merged: Set<String> = []
        if let arr = UserDefaults.standard.array(forKey: seenWorkoutsDefaultsKey) as? [String] {
            merged.formUnion(arr)
        }
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        if let kvArr = kv.array(forKey: seenWorkoutsDefaultsKey) as? [String] {
            merged.formUnion(kvArr)
        }
        seenWorkoutKeys = merged
        dlog("Loaded seen set count=\(seenWorkoutKeys.count)")
    }

    private func persistSeenWorkoutKeys() {
        // Keep the set reasonably bounded
        if seenWorkoutKeys.count > 5000 {
            seenWorkoutKeys = Set(seenWorkoutKeys.prefix(4000))
        }
        let arr = Array(seenWorkoutKeys)
        UserDefaults.standard.set(arr, forKey: seenWorkoutsDefaultsKey)
        let kv = NSUbiquitousKeyValueStore.default
        kv.set(arr, forKey: seenWorkoutsDefaultsKey)
        kv.synchronize()
        dlog("Persisted seen set count=\(seenWorkoutKeys.count)")
    }

    private func loadDeletedWorkoutKeys() {
        var merged: Set<String> = []
        if let arr = UserDefaults.standard.array(forKey: deletedWorkoutsDefaultsKey) as? [String] {
            merged.formUnion(arr)
        }
        let kv = NSUbiquitousKeyValueStore.default
        kv.synchronize()
        if let kvArr = kv.array(forKey: deletedWorkoutsDefaultsKey) as? [String] {
            merged.formUnion(kvArr)
        }
        deletedWorkoutKeys = merged
        dlog("Loaded deleted set count=\(deletedWorkoutKeys.count)")
    }

    private func persistDeletedWorkoutKeys() {
        if deletedWorkoutKeys.count > 10000 {
            deletedWorkoutKeys = Set(deletedWorkoutKeys.prefix(8000))
        }
        let arr = Array(deletedWorkoutKeys)
        UserDefaults.standard.set(arr, forKey: deletedWorkoutsDefaultsKey)
        let kv = NSUbiquitousKeyValueStore.default
        kv.set(arr, forKey: deletedWorkoutsDefaultsKey)
        kv.synchronize()
        dlog("Persisted deleted set count=\(deletedWorkoutKeys.count)")
    }

    private func removeSeenWorkoutKeys(_ uuids: [String]) {
        if uuids.isEmpty { return }
        for u in uuids { seenWorkoutKeys.remove(u) }
        persistSeenWorkoutKeys()
        dlog("Removed \(uuids.count) UUIDs from seen set")
    }

    private func workoutKey(_ w: WorkoutProtocol) -> String { w.uuid.uuidString }

    // Remove any stale seen UUIDs that no longer exist in the database.
    // Returns true if any entries were purged.
    private func purgeStaleSeenKeysIfNeeded(modelContext: ModelContext) -> Bool {
        if seenWorkoutKeys.isEmpty { return false }
        var removed = false
        do {
            let all = try modelContext.fetch(FetchDescriptor<ExerciseItem>())
            let existing = Set(all.compactMap { $0.healthKitWorkoutUUID })
            let stale = seenWorkoutKeys.subtracting(existing)
            if !stale.isEmpty {
                seenWorkoutKeys.subtract(stale)
                persistSeenWorkoutKeys()
                removed = true
                dlog("Purged stale seen keys count=\(stale.count)")
            }
        } catch {
            // If fetch fails, do nothing
        }
        return removed
    }

    // Test-accessible tick to simulate background update handling with mocks
    @discardableResult
    func __test_processBackgroundUpdates(modelContext: ModelContext) async -> Int {
        return await processBackgroundUpdates(modelContext: modelContext)
    }

    // Core background update handler used by observer and tests
    @discardableResult
    private func processBackgroundUpdates(modelContext: ModelContext) async -> Int {
        guard syncEnabled else { return 0 }
        if isSyncing {
            dlog("Background sync skipped: another sync in progress")
            return 0
        }

        loadSeenWorkoutKeys()
        _ = purgeStaleSeenKeysIfNeeded(modelContext: modelContext)
        loadDeletedWorkoutKeys()

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        let workouts = await fetchWorkouts(from: startDate, to: endDate)
        dlog("Fetched \(workouts.count) workouts between \(startDate) and \(endDate)")
        let newWorkouts = workouts.filter { w in
            let key = workoutKey(w)
            if deletedWorkoutKeys.contains(key) {
                // User explicitly deleted/hidden this import across devices; skip
                return false
            }
            if seenWorkoutKeys.contains(key) {
                // If the UUID is marked seen but no item exists anymore, treat it as new
                let exists = hasImportedWorkout(uuidString: key, modelContext: modelContext)
                if !exists { dlog("Seen-but-missing UUID will re-import: \(key)") }
                return !exists
            }
            return true
        }
        dlog("Considered new workouts: \(newWorkouts.count)")

        if newWorkouts.isEmpty {
            UserDefaults.standard.set(endDate, forKey: lastBackgroundSyncDateKey)
            lastSyncDate = endDate
            return 0
        }

        do {
            // Group by day, import, mark as seen
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: newWorkouts) { calendar.startOfDay(for: $0.startDate) }

            let existingDayLogs = try modelContext.fetch(FetchDescriptor<DayLog>())
            var insertedTotal = 0
            for (day, dayWorkouts) in grouped {
                let dayLog = existingDayLogs.first { calendar.isDate($0.date, inSameDayAs: day) } ?? DayLog(date: day)
                if !existingDayLogs.contains(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
                    modelContext.insert(dayLog)
                }
                let added = importWorkouts(dayWorkouts, to: dayLog, modelContext: modelContext)
                dlog("Imported day \(day): added=\(added) of \(dayWorkouts.count)")
                insertedTotal += added
            }
            try modelContext.save()

            // Persist seen keys only for workouts that now exist in the database
            for w in newWorkouts {
                let key = workoutKey(w)
                let exists = hasImportedWorkout(uuidString: key, modelContext: modelContext)
                if exists { seenWorkoutKeys.insert(key) }
                dlog("Mark seen? uuid=\(key) existsInDB=\(exists)")
            }
            persistSeenWorkoutKeys()

            UserDefaults.standard.set(endDate, forKey: lastBackgroundSyncDateKey)
            lastSyncDate = endDate
            lastSyncResult = .success(workoutCount: insertedTotal)
            dlog("Background sync success, inserted=\(insertedTotal)")

            // One-time toast on first successful background import
            if insertedTotal > 0 && !UserDefaults.standard.bool(forKey: backgroundToastShownKey) {
                backgroundToastMessage = "Imported \(insertedTotal) workout\(insertedTotal == 1 ? "" : "s") from Apple Health"
                UserDefaults.standard.set(true, forKey: backgroundToastShownKey)
            }
            // Collapse any CloudKit-driven duplicates by HealthKit UUID
            DedupService.cleanupDuplicateExerciseItems(context: modelContext)
            DedupService.enforceDeletedItemTombstones(context: modelContext)
            return insertedTotal
        } catch {
            lastSyncResult = .error("Background sync failed: \(error.localizedDescription)")
            dlog("Background sync error: \(error.localizedDescription)")
            return 0
        }
    }
    func requestAuthorization() async {
        await checkSetupStatus()
        
        if case .unsupported = setupState {
            authorizationError = HealthKitError.unavailable
            return
        }
        
        let typesToRead = requiredHealthKitTypes()
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            
            // Re-check setup status after authorization attempt
            await checkSetupStatus()
            
        } catch {
            setupState = .error(error)
            authorizationError = error
        }
    }
    
    
    func requiredHealthKitTypes() -> Set<HKObjectType> {
        return Set([
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!
        ])
    }
    
    // MARK: - Data Mapping
    
    func mapActivityTypeToExerciseName(_ activityType: HKWorkoutActivityType) -> String {
        switch activityType {
        case .walking:
            return "Walk"
        case .running:
            return "Run"
        case .cycling:
            return "Cycling"
        case .yoga:
            return "Yoga"
        case .functionalStrengthTraining:
            return "Other"
        case .traditionalStrengthTraining:
            return "Other"
        case .coreTraining:
            return "Plank"
        default:
            return "Other"
        }
    }
    
    func convertWorkoutToExerciseItems(workout: WorkoutProtocol, modelContext: ModelContext) -> [ExerciseItem] {
        let mappedName = mapActivityTypeToExerciseName(workout.workoutActivityType)

        func normalize(_ s: String) -> String {
            var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            t = t.replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
            if t.hasSuffix("s") { t.removeLast() }
            return t
        }
        let target = normalize(mappedName)

        do {
            // Find best matching exercise type (exact -> normalized equality -> contains -> fallback to Other)
            let allExercises = try modelContext.fetch(FetchDescriptor<ExerciseType>())
            let exerciseType: ExerciseType? = {
                if let exact = allExercises.first(where: { $0.name == mappedName }) { return exact }
                if let normEq = allExercises.first(where: { normalize($0.name) == target }) { return normEq }
                if let contains = allExercises.first(where: { normalize($0.name).contains(target) || target.contains(normalize($0.name)) }) { return contains }
                return allExercises.first(where: { normalize($0.name) == normalize("Other") }) ?? allExercises.first
            }()
            guard let exType = exerciseType else { return [] }

            // Load all units once for matching
            let allUnits = try modelContext.fetch(FetchDescriptor<UnitType>())

            // Decide import unit and amount based on preference and available data
            let unitAndAmount: (UnitType, Double)? = {
                func localePrefersMiles() -> Bool {
                    let locale = Locale.current
                    if let region = locale.region?.identifier {
                        // Countries primarily using miles
                        let mileRegions: Set<String> = ["US", "LR", "MM", "GB"]
                        return mileRegions.contains(region)
                    }
                    return false
                }

                let durationMinutes = workout.duration / 60.0
                let totalMeters = workout.totalDistance?.doubleValue(for: HKUnit.meter())

                switch importUnitPreference {
                case .time:
                    // Force minutes unit when available
                    if let minutesUnit = allUnits.first(where: { $0.name.caseInsensitiveCompare("Minutes") == .orderedSame }) {
                        return (minutesUnit, durationMinutes)
                    }
                    let unit = exType.defaultUnit ?? findBestMatchingUnit(for: exType, from: allUnits) ?? allUnits.first!
                    return (unit, durationMinutes)
                case .distance:
                    if let meters = totalMeters {
                        let useMiles = localePrefersMiles()
                        let targetName = useMiles ? "Miles" : "Kilometers"
                        if let unit = allUnits.first(where: { $0.name.caseInsensitiveCompare(targetName) == .orderedSame }) {
                            let amount = useMiles ? (meters / 1609.344) : (meters / 1000.0)
                            return (unit, amount)
                        }
                    }
                    // Fallback to time if no distance available or unit missing
                    let unit = exType.defaultUnit ?? findBestMatchingUnit(for: exType, from: allUnits) ?? allUnits.first!
                    return (unit, durationMinutes)
                case .auto:
                    // Auto: prefer exercise's default unit; if that looks like distance and we have meters, convert. Otherwise minutes.
                    if let def = exType.defaultUnit {
                        let n = def.name.lowercased()
                        if (n.contains("mile") || n.contains("kilometer") || def.abbreviation.lowercased() == "mi" || def.abbreviation.lowercased() == "km"),
                           let meters = totalMeters {
                            // Map to Miles/Kilometers unit type available in store (by name)
                            let targetName = n.contains("mile") || def.abbreviation.lowercased() == "mi" ? "Miles" : "Kilometers"
                            if let unit = allUnits.first(where: { $0.name.caseInsensitiveCompare(targetName) == .orderedSame }) {
                                let amount = targetName == "Miles" ? (meters / 1609.344) : (meters / 1000.0)
                                return (unit, amount)
                            }
                        }
                        // Otherwise, use default unit with minutes amount
                        return (def, durationMinutes)
                    }
                    let unit = findBestMatchingUnit(for: exType, from: allUnits) ?? allUnits.first!
                    return (unit, durationMinutes)
                }
            }()

            guard let (unit, amount) = unitAndAmount else { return [] }

            // Create exercise item with import metadata
            let item = ExerciseItem(
                exercise: exType,
                unit: unit,
                amount: amount,
                note: "Imported from Apple Health",
                enjoyment: 3,
                intensity: 3,
                at: workout.startDate
            )
            item.healthKitWorkoutUUID = workout.uuid.uuidString
            dlog("Converted workout uuid=\(workout.uuid) type=\(workout.workoutActivityType.rawValue) -> exercise=\(exType.name), unit=\(unit.name), amount=\(amount)")
            return [item]

        } catch {
            print("Error converting workout: \(error)")
            return []
        }
    }
    
    // MARK: - Data Import
    
    @discardableResult
    func importWorkouts(_ workouts: [WorkoutProtocol], to dayLog: DayLog, modelContext: ModelContext) -> Int {
        var inserted = 0
        var localInflight: [String] = []
        var changed = false
        for workout in workouts {
            let exerciseItems = convertWorkoutToExerciseItems(workout: workout, modelContext: modelContext)

            for item in exerciseItems {
                if dayLog.items == nil { dayLog.items = [] }

                // Prevent duplicate inserts across overlapping syncs using an in-flight UUID gate
                if let uuid = item.healthKitWorkoutUUID {
                    if inflightUUIDs.contains(uuid) {
                        dlog("Skipped due to inflight gate uuid=\(uuid)")
                        continue
                    } else {
                        inflightUUIDs.insert(uuid)
                        localInflight.append(uuid)
                    }
                }

                // Duplicate guard: avoid adding an item that matches an already imported HealthKit item
                let exists = dayLog.unwrappedItems.contains(where: { existing in
                    // Only consider previously imported items to avoid blocking legitimate manual entries
                    guard isImportedFromHealthKit(existing) else { return false }
                    // Prefer UUID-based dedup when present
                    if let eu = existing.healthKitWorkoutUUID, let nu = item.healthKitWorkoutUUID, eu == nu { return true }
                    let sameTimestamp = abs(existing.createdAt.timeIntervalSince(item.createdAt)) < 1.0
                    let sameExercise = existing.exercise?.name == item.exercise?.name
                    let sameUnit = existing.unit?.name == item.unit?.name
                    let sameAmount = abs(existing.amount - item.amount) < 0.01
                    return sameTimestamp && sameExercise && sameUnit && sameAmount
                })

                // Global dedup across all logs by HealthKit UUID
                let globalExists: Bool = {
                    if let uuid = item.healthKitWorkoutUUID {
                        do {
                            let all = try modelContext.fetch(FetchDescriptor<ExerciseItem>())
                            return all.contains { $0.healthKitWorkoutUUID == uuid }
                        } catch { return false }
                    }
                    return false
                }()

                if !exists && !globalExists {
                    // Ensure item is managed so global queries can see it immediately
                    modelContext.insert(item)
                    dayLog.items?.append(item)
                    // Maintain inverse relationship explicitly for consistency in tests and repairs
                    item.dayLog = dayLog
                    inserted += 1
                    changed = true
                    dlog("Inserted item uuid=\(item.healthKitWorkoutUUID ?? "-") day=\(dayLog.date) ex=\(item.exercise?.name ?? "?") amt=\(item.amount)")
                } else {
                    // If it exists globally but not in this day, move the existing item into this day (repair scenario)
                    if !exists, globalExists, let uuid = item.healthKitWorkoutUUID {
                        do {
                            let all = try modelContext.fetch(FetchDescriptor<ExerciseItem>())
                            if let existingItem = all.first(where: { $0.healthKitWorkoutUUID == uuid }) {
                                if existingItem.dayLog !== dayLog {
                                    // Remove from old day array to keep UI state consistent
                                    if let oldDay = existingItem.dayLog {
                                        let existingID = existingItem.persistentModelID
                                        oldDay.items = oldDay.unwrappedItems.filter { $0.persistentModelID != existingID }
                                    }
                                    // Append to target day if not already present
                                    if dayLog.items == nil { dayLog.items = [] }
                                    let existsInTarget = dayLog.items?.contains(where: { $0.persistentModelID == existingItem.persistentModelID }) ?? false
                                    if !existsInTarget {
                                        dayLog.items?.append(existingItem)
                                    }
                                    // Update owning side
                                    existingItem.dayLog = dayLog
                                    changed = true

                                    // Ensure no other DayLog retains any item with the same HealthKit UUID
                                    do {
                                        let allLogs = try modelContext.fetch(FetchDescriptor<DayLog>())
                                        for l in allLogs where l !== dayLog {
                                            if let its = l.items, its.contains(where: { $0.healthKitWorkoutUUID == uuid }) {
                                                l.items = its.filter { $0.healthKitWorkoutUUID != uuid }
                                            }
                                        }
                                    } catch { /* ignore cleanup errors in repair */ }

                                    dlog("Moved existing item uuid=\(uuid) into day=\(dayLog.date)")
                                }
                            }
                        } catch {
                            dlog("Failed move repair for uuid=\(uuid): \(error.localizedDescription)")
                        }
                    } else {
                        dlog("Skipped duplicate uuid=\(item.healthKitWorkoutUUID ?? "-") existsInDay=\(exists) existsGlobal=\(globalExists)")
                    }
                }
            }
        }
        // Release inflight UUIDs
        for u in localInflight { inflightUUIDs.remove(u) }
        // Persist changes so fresh fetches reflect moved/inserted items (important for tests and repair logic)
        if changed {
            do { try modelContext.save() } catch { dlog("Save after importWorkouts failed: \(error.localizedDescription)") }
        }
        return inserted
    }
    
    func fetchWorkouts(from startDate: Date, to endDate: Date) async -> [WorkoutProtocol] {
        // If we have mock workouts for testing, filter them by date range and return
        if let mockWorkouts = mockWorkouts {
            return mockWorkouts.filter { workout in
                workout.startDate >= startDate && workout.startDate <= endDate
            }
        }
        
        // Otherwise, query HealthKit
        return await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                let workouts: [WorkoutProtocol] = (samples as? [HKWorkout]) ?? []
                if let error {
                    let line = "[HKSync] HKSampleQuery error: \(error.localizedDescription)"
                    print(line)
                    Task { @MainActor in
                        self.debugLines.append(line)
                        if self.debugLines.count > 300 { self.debugLines.removeFirst(self.debugLines.count - 300) }
                    }
                }
                // Emit a small preview of fetched records
                for w in workouts.prefix(20) {
                    let line = "[HKSync] Fetched uuid=\(w.uuid) type=\(w.workoutActivityType.rawValue) start=\(w.startDate) end=\(w.endDate)"
                    print(line)
                    Task { @MainActor in
                        self.debugLines.append(line)
                        if self.debugLines.count > 300 { self.debugLines.removeFirst(self.debugLines.count - 300) }
                    }
                }
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Import Management
    
    func isImportedFromHealthKit(_ item: ExerciseItem) -> Bool {
        if item.healthKitWorkoutUUID != nil { return true }
        return item.note?.contains("Imported from Apple Health") == true
    }

    // Visible for tests and internal checks
    func hasImportedWorkout(uuidString: String, modelContext: ModelContext) -> Bool {
        do {
            let all = try modelContext.fetch(FetchDescriptor<ExerciseItem>())
            return all.contains { $0.healthKitWorkoutUUID == uuidString }
        } catch { return false }
    }

    // MARK: - Maintenance & Recovery

    func resetHealthSyncCache() {
        seenWorkoutKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: seenWorkoutsDefaultsKey)
        UserDefaults.standard.removeObject(forKey: lastBackgroundSyncDateKey)
        lastSyncDate = nil
        dlog("Manual reset of Health sync cache")
        // Also clear deleted/tombstoned keys to allow re-imports
        deletedWorkoutKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: deletedWorkoutsDefaultsKey)
        NSUbiquitousKeyValueStore.default.removeObject(forKey: deletedWorkoutsDefaultsKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    @discardableResult
    func resetCacheAndRescan(modelContext: ModelContext) async -> Int {
        resetHealthSyncCache()
        // Force immediate rescan regardless of throttle
        return await processBackgroundUpdates(modelContext: modelContext)
    }

    // Force import ignoring dedup rules for last given hours (debug only)
    @discardableResult
    func forceImportIgnoringDedup(hours: Int = 24, modelContext: ModelContext) async -> Int {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -hours, to: endDate) ?? endDate
        let workouts = await fetchWorkouts(from: startDate, to: endDate)
        dlog("FORCE import window fetched=\(workouts.count)")
        var inserted = 0
        do {
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.startDate) }
            let existingDayLogs = try modelContext.fetch(FetchDescriptor<DayLog>())
            for (day, dayWorkouts) in grouped {
                let dayLog = existingDayLogs.first { calendar.isDate($0.date, inSameDayAs: day) } ?? {
                    let d = DayLog(date: day); modelContext.insert(d); return d
                }()
                for w in dayWorkouts {
                    for item in convertWorkoutToExerciseItems(workout: w, modelContext: modelContext) {
                        if dayLog.items == nil { dayLog.items = [] }
                        modelContext.insert(item)
                        dayLog.items?.append(item)
                        item.dayLog = dayLog
                        inserted += 1
                        dlog("FORCE inserted uuid=\(item.healthKitWorkoutUUID ?? "-") day=\(day) ex=\(item.exercise?.name ?? "?") amt=\(item.amount)")
                    }
                }
            }
            try modelContext.save()
            lastSyncResult = .success(workoutCount: inserted)
            return inserted
        } catch {
            lastSyncResult = .error("Force import failed: \(error.localizedDescription)")
            return 0
        }
    }

    // Import exactly these workouts, ignoring dedup (user-approved repair)
    @discardableResult
    func importSpecificWorkoutsIgnoringDedup(_ workouts: [WorkoutProtocol], modelContext: ModelContext) async -> Int {
        guard !workouts.isEmpty else { return 0 }
        isSyncing = true
        lastSyncResult = nil
        // Add in-flight gates so background importer skips these UUIDs
        let uuids = workouts.map { $0.uuid.uuidString }
        for u in uuids { inflightUUIDs.insert(u) }
        defer {
            isSyncing = false
            for u in uuids { inflightUUIDs.remove(u) }
        }

        var inserted = 0
        do {
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.startDate) }
            let existingLogs = try modelContext.fetch(FetchDescriptor<DayLog>())

            for (day, dayWorkouts) in grouped {
                let dayLog = existingLogs.first { calendar.isDate($0.date, inSameDayAs: day) } ?? {
                    let d = DayLog(date: day); modelContext.insert(d); return d
                }()
                for w in dayWorkouts {
                    for item in convertWorkoutToExerciseItems(workout: w, modelContext: modelContext) {
                        if dayLog.items == nil { dayLog.items = [] }
                        modelContext.insert(item)
                        dayLog.items?.append(item)
                        item.dayLog = dayLog
                        // Mark as seen to avoid background re-import duplication
                        seenWorkoutKeys.insert(item.healthKitWorkoutUUID ?? w.uuid.uuidString)
                        inserted += 1
                    }
                }
            }
            try modelContext.save()
            persistSeenWorkoutKeys()
            lastSyncResult = .success(workoutCount: inserted)
            return inserted
        } catch {
            lastSyncResult = .error("Import failed: \(error.localizedDescription)")
            return 0
        }
    }
    
    func removeHealthKitImports(from dayLog: DayLog, modelContext: ModelContext) {
        guard let items = dayLog.items else { return }

        let itemsToRemove = items.filter { isImportedFromHealthKit($0) }

        // Remove from model and mark their UUIDs as deleted to avoid automatic re-imports across devices
        let uuids = itemsToRemove.compactMap { $0.healthKitWorkoutUUID }
        for item in itemsToRemove { modelContext.delete(item) }
        if !uuids.isEmpty {
            for u in uuids { deletedWorkoutKeys.insert(u) }
            persistDeletedWorkoutKeys()
        }

        dayLog.items = items.filter { !isImportedFromHealthKit($0) }
    }
    
    // MARK: - Sync Management
    
    func syncRecentWorkouts(days: Int = 7, modelContext: ModelContext) async {
        // Set syncing state
        isSyncing = true
        lastSyncResult = nil
        
        // If HealthKit isn't available AND we don't have mocks, report zero
        if !HKHealthStore.isHealthDataAvailable() && mockWorkouts == nil {
            defer { isSyncing = false }
            lastSyncResult = .success(workoutCount: 0)
            return
        }

        defer { isSyncing = false }
        
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
            
            let workouts = await fetchWorkouts(from: startDate, to: endDate)
            
            // Group workouts by day
            let calendar = Calendar.current
            let workoutsByDay = Dictionary(grouping: workouts) { workout in
                calendar.startOfDay(for: workout.startDate)
            }
            
            let existingDayLogs = try modelContext.fetch(FetchDescriptor<DayLog>())
            var totalImportedWorkouts = 0
            
            for (day, dayWorkouts) in workoutsByDay {
                // Find or create day log
                let dayLog = existingDayLogs.first { calendar.isDate($0.date, inSameDayAs: day) } 
                             ?? DayLog(date: day)
                
                if !existingDayLogs.contains(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
                    modelContext.insert(dayLog)
                }
                
                // Remove existing imports for this day to avoid duplicates
                removeHealthKitImports(from: dayLog, modelContext: modelContext)
                
                // Import new workouts and count actual inserts
                let added = importWorkouts(dayWorkouts, to: dayLog, modelContext: modelContext)
                totalImportedWorkouts += added
            }
            
            try modelContext.save()

            // Set success result
            lastSyncResult = .success(workoutCount: totalImportedWorkouts)
            let now = Date()
            UserDefaults.standard.set(now, forKey: lastBackgroundSyncDateKey)
            lastSyncDate = now

            // Mark seen for imported workouts that exist in DB so background ticks skip them
            for (_, dayWorkouts) in workoutsByDay {
                for w in dayWorkouts {
                    let key = workoutKey(w)
                    if hasImportedWorkout(uuidString: key, modelContext: modelContext) {
                        seenWorkoutKeys.insert(key)
                    }
                }
            }
            persistSeenWorkoutKeys()

            // Post-merge cleanup to collapse any duplicates and enforce tombstones
            DedupService.cleanupDuplicateExerciseItems(context: modelContext)
            DedupService.enforceDeletedItemTombstones(context: modelContext)
            
        } catch {
            lastSyncResult = .error("Failed to sync workouts: \(error.localizedDescription)")
        }
    }

    // Foreground helper: Throttled background-style sync when app becomes active
    func foregroundSyncIfNeeded(modelContext: ModelContext, minimumInterval: TimeInterval = 30 * 60) async {
        guard syncEnabled else { return }
        loadSeenWorkoutKeys()
        let purged = purgeStaleSeenKeysIfNeeded(modelContext: modelContext)
        if !purged {
            if let last = UserDefaults.standard.object(forKey: lastBackgroundSyncDateKey) as? Date,
               Date().timeIntervalSince(last) < minimumInterval {
                dlog("Foreground sync skipped: throttled (last=\(last))")
                return
            }
        }
        dlog("Foreground sync running (purged=\(purged))")
        _ = await processBackgroundUpdates(modelContext: modelContext)
    }
}

enum HealthKitSetupState: Equatable {
    case unknown
    case unsupported
    case needsPermission
    case ready
    case error(Error)
    
    static func == (lhs: HealthKitSetupState, rhs: HealthKitSetupState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown),
             (.unsupported, .unsupported),
             (.needsPermission, .needsPermission),
             (.ready, .ready):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
    var title: String {
        switch self {
        case .unknown:
            return "Checking HealthKit..."
        case .unsupported:
            #if os(macOS)
            return "HealthKit Not Available"
            #else
            return "HealthKit Not Supported"
            #endif
        case .needsPermission:
            return "Grant HealthKit Access"
        case .ready:
            return "HealthKit Ready"
        case .error:
            return "HealthKit Error"
        }
    }
    
    var description: String {
        switch self {
        case .unknown:
            return "Checking HealthKit availability..."
        case .unsupported:
            #if os(macOS)
            return "HealthKit data is not available on macOS. Use the iOS version of Bellows to sync workouts from Apple Health."
            #else
            return "HealthKit is not available on this device"
            #endif
        case .needsPermission:
            return "Allow Bellows to read workout data from Apple Health"
        case .ready:
            return "Import workouts from Apple Health to maintain your streak"
        case .error(let error):
            return error.localizedDescription
        }
    }
}

enum HealthKitError: Error, LocalizedError {
    case unavailable
    case unauthorized
    case noData
    
    var errorDescription: String? {
        switch self {
        case .unavailable:
            #if os(macOS)
            return "HealthKit data is not available on macOS"
            #else
            return "HealthKit is not available on this device"
            #endif
        case .unauthorized:
            return "HealthKit access not authorized"
        case .noData:
            return "No workout data available"
        }
    }
}

extension Date {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}

extension ProcessInfo {
    var machineHardwareName: String? {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

// Seed helpers
struct SeedDefaults {
    static let unitTypes: [(String, String, Double, Bool)] = [
        ("Minutes", "min", 0.5, false),  // Time units: 0.5 increments, decimal display
        ("Seconds", "sec", 1.0, false),  // Time units: 1.0 increments, decimal display  
        ("Reps", "reps", 1.0, true),     // Count units: 1.0 increments, integer display
        ("Steps", "steps", 1.0, true),   // Count units: 1.0 increments, integer display
        ("Miles", "mi", 0.1, false),     // Distance units: 0.1 increments, decimal display
        ("Kilometers", "km", 0.1, false), // Distance units: 0.1 increments, decimal display
        ("Laps", "laps", 1.0, true),     // Can be distance or count - user chooses integer display
    ]

    static let exerciseTypes: [(String, Double, Double, Double, String?, String?)] = [
        ("Walk", 3.3, 0.15, 12.0, "figure.walk", "Minutes"),
        ("Run", 9.8, 0.15, 6.0, "figure.run", "Minutes"),
        ("Cycling", 6.8, 0.15, 2.0, "bicycle", "Minutes"),
        ("Yoga", 2.5, 0.15, 10.0, "figure.mind.and.body", "Minutes"),
        ("Plank", 3.8, 0.15, 10.0, "figure.core.training", "Minutes"),
        ("Pushups", 8.0, 0.6, 10.0, "figure.strengthtraining.traditional", "Reps"),
        ("Squats", 5.0, 0.25, 10.0, "figure.strengthtraining.functional", "Reps"),
        ("Other", 4.0, 0.15, 10.0, "square.grid.2x2", nil)
    ]
}

// Keep old function for compatibility during migration
func stepForUnitCategory(_ category: UnitCategory?) -> Double {
    switch category {
    case .reps, .steps: return 1
    case .distance: return 0.1
    case .time: return 0.5
    default: return 0.5
    }
}
