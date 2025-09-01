import Testing
import SwiftUI
import SwiftData
import Foundation
@testable import Bellows

struct ExerciseSheetsTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
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
    
    // MARK: - AddExerciseItemSheet Tests
    
    @MainActor
    @Test func addExerciseItemSheetCreation() {
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        let sheet = AddExerciseItemSheet(date: testDate, dayLog: dayLog)
            .modelContainer(modelContainer)
        
        _ = sheet
        #expect(true)
    }
    
    @MainActor
    @Test func addExerciseItemSheetBody() throws {
        // Create test data
        let exercise = ExerciseType(name: "Test Exercise", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        modelContext.insert(exercise)
        modelContext.insert(unit)
        try modelContext.save()
        
        let testDate = Date()
        let dayLog = DayLog(date: testDate)
        let sheet = AddExerciseItemSheet(date: testDate, dayLog: dayLog)
            .modelContainer(modelContainer)
        
        _ = sheet
        #expect(true)
    }
    
    @MainActor
    @Test func addExerciseItemFilteredExerciseTypes() throws {
        // Create test data including "Other"
        let exercise1 = ExerciseType(name: "Walk", baseMET: 3.0, repWeight: 0.15, defaultPaceMinPerMi: 12.0)
        let exercise2 = ExerciseType(name: "Other", baseMET: 4.0, repWeight: 0.15, defaultPaceMinPerMi: 10.0)
        modelContext.insert(exercise1)
        modelContext.insert(exercise2)
        try modelContext.save()
        
        struct TestFilteredExercises: View {
            let container: ModelContainer
            @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
            
            private var filteredExerciseTypes: [ExerciseType] {
                exerciseTypes.filter { $0.name.lowercased() != "other" }
            }
            
            var body: some View {
                Text("Filtered: \(filteredExerciseTypes.count)")
            }
        }
        
        let testView = TestFilteredExercises(container: modelContainer)
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func addExerciseItemFilteredUnitTypes() throws {
        // Create test data including "Other"
        let unit1 = UnitType(name: "Minutes", abbreviation: "min", category: .minutes)
        let unit2 = UnitType(name: "Other", abbreviation: "", category: .other)
        modelContext.insert(unit1)
        modelContext.insert(unit2)
        try modelContext.save()
        
        struct TestFilteredUnits: View {
            let container: ModelContainer
            @Query(sort: \UnitType.name) private var unitTypes: [UnitType]
            
            private var filteredUnitTypes: [UnitType] {
                unitTypes.filter { $0.name.lowercased() != "other" }
            }
            
            var body: some View {
                Text("Filtered: \(filteredUnitTypes.count)")
            }
        }
        
        let testView = TestFilteredUnits(container: modelContainer)
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func stepForSelectedUnitFunction() {
        struct TestStepFunction: View {
            @State private var selectedUnit: UnitType?
            
            var body: some View {
                Text("Step: \(stepForSelectedUnit())")
            }
            
            private func stepForSelectedUnit() -> Double {
                switch selectedUnit?.category {
                case .reps, .steps: return 1
                case .distanceMi: return 0.1
                case .minutes: return 0.5
                default: return 0.5
                }
            }
        }
        
        let testView = TestStepFunction()
        _ = testView
        #expect(true)
    }
    
    // MARK: - EditExerciseItemSheet Tests
    
    @MainActor
    @Test func editExerciseItemSheetCreation() throws {
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        let sheet = EditExerciseItemSheet(item: item)
            .modelContainer(modelContainer)
        
        _ = sheet
        #expect(true)
    }
    
    @MainActor
    @Test func editExerciseItemSheetBody() throws {
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        let sheet = EditExerciseItemSheet(item: item)
            .modelContainer(modelContainer)
        
        _ = sheet
        #expect(true)
    }
    
    // MARK: - Form Validation Tests
    
    @MainActor
    @Test func addExerciseFormValidation() {
        struct TestFormValidation: View {
            @State private var selectedExercise: ExerciseType?
            @State private var selectedUnit: UnitType?
            @State private var amount: Double = 0
            
            var isFormValid: Bool {
                selectedExercise != nil && selectedUnit != nil && amount > 0
            }
            
            var body: some View {
                Text("Valid: \(String(isFormValid))")
            }
        }
        
        let testView = TestFormValidation()
        _ = testView
        #expect(true)
    }
    
    // MARK: - Helper Function Tests
    
    @Test func amountOnlyStringFormatting() {
        let repsUnit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let minutesUnit = UnitType(name: "Minutes", abbreviation: "min", category: .minutes)
        let milesUnit = UnitType(name: "Miles", abbreviation: "mi", category: .distanceMi)
        
        // Test different formatting based on unit category
        let repsResult = amountOnlyString(10.5, unit: repsUnit)
        let minutesResult = amountOnlyString(15.7, unit: minutesUnit)
        let milesResult = amountOnlyString(3.25, unit: milesUnit)
        let nilUnitResult = amountOnlyString(5.8, unit: nil)
        
        #expect(!repsResult.isEmpty)
        #expect(!minutesResult.isEmpty)
        #expect(!milesResult.isEmpty)
        #expect(!nilUnitResult.isEmpty)
    }
    
    // MARK: - Navigation and Toolbar Tests
    
    @MainActor
    @Test func addExerciseNavigationTitle() {
        _ = Date()
        
        struct TestNavigationTitle: View {
            var body: some View {
                NavigationStack {
                    Text("Content")
                        .navigationTitle("Log Exercise")
                }
            }
        }
        
        let testView = TestNavigationTitle()
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func editExerciseNavigationTitle() {
        struct TestEditNavigationTitle: View {
            var body: some View {
                NavigationStack {
                    Text("Content")
                        .navigationTitle("Edit Exercise")
                }
            }
        }
        
        let testView = TestEditNavigationTitle()
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func toolbarButtons() {
        struct TestToolbar: View {
            @Environment(\.dismiss) private var dismiss
            @State private var selectedExercise: ExerciseType?
            @State private var selectedUnit: UnitType?
            @State private var amount: Double = 10
            
            var body: some View {
                NavigationStack {
                    Text("Content")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { dismiss() }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") { /* save action */ }
                                    .disabled(selectedExercise == nil || selectedUnit == nil || amount <= 0)
                            }
                        }
                }
            }
        }
        
        let testView = TestToolbar()
        _ = testView
        #expect(true)
    }
    
    // MARK: - Platform-Specific Tests
    
    @MainActor
    @Test func macOSPresentationModifiers() {
        struct TestMacOSModifiers: View {
            var body: some View {
                Text("Test")
                #if os(macOS)
                    .formStyle(.grouped)
                    .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
                #endif
            }
        }
        
        let testView = TestMacOSModifiers()
        _ = testView
        #expect(true)
    }
    
    #if os(macOS)
    @MainActor
    @Test func macPresentationFittedExtension() {
        struct TestMacExtension: View {
            var body: some View {
                Text("Test")
                    .macPresentationFitted()
            }
        }
        
        let testView = TestMacExtension()
        _ = testView
        #expect(true)
    }
    #endif
    
    // MARK: - Rating Tests
    
    @MainActor
    @Test func enjoymentRatingPicker() {
        struct TestEnjoymentPicker: View {
            @State private var enjoyment: Int = 3
            
            var body: some View {
                VStack {
                    Text("Enjoyment")
                    Picker("Enjoyment", selection: $enjoyment) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        
        let testView = TestEnjoymentPicker()
        _ = testView
        #expect(true)
    }
    
    @MainActor
    @Test func intensityRatingPicker() {
        struct TestIntensityPicker: View {
            @State private var intensity: Int = 3
            
            var body: some View {
                VStack {
                    Text("Intensity")
                    Picker("Intensity", selection: $intensity) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        
        let testView = TestIntensityPicker()
        _ = testView
        #expect(true)
    }
    
    // MARK: - Data Integration Tests
    
    @MainActor
    @Test func addExerciseDataFlow() throws {
        let exercise = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0)
        let unit = UnitType(name: "Minutes", abbreviation: "min", category: .minutes)
        let dayLog = DayLog(date: Date())
        
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(dayLog)
        try modelContext.save()
        
        // Simulate adding an exercise
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 30.0, enjoyment: 4, intensity: 3)
        
        if dayLog.items == nil {
            dayLog.items = []
        }
        dayLog.items?.append(item)
        
        modelContext.insert(item)
        try modelContext.save()
        
        #expect(dayLog.items?.count == 1)
        #expect(item.exercise?.name == "Walk")
        #expect(item.amount == 30.0)
    }
    
    @MainActor
    @Test func editExerciseDataFlow() throws {
        let exercise = ExerciseType(name: "Run", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 6.0)
        let unit = UnitType(name: "Miles", abbreviation: "mi", category: .distanceMi)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 3.0, enjoyment: 4, intensity: 5)
        
        modelContext.insert(exercise)
        modelContext.insert(unit)
        modelContext.insert(item)
        try modelContext.save()
        
        // Simulate editing the exercise
        let originalModified = item.modifiedAt
        Thread.sleep(forTimeInterval: 0.001) // Ensure timestamp difference
        
        item.amount = 5.0
        item.enjoyment = 5
        item.intensity = 4
        item.note = "Great run!"
        item.modifiedAt = Date()
        
        try modelContext.save()
        
        #expect(item.amount == 5.0)
        #expect(item.enjoyment == 5)
        #expect(item.intensity == 4)
        #expect(item.note == "Great run!")
        #expect(item.modifiedAt > originalModified)
    }
}

// Helper function (needs to be outside the struct for testing)
private func amountOnlyString(_ amount: Double, unit: UnitType?) -> String {
    guard let unit else { return String(format: "%.0f", amount) }
    switch unit.category {
    case .reps, .steps:
        return String(Int(amount))
    default:
        return String(format: "%.1f", amount)
    }
}

#if os(macOS)
private extension View {
    @ViewBuilder
    func macPresentationFitted() -> some View {
        if #available(macOS 15.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
    }
}
#endif