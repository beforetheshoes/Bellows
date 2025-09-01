import Testing
import SwiftData
import Foundation
@testable import Bellows

struct ModelsTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
        let schema = Schema([
            DayLog.self,
            ExerciseType.self,
            UnitType.self,
            ExerciseItem.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
    
    // MARK: - DayLog Tests
    
    @Test func dayLogInitialization() {
        let date = Date()
        let dayLog = DayLog(date: date)
        
        #expect(dayLog.date == date.startOfDay())
        // CreatedAt is always present
        // ModifiedAt is always present
        #expect(dayLog.unwrappedItems.isEmpty)
        #expect(!dayLog.didMove)
    }
    
    @Test func dayLogUnwrappedItems() {
        let dayLog = DayLog(date: Date())
        #expect(dayLog.unwrappedItems == [])
        
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        dayLog.items = [item]
        #expect(dayLog.unwrappedItems.count == 1)
    }
    
    @Test func dayLogDidMove() {
        let dayLog = DayLog(date: Date())
        #expect(!dayLog.didMove)
        
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        dayLog.items = [item]
        #expect(dayLog.didMove)
    }
    
    @Test func dayLogNotesProperty() {
        let dayLog = DayLog(date: Date())
        #expect(dayLog.notes == nil)
        
        dayLog.notes = "Test notes"
        #expect(dayLog.notes == "Test notes")
    }
    
    // MARK: - UnitCategory Tests
    
    @Test func unitCategoryAllCases() {
        let allCases = UnitCategory.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.minutes))
        #expect(allCases.contains(.reps))
        #expect(allCases.contains(.steps))
        #expect(allCases.contains(.distanceMi))
        #expect(allCases.contains(.other))
    }
    
    @Test func unitCategoryIdentifiable() {
        #expect(UnitCategory.minutes.id == "minutes")
        #expect(UnitCategory.reps.id == "reps")
        #expect(UnitCategory.steps.id == "steps")
        #expect(UnitCategory.distanceMi.id == "distanceMi")
        #expect(UnitCategory.other.id == "other")
    }
    
    @Test func unitCategoryRawValues() {
        #expect(UnitCategory.minutes.rawValue == "minutes")
        #expect(UnitCategory.reps.rawValue == "reps")
        #expect(UnitCategory.steps.rawValue == "steps")
        #expect(UnitCategory.distanceMi.rawValue == "distanceMi")
        #expect(UnitCategory.other.rawValue == "other")
    }
    
    // MARK: - UnitType Tests
    
    @Test func unitTypeInitialization() {
        let unit = UnitType(name: "Minutes", abbreviation: "min", category: .minutes)
        
        #expect(unit.name == "Minutes")
        #expect(unit.abbreviation == "min")
        #expect(unit.category == .minutes)
        // CreatedAt is always present
        #expect(unit.exerciseItems != nil)
    }
    
    @Test func unitTypeDefaultValues() {
        let unit = UnitType(name: "Test", abbreviation: "t", category: .other)
        #expect((unit.exerciseItems?.count ?? 0) == 0)
    }
    
    // MARK: - ExerciseType Tests
    
    @Test func exerciseTypeInitialization() {
        let exercise = ExerciseType(
            name: "Running",
            baseMET: 9.8,
            repWeight: 0.15,
            defaultPaceMinPerMi: 8.0,
            iconSystemName: "figure.run"
        )
        
        #expect(exercise.name == "Running")
        #expect(exercise.baseMET == 9.8)
        #expect(exercise.repWeight == 0.15)
        #expect(exercise.defaultPaceMinPerMi == 8.0)
        #expect(exercise.iconSystemName == "figure.run")
        // CreatedAt is always present
    }
    
    @Test func exerciseTypeWithoutIcon() {
        let exercise = ExerciseType(
            name: "Test",
            baseMET: 5.0,
            repWeight: 0.2,
            defaultPaceMinPerMi: 10.0
        )
        
        #expect(exercise.iconSystemName == nil)
    }
    
    // MARK: - ExerciseItem Tests
    
    @Test func exerciseItemFullInitialization() {
        let exercise = ExerciseType(name: "Pushups", baseMET: 8.0, repWeight: 0.6, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let item = ExerciseItem(
            exercise: exercise,
            unit: unit,
            amount: 20,
            note: "Felt good",
            enjoyment: 4,
            intensity: 3
        )
        
        #expect(item.exercise?.name == "Pushups")
        #expect(item.unit?.name == "Reps")
        #expect(item.amount == 20)
        #expect(item.note == "Felt good")
        #expect(item.enjoyment == 4)
        #expect(item.intensity == 3)
        // CreatedAt is always present
        // ModifiedAt is always present
    }
    
    @Test func exerciseItemIntensityOnlyInitialization() {
        let exercise = ExerciseType(name: "Yoga", baseMET: 2.5, repWeight: 0.15, defaultPaceMinPerMi: 10.0)
        let item = ExerciseItem(
            exercise: exercise,
            note: "Morning session",
            enjoyment: 5,
            intensity: 2
        )
        
        #expect(item.exercise?.name == "Yoga")
        #expect(item.unit == nil)
        #expect(item.amount == 0)
        #expect(item.note == "Morning session")
        #expect(item.enjoyment == 5)
        #expect(item.intensity == 2)
    }
    
    @Test func exerciseItemEnjoymentBounds() {
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        
        // Test lower bound
        let item1 = ExerciseItem(exercise: exercise, unit: unit, amount: 10, enjoyment: 0, intensity: 3)
        #expect(item1.enjoyment == 1)
        
        // Test upper bound
        let item2 = ExerciseItem(exercise: exercise, unit: unit, amount: 10, enjoyment: 10, intensity: 3)
        #expect(item2.enjoyment == 5)
        
        // Test within bounds
        let item3 = ExerciseItem(exercise: exercise, unit: unit, amount: 10, enjoyment: 3, intensity: 3)
        #expect(item3.enjoyment == 3)
    }
    
    @Test func exerciseItemIntensityBounds() {
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        
        // Test lower bound
        let item1 = ExerciseItem(exercise: exercise, unit: unit, amount: 10, enjoyment: 3, intensity: -5)
        #expect(item1.intensity == 1)
        
        // Test upper bound
        let item2 = ExerciseItem(exercise: exercise, unit: unit, amount: 10, enjoyment: 3, intensity: 100)
        #expect(item2.intensity == 5)
        
        // Test within bounds
        let item3 = ExerciseItem(exercise: exercise, unit: unit, amount: 10, enjoyment: 3, intensity: 4)
        #expect(item3.intensity == 4)
    }
    
    @Test func exerciseItemCustomDate() {
        let customDate = Date().addingTimeInterval(-86400) // Yesterday
        let exercise = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10, at: customDate)
        
        #expect(item.createdAt == customDate)
    }
    
    // MARK: - Date Extension Tests
    
    @Test func dateStartOfDay() {
        let calendar = Calendar.current
        let date = Date()
        let startOfDay = date.startOfDay()
        
        let components = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }
    
    @Test func dateStartOfDayWithCustomCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        
        let date = Date()
        let startOfDay = date.startOfDay(calendar: calendar)
        
        let components = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }
    
    // MARK: - SeedDefaults Tests
    
    @Test func seedDefaultsUnitTypes() {
        let unitTypes = SeedDefaults.unitTypes
        
        #expect(unitTypes.count == 5)
        
        // Check first unit type
        #expect(unitTypes[0].0 == "Minutes")
        #expect(unitTypes[0].1 == "min")
        #expect(unitTypes[0].2 == .minutes)
        
        // Check all categories are present
        let categories = unitTypes.map { $0.2 }
        #expect(categories.contains(.minutes))
        #expect(categories.contains(.reps))
        #expect(categories.contains(.steps))
        #expect(categories.contains(.distanceMi))
        #expect(categories.contains(.other))
    }
    
    @Test func seedDefaultsExerciseTypes() {
        let exerciseTypes = SeedDefaults.exerciseTypes
        
        #expect(exerciseTypes.count == 8)
        
        // Check first exercise type
        #expect(exerciseTypes[0].0 == "Walk")
        #expect(exerciseTypes[0].1 == 3.3)
        #expect(exerciseTypes[0].2 == 0.15)
        #expect(exerciseTypes[0].3 == 12.0)
        #expect(exerciseTypes[0].4 == "figure.walk")
        
        // Check that all have names
        for exercise in exerciseTypes {
            #expect(!exercise.0.isEmpty)
            #expect(exercise.1 > 0) // baseMET should be positive
            #expect(exercise.2 > 0) // repWeight should be positive
            #expect(exercise.3 > 0) // defaultPaceMinPerMi should be positive
        }
    }
    
    // MARK: - Integration Tests
    
    @Test func dayLogWithExerciseItems() {
        let dayLog = DayLog(date: Date())
        let exercise = ExerciseType(name: "Running", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 8.0)
        let unit = UnitType(name: "Miles", abbreviation: "mi", category: .distanceMi)
        
        let item1 = ExerciseItem(exercise: exercise, unit: unit, amount: 3.5)
        let item2 = ExerciseItem(exercise: exercise, unit: unit, amount: 2.0)
        
        dayLog.items = [item1, item2]
        item1.dayLog = dayLog
        item2.dayLog = dayLog
        
        #expect(dayLog.unwrappedItems.count == 2)
        #expect(dayLog.didMove)
        #expect(item1.dayLog?.date == dayLog.date)
        #expect(item2.dayLog?.date == dayLog.date)
    }
    
    @Test func exerciseTypeWithMultipleItems() {
        let exercise = ExerciseType(name: "Pushups", baseMET: 8.0, repWeight: 0.6, defaultPaceMinPerMi: 10.0)
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        
        let item1 = ExerciseItem(exercise: exercise, unit: unit, amount: 20)
        let item2 = ExerciseItem(exercise: exercise, unit: unit, amount: 15)
        let item3 = ExerciseItem(exercise: exercise, unit: unit, amount: 25)
        
        exercise.exerciseItems = [item1, item2, item3]
        
        #expect(exercise.exerciseItems?.count == 3)
    }
    
    @Test func unitTypeWithMultipleItems() {
        let unit = UnitType(name: "Reps", abbreviation: "reps", category: .reps)
        let exercise1 = ExerciseType(name: "Pushups", baseMET: 8.0, repWeight: 0.6, defaultPaceMinPerMi: 10.0)
        let exercise2 = ExerciseType(name: "Squats", baseMET: 5.0, repWeight: 0.25, defaultPaceMinPerMi: 10.0)
        
        let item1 = ExerciseItem(exercise: exercise1, unit: unit, amount: 20)
        let item2 = ExerciseItem(exercise: exercise2, unit: unit, amount: 15)
        
        unit.exerciseItems = [item1, item2]
        
        #expect(unit.exerciseItems?.count == 2)
    }
}