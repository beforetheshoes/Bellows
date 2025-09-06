import Testing
import SwiftData
import Foundation
@testable import Bellows

// Fake WC client for testing coordinator behavior.
final class FakeWCClient: WatchConnectivityClient {
    weak var delegate: WatchConnectivityClientDelegate?
    var isReachable: Bool = true
    var sentMessages: [[String: Any]] = []
    var sentApplicationContexts: [[String: Any]] = []
    var sentComplicationUserInfos: [[String: Any]] = []

    func activate() { /* no-op */ }

    func sendMessage(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
        sentMessages.append(message)
        // No reply for tests.
    }

    func updateApplicationContext(_ context: [String : Any]) throws {
        sentApplicationContexts.append(context)
    }

    // Test helper to simulate an incoming message from watch
    func simulateIncomingMessage(_ message: [String: Any]) {
        delegate?.wcClient(self, didReceiveMessage: message)
    }
    
    // Test helper to simulate complication user info
    func simulateComplicationUserInfo(_ userInfo: [String: Any]) {
        delegate?.wcClient(self, didReceiveComplicationUserInfo: userInfo)
    }
    
    // Mock transferCurrentComplicationUserInfo for testing iOS behavior
    func transferCurrentComplicationUserInfo(_ userInfo: [String: Any]) {
        sentComplicationUserInfos.append(userInfo)
    }
}

// Spy Health service conforming to HealthSyncing
@MainActor
final class SpyHealthSync: HealthSyncing {
    var syncEnabled: Bool = true
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var foregroundCalls: Int = 0

    func foregroundSyncIfNeeded(modelContext: ModelContext, minimumInterval: TimeInterval) async {
        foregroundCalls += 1
        lastSyncDate = Date()
    }
}

struct WatchConnectivityNudgeTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext

    init() {
        let schema = Schema([
            DayLog.self,
            ExerciseType.self,
            UnitType.self,
            ExerciseItem.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    @Test @MainActor
    func triggersSyncOnValidNudge() async {
        let wc = FakeWCClient()
        let spy = SpyHealthSync()
        let coord = WatchNudgeCoordinator(client: wc, health: spy, modelContext: modelContext, minimumNudgeInterval: 0)
        #expect(coord.nudgeCount == 0)

        wc.simulateIncomingMessage([
            WatchConnectivitySchemaV1.versionKey: WatchConnectivitySchemaV1.version,
            WatchConnectivitySchemaV1.typeKey: "nudge",
            WatchConnectivitySchemaV1.reasonKey: "workout_finished"
        ])

        // Allow async Task in coordinator to execute
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(spy.foregroundCalls == 1)
        #expect(coord.nudgeCount == 1)
        #expect(coord.lastNudgeReason == "workout_finished")
    }

    @Test @MainActor
    func doesNotSyncWhenDisabled() async {
        let wc = FakeWCClient()
        let spy = SpyHealthSync(); spy.syncEnabled = false
        _ = WatchNudgeCoordinator(client: wc, health: spy, modelContext: modelContext, minimumNudgeInterval: 0)

        wc.simulateIncomingMessage([
            WatchConnectivitySchemaV1.versionKey: WatchConnectivitySchemaV1.version,
            WatchConnectivitySchemaV1.typeKey: "nudge",
            WatchConnectivitySchemaV1.reasonKey: "workout_finished"
        ])

        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(spy.foregroundCalls == 0)
    }

    @Test @MainActor
    func throttlesRapidNudges() async {
        let wc = FakeWCClient()
        let spy = SpyHealthSync()
        let coord = WatchNudgeCoordinator(client: wc, health: spy, modelContext: modelContext, minimumNudgeInterval: 10)

        let msg: [String: Any] = [
            WatchConnectivitySchemaV1.versionKey: WatchConnectivitySchemaV1.version,
            WatchConnectivitySchemaV1.typeKey: "nudge",
            WatchConnectivitySchemaV1.reasonKey: "workout_finished"
        ]
        wc.simulateIncomingMessage(msg)
        try? await Task.sleep(nanoseconds: 50_000_000)
        wc.simulateIncomingMessage(msg)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(spy.foregroundCalls == 1)
        #expect(coord.nudgeCount == 1)
    }

    @Test @MainActor
    func ignoresUnknownSchemaVersion() async {
        let wc = FakeWCClient()
        let spy = SpyHealthSync()
        _ = WatchNudgeCoordinator(client: wc, health: spy, modelContext: modelContext, minimumNudgeInterval: 0)

        wc.simulateIncomingMessage([
            WatchConnectivitySchemaV1.versionKey: 99,
            WatchConnectivitySchemaV1.typeKey: "nudge",
            WatchConnectivitySchemaV1.reasonKey: "workout_finished"
        ])
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(spy.foregroundCalls == 0)
    }

    @Test @MainActor
    func skipsWhenAlreadySyncing() async {
        let wc = FakeWCClient()
        let spy = SpyHealthSync(); spy.isSyncing = true
        _ = WatchNudgeCoordinator(client: wc, health: spy, modelContext: modelContext, minimumNudgeInterval: 0)

        wc.simulateIncomingMessage([
            WatchConnectivitySchemaV1.versionKey: WatchConnectivitySchemaV1.version,
            WatchConnectivitySchemaV1.typeKey: "nudge",
            WatchConnectivitySchemaV1.reasonKey: "workout_finished"
        ])
        try? await Task.sleep(nanoseconds: 100_000_000)
        #expect(spy.foregroundCalls == 0)
    }

    @Test @MainActor
    func addEntryCreatesExerciseItem() async {
        // Seed defaults
        __test_seed_defaults(context: modelContext)
        let wc = FakeWCClient()
        let spy = SpyHealthSync() // health not used for add_entry
        let coord = WatchNudgeCoordinator(client: wc, health: spy, modelContext: modelContext, minimumNudgeInterval: 0)
        #expect(coord.nudgeCount == 0)

        wc.simulateIncomingMessage([
            WatchConnectivitySchemaV1.versionKey: WatchConnectivitySchemaV1.version,
            WatchConnectivitySchemaV1.typeKey: "add_entry",
            WatchConnectivitySchemaV1.payloadKey: [
                "exerciseName": "Walk",
                "unitName": "Minutes",
                "amount": 15.0,
                "enjoyment": 4,
                "intensity": 3
            ]
        ])
        // Allow broadcast and save
        try? await Task.sleep(nanoseconds: 100_000_000)

        let days = try! modelContext.fetch(FetchDescriptor<DayLog>())
        let today = Date().startOfDay()
        let calendar = Calendar.current
        let day = days.first { calendar.isDate($0.date, inSameDayAs: today) }
        #expect(day != nil)
        #expect((day?.unwrappedItems.count ?? 0) >= 1)
    }
}
