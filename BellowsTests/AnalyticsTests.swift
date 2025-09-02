import Testing
import Foundation
import SwiftData
@testable import Bellows

struct AnalyticsTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    let calendar: Calendar
    
    init() {
        calendar = Calendar.current
        
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            modelContainer = try ModelContainer(
                for: DayLog.self, ExerciseType.self, UnitType.self, ExerciseItem.self,
                configurations: config
            )
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
    
    // MARK: - Current Streak Tests
    
    @Test func currentStreakEmpty() {
        let streak = Analytics.currentStreak(days: [])
        #expect(streak == 0)
    }
    
    @Test func currentStreakSingleDayYesterday() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let dayLog = DayLog(date: yesterday)
        
        // Add exercise to make it count
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 1000)
        dayLog.items = [item]
        
        let streak = Analytics.currentStreak(days: [dayLog], calendar: calendar)
        #expect(streak == 1)
    }
    
    @Test func currentStreakSingleDayToday() {
        let today = Date()
        let dayLog = DayLog(date: today)
        
        // Add exercise to make it count
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 1000)
        dayLog.items = [item]
        
        let streak = Analytics.currentStreak(days: [dayLog], calendar: calendar)
        #expect(streak == 1)
    }
    
    @Test func currentStreakConsecutiveDays() {
        var dayLogs: [DayLog] = []
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        
        // Create 5 consecutive days ending yesterday
        for i in 1...5 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let dayLog = DayLog(date: date)
            let item = ExerciseItem(exercise: exercise, unit: unit, amount: Double(1000 * i))
            dayLog.items = [item]
            dayLogs.append(dayLog)
        }
        
        let streak = Analytics.currentStreak(days: dayLogs, calendar: calendar)
        #expect(streak == 5)
    }
    
    @Test func currentStreakWithTodayIncluded() {
        var dayLogs: [DayLog] = []
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        
        // Create 3 consecutive days ending yesterday
        for i in 1...3 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let dayLog = DayLog(date: date)
            let item = ExerciseItem(exercise: exercise, unit: unit, amount: Double(1000 * i))
            dayLog.items = [item]
            dayLogs.append(dayLog)
        }
        
        // Add today
        let todayLog = DayLog(date: Date())
        let todayItem = ExerciseItem(exercise: exercise, unit: unit, amount: 5000)
        todayLog.items = [todayItem]
        dayLogs.append(todayLog)
        
        let streak = Analytics.currentStreak(days: dayLogs, calendar: calendar)
        #expect(streak == 4) // 3 days + today
    }
    
    @Test func currentStreakBrokenYesterday() {
        var dayLogs: [DayLog] = []
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        
        // Create activity 3 days ago
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let dayLog = DayLog(date: threeDaysAgo)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 1000)
        dayLog.items = [item]
        dayLogs.append(dayLog)
        
        // No activity yesterday or day before - streak is broken
        let streak = Analytics.currentStreak(days: dayLogs, calendar: calendar)
        #expect(streak == 0)
    }
    
    @Test func currentStreakWithGap() {
        var dayLogs: [DayLog] = []
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        
        // Create activity yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayLog = DayLog(date: yesterday)
        let yesterdayItem = ExerciseItem(exercise: exercise, unit: unit, amount: 1000)
        yesterdayLog.items = [yesterdayItem]
        dayLogs.append(yesterdayLog)
        
        // Create activity 3 days ago (gap at 2 days ago)
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        let oldLog = DayLog(date: threeDaysAgo)
        let oldItem = ExerciseItem(exercise: exercise, unit: unit, amount: 1000)
        oldLog.items = [oldItem]
        dayLogs.append(oldLog)
        
        // Streak should only count yesterday
        let streak = Analytics.currentStreak(days: dayLogs, calendar: calendar)
        #expect(streak == 1)
    }
    
    @Test func currentStreakEmptyDayLog() {
        // DayLog exists but has no items
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let dayLog = DayLog(date: yesterday)
        dayLog.items = [] // Empty items
        
        let streak = Analytics.currentStreak(days: [dayLog], calendar: calendar)
        #expect(streak == 0)
    }
    
    @Test func currentStreakMultipleDayLogsPerDay() {
        var dayLogs: [DayLog] = []
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Steps", abbreviation: "steps", category: .steps)
        
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        // Create two DayLogs for the same day
        let dayLog1 = DayLog(date: yesterday)
        let item1 = ExerciseItem(exercise: exercise, unit: unit, amount: 1000)
        dayLog1.items = [item1]
        
        let dayLog2 = DayLog(date: yesterday)
        let item2 = ExerciseItem(exercise: exercise, unit: unit, amount: 2000)
        dayLog2.items = [item2]
        
        dayLogs = [dayLog1, dayLog2]
        
        // Should still count as 1 day streak
        let streak = Analytics.currentStreak(days: dayLogs, calendar: calendar)
        #expect(streak == 1)
    }
    
    // MARK: - EWMA Tests
    
    @Test func ewmaEmpty() {
        let result = Analytics.ewma(values: [])
        #expect(result == [])
    }
    
    @Test func ewmaSingleValue() {
        let result = Analytics.ewma(values: [10.0])
        #expect(result == [10.0])
    }
    
    @Test func ewmaConstantValues() {
        let result = Analytics.ewma(values: [5.0, 5.0, 5.0, 5.0])
        // All values should converge to 5.0
        for value in result {
            #expect(abs(value - 5.0) < 0.0001)
        }
    }
    
    @Test func ewmaDefaultAlpha() {
        let values = [10.0, 20.0, 30.0]
        let result = Analytics.ewma(values: values)
        
        // With alpha=0.3 (default)
        // First value: 10.0
        #expect(abs(result[0] - 10.0) < 0.0001)
        
        // Second value: 0.3*20 + 0.7*10 = 6 + 7 = 13
        #expect(abs(result[1] - 13.0) < 0.0001)
        
        // Third value: 0.3*30 + 0.7*13 = 9 + 9.1 = 18.1
        #expect(abs(result[2] - 18.1) < 0.0001)
    }
    
    @Test func ewmaCustomAlpha() {
        let values = [10.0, 20.0, 30.0]
        let result = Analytics.ewma(values: values, alpha: 0.5)
        
        // With alpha=0.5
        // First value: 10.0
        #expect(abs(result[0] - 10.0) < 0.0001)
        
        // Second value: 0.5*20 + 0.5*10 = 10 + 5 = 15
        #expect(abs(result[1] - 15.0) < 0.0001)
        
        // Third value: 0.5*30 + 0.5*15 = 15 + 7.5 = 22.5
        #expect(abs(result[2] - 22.5) < 0.0001)
    }
    
    @Test func ewmaAlphaOne() {
        let values = [10.0, 20.0, 30.0]
        let result = Analytics.ewma(values: values, alpha: 1.0)
        
        // With alpha=1.0, should just return the original values
        #expect(result == values)
    }
    
    @Test func ewmaAlphaZero() {
        let values = [10.0, 20.0, 30.0]
        let result = Analytics.ewma(values: values, alpha: 0.0)
        
        // With alpha=0.0, all values should be the first value
        #expect(abs(result[0] - 10.0) < 0.0001)
        #expect(abs(result[1] - 10.0) < 0.0001)
        #expect(abs(result[2] - 10.0) < 0.0001)
    }
    
    @Test func ewmaLargeDataset() {
        let values = Array(stride(from: 0.0, to: 100.0, by: 1.0))
        let result = Analytics.ewma(values: values, alpha: 0.3)
        
        // Result should have same count as input
        #expect(result.count == values.count)
        
        // Values should be smoothed (less than the original for increasing series)
        for i in 1..<result.count {
            #expect(result[i] <= values[i])
        }
    }
    
    // MARK: - Today Band Tests
    
    @Test func todayBandEmptyHistory() {
        let band = Analytics.todayBand(today: 10.0, history: [])
        #expect(band == "—")
    }
    
    @Test func todayBandLow() {
        let history = [10.0, 12.0, 11.0, 13.0, 10.0]
        // Mean = 11.2, Variance = 1.36, SD = 1.166
        // Low threshold = 11.2 - 0.5*1.166 = 10.617
        
        let band = Analytics.todayBand(today: 9.0, history: history)
        #expect(band == "low")
    }
    
    @Test func todayBandMedium() {
        let history = [10.0, 12.0, 11.0, 13.0, 10.0]
        // Mean = 11.2, SD = 1.166
        // Medium range: [10.617, 11.783]
        
        let band = Analytics.todayBand(today: 11.0, history: history)
        #expect(band == "medium")
    }
    
    @Test func todayBandHigh() {
        let history = [10.0, 12.0, 11.0, 13.0, 10.0]
        // Mean = 11.2, SD = 1.166
        // High threshold = 11.2 + 0.5*1.166 = 11.783
        
        let band = Analytics.todayBand(today: 15.0, history: history)
        #expect(band == "high")
    }
    
    @Test func todayBandConstantHistory() {
        let history = [10.0, 10.0, 10.0, 10.0]
        // Mean = 10, SD = 0
        
        // Any value not exactly 10 should be high (since SD=0)
        let bandHigh = Analytics.todayBand(today: 10.1, history: history)
        #expect(bandHigh == "high")
        
        let bandLow = Analytics.todayBand(today: 9.9, history: history)
        #expect(bandLow == "low")
        
        // Exactly 10 should be medium
        let bandMedium = Analytics.todayBand(today: 10.0, history: history)
        #expect(bandMedium == "medium")
    }
    
    @Test func todayBandSingleHistory() {
        let history = [10.0]
        // Mean = 10, SD = 0
        
        let band = Analytics.todayBand(today: 10.0, history: history)
        #expect(band == "medium")
        
        let bandHigh = Analytics.todayBand(today: 11.0, history: history)
        #expect(bandHigh == "high")
    }
    
    @Test func todayBandBoundaryValues() {
        let history = [0.0, 10.0, 20.0, 30.0, 40.0]
        // Mean = 20, Variance = 200, SD = 14.142
        // Low threshold = 20 - 0.5*14.142 = 12.929
        // High threshold = 20 + 0.5*14.142 = 27.071
        
        // Test boundary cases
        let lowBoundary = Analytics.todayBand(today: 12.929, history: history)
        #expect(lowBoundary == "medium") // Exactly at boundary
        
        let highBoundary = Analytics.todayBand(today: 27.071, history: history)
        #expect(highBoundary == "medium") // Exactly at boundary
    }
    
    @Test func todayBandNegativeValues() {
        let history = [-10.0, -5.0, -8.0, -6.0, -9.0]
        // Mean = -7.6, calculate SD
        
        let band = Analytics.todayBand(today: -5.0, history: history)
        #expect(band == "high") // -5 is higher than mean of -7.6
        
        let bandLow = Analytics.todayBand(today: -10.0, history: history)
        #expect(bandLow == "low")
    }
    
    // MARK: - Integration Tests
    
    @Test func currentStreakWithRealDates() {
        var dayLogs: [DayLog] = []
        let exercise = ExerciseType(name: "Running", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 8.0, defaultUnit: nil)
        let unit = UnitType(name: "Miles", abbreviation: "mi", category: .distance)
        
        // Create a week of consecutive activity
        for i in 0...6 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let dayLog = DayLog(date: date)
            let item = ExerciseItem(exercise: exercise, unit: unit, amount: Double(3 + i))
            dayLog.items = [item]
            dayLogs.append(dayLog)
        }
        
        let streak = Analytics.currentStreak(days: dayLogs, calendar: calendar)
        #expect(streak == 7)
    }
    
    @Test func ewmaWithRealData() {
        // Simulate daily step counts
        let stepCounts = [8000.0, 10000.0, 7500.0, 12000.0, 9000.0, 11000.0, 8500.0]
        let smoothed = Analytics.ewma(values: stepCounts, alpha: 0.3)
        
        #expect(smoothed.count == stepCounts.count)
        
        // Smoothed values should show less variation
        let originalVariance = variance(stepCounts)
        let smoothedVariance = variance(smoothed)
        #expect(smoothedVariance < originalVariance)
    }
    
    @Test func todayBandWithRealData() {
        // Simulate a week of exercise minutes
        let weekHistory = [30.0, 45.0, 20.0, 60.0, 35.0, 40.0, 25.0]
        
        // Test various today values
        let lowDay = Analytics.todayBand(today: 15.0, history: weekHistory)
        #expect(lowDay == "low")
        
        let typicalDay = Analytics.todayBand(today: 35.0, history: weekHistory)
        #expect(typicalDay == "medium")
        
        let highDay = Analytics.todayBand(today: 70.0, history: weekHistory)
        #expect(highDay == "high")
    }
    
    // Helper function for variance calculation
    private func variance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
    }
}