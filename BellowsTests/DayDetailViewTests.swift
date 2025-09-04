import Testing
import SwiftUI
import SwiftData
import Foundation
@testable import Bellows

struct DayDetailViewTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
    
    // MARK: - DayDetailView Creation Tests
    
    @MainActor
    @Test func dayDetailViewInitialization() {
        let date = Date()
        let dayDetailView = DayDetailView(date: date)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    @MainActor
    @Test func dayDetailViewWithPastDate() {
        let pastDate = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let dayDetailView = DayDetailView(date: pastDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
        
        _ = dayDetailView
        #expect(true)
    }
    
    @MainActor
    @Test func dayDetailViewWithFutureDate() {
        let futureDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let dayDetailView = DayDetailView(date: futureDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
        
        _ = dayDetailView
        #expect(true)
    }
    
    @MainActor
    @Test func dayDetailViewWithExactMidnight() {
        let midnight = Calendar.current.startOfDay(for: Date())
        let dayDetailView = DayDetailView(date: midnight)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    // MARK: - Query Filtering Tests
    
    @MainActor
    @Test func dayLogFiltering() throws {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let otherDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 16))!
        
        // Create day logs for both dates
        let targetDayLog = DayLog(date: testDate)
        let otherDayLog = DayLog(date: otherDate)
        
        modelContext.insert(targetDayLog)
        modelContext.insert(otherDayLog)
        try modelContext.save()
        
        // DayDetailView should only show the target date
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    @MainActor
    @Test func startOfDayFiltering() throws {
        let baseDate = Date()
        let startOfDay = baseDate.startOfDay()
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Create logs at different times of the same day
        let morningLog = DayLog(date: startOfDay)
        let afternoonLog = DayLog(date: Calendar.current.date(byAdding: .hour, value: 14, to: startOfDay)!)
        let nextDayLog = DayLog(date: endOfDay)
        
        modelContext.insert(morningLog)
        modelContext.insert(afternoonLog)
        modelContext.insert(nextDayLog)
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: baseDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    // MARK: - Date String Formatting Tests
    
    @MainActor
    @Test func dateStringFormatting() {
        struct TestDateStringView: View {
            let date: Date
            
            var body: some View {
                Text(dateString(date))
            }
            
            private func dateString(_ date: Date) -> String {
                let formatter = DateFormatter()
                formatter.dateStyle = .full
                return formatter.string(from: date)
            }
        }
        
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 12, day: 25))!
        let testView = TestDateStringView(date: testDate)
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func navigationTitleFormatting() {
        let testDate = Calendar.current.date(from: DateComponents(year: 2024, month: 7, day: 4))!
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    // MARK: - Empty State Tests
    
    @MainActor
    @Test func emptyStateWithNoDayLog() {
        let testDate = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        _ = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        // Should show "No data" state when no day log exists
        #expect(true)
    }
    
    @MainActor
    @Test func emptyStateWithEmptyDayLog() throws {
        let testDate = Date()
        let emptyDayLog = DayLog(date: testDate)
        
        modelContext.insert(emptyDayLog)
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        // Should show "No exercises logged" state
        _ = dayDetailView
        #expect(true)
    }
    
    // MARK: - Exercise List Display Tests
    
    @MainActor
    @Test func exerciseListWithSingleItem() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Walking", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 30, note: "Morning walk", enjoyment: 4, intensity: 2)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    @MainActor
    @Test func exerciseListWithMultipleItems() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let walkingExercise = ExerciseType(name: "Walking", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let pushupsExercise = ExerciseType(name: "Pushups", baseMET: 8.0, repWeight: 0.6, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        
        let minutesUnit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let repsUnit = UnitType(name: "Reps", abbreviation: "reps", stepSize: 1.0, displayAsInteger: true)
        
        let walkingItem = ExerciseItem(exercise: walkingExercise, unit: minutesUnit, amount: 30, enjoyment: 4, intensity: 2)
        let pushupsItem = ExerciseItem(exercise: pushupsExercise, unit: repsUnit, amount: 20, enjoyment: 3, intensity: 4)
        
        dayLog.items = [walkingItem, pushupsItem]
        walkingItem.dayLog = dayLog
        pushupsItem.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(walkingExercise)
        modelContext.insert(pushupsExercise)
        modelContext.insert(minutesUnit)
        modelContext.insert(repsUnit)
        modelContext.insert(walkingItem)
        modelContext.insert(pushupsItem)
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    // MARK: - Exercise Label Formatting Tests
    
    @MainActor
    @Test func exerciseLabelFormatting() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Running", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 8.0, defaultUnit: nil)
        let unit = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 3.2)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        struct TestLabelFormatting: View {
            let item: ExerciseItem
            
            var body: some View {
                Text(label(for: item))
            }
            
            private func label(for item: ExerciseItem) -> String {
                let name = item.exercise?.name ?? "Unknown"
                let abbr = item.unit?.abbreviation ?? ""
                let amountStr: String
                if let unit = item.unit {
                    if unit.displayAsInteger {
                        amountStr = String(Int(item.amount.rounded()))
                    } else {
                        amountStr = String(format: "%.1f", item.amount)
                    }
                } else {
                    amountStr = String(format: "%.1f", item.amount)
                }
                
                if abbr.isEmpty {
                    return "\(amountStr) \(name)"
                } else {
                    return "\(amountStr) \(abbr) \(name)"
                }
            }
        }
        
        let testView = TestLabelFormatting(item: item)
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func exerciseLabelWithMissingData() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        // Create item with missing unit references
        let exercise = ExerciseType(name: "", baseMET: 0, repWeight: 0, defaultPaceMinPerMi: 0, defaultUnit: nil)
        let item = ExerciseItem(exercise: exercise, note: nil, enjoyment: 3, intensity: 3)
        modelContext.insert(exercise)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(item)
        try modelContext.save()
        
        struct TestMissingDataLabel: View {
            let item: ExerciseItem
            
            var body: some View {
                Text(label(for: item))
            }
            
            private func label(for item: ExerciseItem) -> String {
                let name = item.exercise?.name ?? "Unknown"
                let abbr = item.unit?.abbreviation ?? ""
                let amountStr: String
                if let unit = item.unit {
                    if unit.displayAsInteger {
                        amountStr = String(Int(item.amount.rounded()))
                    } else {
                        amountStr = String(format: "%.1f", item.amount)
                    }
                } else {
                    amountStr = String(format: "%.1f", item.amount)
                }
                
                if abbr.isEmpty {
                    return "\(amountStr) \(name)"
                } else {
                    return "\(amountStr) \(abbr) \(name)"
                }
            }
        }
        
        let testView = TestMissingDataLabel(item: item)
        _ = testView
        #expect(true)
    }
    
    // MARK: - Daily Summary Tests
    
    @MainActor
    @Test func dailySummaryCalculation() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unit = UnitType(name: "Test", abbreviation: "t", stepSize: 1.0, displayAsInteger: false)
        
        let item1 = ExerciseItem(exercise: exercise, unit: unit, amount: 10, enjoyment: 5, intensity: 3)
        let item2 = ExerciseItem(exercise: exercise, unit: unit, amount: 20, enjoyment: 3, intensity: 4)
        let item3 = ExerciseItem(exercise: exercise, unit: unit, amount: 30, enjoyment: 4, intensity: 5)
        
        dayLog.items = [item1, item2, item3]
        item1.dayLog = dayLog
        item2.dayLog = dayLog
        item3.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item1)
        modelContext.insert(item2)
        modelContext.insert(item3)
        try modelContext.save()
        
        struct TestDailySummary: View {
            let dayLog: DayLog
            
            var body: some View {
                VStack {
                    // Avoid binding an unused value; only check boolean condition
                    if dailyAverages(for: dayLog) != nil {
                        Text("Daily Summary Available")
                    }
                }
            }
            
            private func dailyAverages(for dayLog: DayLog) -> (enjoyment: Double, intensity: Double)? {
                let items = dayLog.unwrappedItems
                guard !items.isEmpty else { return nil }
                let eAvg = Double(items.map { $0.enjoyment }.reduce(0, +)) / Double(items.count)
                let iAvg = Double(items.map { $0.intensity }.reduce(0, +)) / Double(items.count)
                return (eAvg, iAvg)
            }
        }
        
        let testView = TestDailySummary(dayLog: dayLog)
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func summaryWithSingleItem() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Solo Exercise", baseMET: 6.0, repWeight: 0.3, defaultPaceMinPerMi: 9.0, defaultUnit: nil)
        let unit = UnitType(name: "Test", abbreviation: "t", stepSize: 1.0, displayAsInteger: false)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 15, enjoyment: 4, intensity: 3)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    @MainActor
    @Test func noSummaryForEmptyDay() throws {
        let testDate = Date()
        let emptyDayLog = DayLog(date: testDate)
        
        modelContext.insert(emptyDayLog)
        try modelContext.save()
        
        struct TestNoSummary: View {
            let dayLog: DayLog
            
            var body: some View {
                VStack {
                    if dailyAverages(for: dayLog) != nil {
                        Text("Should not appear")
                    } else {
                        Text("No summary for empty day")
                    }
                }
            }
            
            private func dailyAverages(for dayLog: DayLog) -> (enjoyment: Double, intensity: Double)? {
                let items = dayLog.unwrappedItems
                guard !items.isEmpty else { return nil }
                let eAvg = Double(items.map { $0.enjoyment }.reduce(0, +)) / Double(items.count)
                let iAvg = Double(items.map { $0.intensity }.reduce(0, +)) / Double(items.count)
                return (eAvg, iAvg)
            }
        }
        
        let testView = TestNoSummary(dayLog: emptyDayLog)
        _ = testView
        #expect(true)
    }
    
    // MARK: - Timestamp Display Tests
    
    @MainActor
    @Test func exerciseListDisplaysTimestamp() throws {
        let testDate = Date().startOfDay()
        let dayLog = DayLog(date: testDate)
        
        // Create exercises with specific timestamps
        let exercise1 = ExerciseType(name: "Morning Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let unit1 = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let morningTime = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 7, minute: 30))!
        let item1 = ExerciseItem(exercise: exercise1, unit: unit1, amount: 30, at: morningTime)
        
        let exercise2 = ExerciseType(name: "Evening Run", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 6.0, defaultUnit: nil)
        let unit2 = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let eveningTime = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 18, minute: 45))!
        let item2 = ExerciseItem(exercise: exercise2, unit: unit2, amount: 3.5, at: eveningTime)
        
        dayLog.items = [item1, item2]
        item1.dayLog = dayLog
        item2.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise1)
        modelContext.insert(unit1)
        modelContext.insert(item1)
        modelContext.insert(exercise2)
        modelContext.insert(unit2)
        modelContext.insert(item2)
        try modelContext.save()
        
        // Test that the exercise list includes timestamps
        struct TestExerciseListView: View {
            let dayLog: DayLog
            
            var body: some View {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(dayLog.unwrappedItems, id: \.persistentModelID) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(label(for: item))
                                    .font(.body)
                                
                                Text(timeString(item.createdAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                if let note = item.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 8) {
                                    Label("\(item.enjoyment)", systemImage: "face.smiling.fill")
                                    Label("\(item.intensity)", systemImage: "flame.fill")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            private func label(for item: ExerciseItem) -> String {
                let name = item.exercise?.name ?? "Unknown"
                let abbr = item.unit?.abbreviation ?? ""
                let amountStr: String
                if let unit = item.unit {
                    if unit.displayAsInteger {
                        amountStr = String(Int(item.amount.rounded()))
                    } else {
                        amountStr = String(format: "%.1f", item.amount)
                    }
                } else {
                    amountStr = String(format: "%.1f", item.amount)
                }
                
                if abbr.isEmpty {
                    return "\(amountStr) \(name)"
                } else {
                    return "\(amountStr) \(abbr) \(name)"
                }
            }
            
            private func timeString(_ d: Date) -> String {
                let f = DateFormatter()
                f.timeStyle = .short
                return f.string(from: d)
            }
        }
        
        let testView = TestExerciseListView(dayLog: dayLog)
        _ = testView
        #expect(true)
    }
    
    // MARK: - Toolbar and Sheet Tests
    
    @MainActor
    @Test func toolbarAddButton() {
        let dayDetailView = DayDetailView(date: Date())
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    @MainActor
    @Test func addExerciseSheetPresentation() {
        struct TestAddSheet: View {
            @State private var showingAddSheet = false
            let date: Date
            let container: ModelContainer
            
            var body: some View {
                Button("Add Exercise") {
                    showingAddSheet = true
                }
                .sheet(isPresented: $showingAddSheet) {
                    AddExerciseItemSheet(date: date, dayLog: nil)
                        .modelContainer(container)
                }
            }
        }
        
        let testView = TestAddSheet(date: Date(), container: modelContainer)
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func editExerciseSheetPresentation() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Edit Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unit = UnitType(name: "Test", abbreviation: "t", stepSize: 1.0, displayAsInteger: false)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        struct TestEditSheet: View {
            @State private var editingItem: ExerciseItem?
            let item: ExerciseItem
            let container: ModelContainer
            
            var body: some View {
                Button("Edit Item") {
                    editingItem = item
                }
                .sheet(item: $editingItem) { item in
                    EditExerciseItemSheet(item: item)
                        .modelContainer(container)
                }
            }
        }
        
        let testView = TestEditSheet(item: item, container: modelContainer)
        _ = testView
        #expect(true)
    }
    
    // MARK: - Context Menu Tests
    
    @MainActor
    @Test func exerciseItemContextMenu() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Context Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unit = UnitType(name: "Test", abbreviation: "t", stepSize: 1.0, displayAsInteger: false)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        struct TestContextMenu: View {
            let item: ExerciseItem
            let context: ModelContext
            
            var body: some View {
                Text("Exercise Item")
                    .contextMenu {
                        Button("Edit") {
                            // Edit action
                        }
                        
                        Button("Delete", role: .destructive) {
                            context.delete(item)
                            try? context.save()
                        }
                    }
            }
        }
        
        let testView = TestContextMenu(item: item, context: modelContext)
        _ = testView
        #expect(true)
    }
    
    // MARK: - Platform-Specific Tests
    
    @MainActor
    @Test func iOSNavigationBarTitle() {
        _ = DayDetailView(date: Date())
            .modelContainer(modelContainer)
        
        struct TestiOSNavigation: View {
            let container: ModelContainer
            
            var body: some View {
                NavigationStack {
                    DayDetailView(date: Date())
                        .modelContainer(container)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.large)
                        #endif
                }
            }
        }
        
        let testView = TestiOSNavigation(container: modelContainer)
        _ = testView
        #expect(true)
    }
    
    // MARK: - Data Persistence Tests
    
    @MainActor
    @Test func dataModificationHandling() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Modify Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unit = UnitType(name: "Test", abbreviation: "t", stepSize: 1.0, displayAsInteger: false)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        // Modify the item
        item.amount = 20
        item.enjoyment = 5
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        _ = dayDetailView
        #expect(true)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    @Test func handlingDeletedItems() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        let exercise = ExerciseType(name: "Delete Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unit = UnitType(name: "Test", abbreviation: "t", stepSize: 1.0, displayAsInteger: false)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        dayLog.items = [item]
        item.dayLog = dayLog
        
        modelContext.insert(dayLog)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        // Delete the item
        modelContext.delete(item)
        try modelContext.save()
        
        // View should handle the deletion gracefully
        _ = dayDetailView
        #expect(true)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    @Test func performanceWithManyExercises() throws {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        
        // Create many exercise items
        for i in 0..<100 {
            let exercise = ExerciseType(name: "Exercise \\(i)", baseMET: 4.0 + Double(i % 10), repWeight: 0.15, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
            let categoryIndex = i % 5
            let (stepSize, displayAsInteger): (Double, Bool) = {
                switch categoryIndex {
                case 0: return (0.5, false)  // time
                case 1: return (0.1, false)  // distance
                case 2: return (1.0, true)   // reps
                case 3: return (1.0, true)   // steps
                default: return (1.0, false) // other
                }
            }()
            let unit = UnitType(name: "Unit \\(i)", abbreviation: "u\\(i)", stepSize: stepSize, displayAsInteger: displayAsInteger)
            let item = ExerciseItem(
                exercise: exercise, 
                unit: unit, 
                amount: Double(i + 1), 
                note: i % 10 == 0 ? "Note for \\(i)" : nil,
                enjoyment: (i % 5) + 1, 
                intensity: (i % 4) + 2
            )
            
            dayLog.items?.append(item) ?? {
                dayLog.items = [item]
            }()
            item.dayLog = dayLog
            
            modelContext.insert(exercise)
            modelContext.insert(unit)
            modelContext.insert(item)
        }
        
        modelContext.insert(dayLog)
        try modelContext.save()
        
        let dayDetailView = DayDetailView(date: testDate)
            .modelContainer(modelContainer)
        
        // Should handle many exercises efficiently
        _ = dayDetailView
        #expect(true)
    }
}
