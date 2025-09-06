import Testing
import SwiftData
import Foundation
@testable import Bellows

struct WatchComplicationSyncTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
        let schema = Schema([
            DayLog.self,
            ExerciseItem.self,
            ExerciseType.self,
            UnitType.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    @Test @MainActor
    func complicationUserInfoUpdatesSharedDefaults() {
        let fakeWC = FakeWCClient()
        let nudgeCoordinator = WatchNudgeCoordinator(client: fakeWC, health: SpyHealthSync(), modelContext: modelContext, minimumNudgeInterval: 0)
        
        // Create some test data that affects streak
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 1.0, displayAsInteger: true)
        
        modelContext.insert(exercise)
        modelContext.insert(unit)
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let dayLog = DayLog(date: yesterday)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 30)
        dayLog.items = [item]
        
        modelContext.insert(dayLog)
        try! modelContext.save()
        
        // Broadcast state should include streak and intensity
        nudgeCoordinator.broadcastStateToWatch()
        
        // Verify the broadcast includes streak data
        #expect(fakeWC.sentApplicationContexts.count >= 1)
        let lastContext = fakeWC.sentApplicationContexts.last!
        
        #expect((lastContext[WatchConnectivitySchemaV1.appCtxStreakKey] as? Int) == 1)
        #expect(lastContext[WatchConnectivitySchemaV1.appCtxIntensityKey] is Double)
    }
    
    
    @Test @MainActor
    func streakChangeObserverTriggersCorrectly() {
        // This test will verify the streak change detection logic
        let days: [DayLog] = []
        let initialStreak = Analytics.currentStreak(days: days)
        #expect(initialStreak == 0)
        
        // Create exercise data for yesterday
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 1.0, displayAsInteger: true)
        
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let dayLog = DayLog(date: yesterday)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 30)
        dayLog.items = [item]
        
        let newDays = [dayLog]
        let newStreak = Analytics.currentStreak(days: newDays)
        #expect(newStreak == 1)
        
        // Verify streak actually changed
        #expect(newStreak != initialStreak)
    }
    
}