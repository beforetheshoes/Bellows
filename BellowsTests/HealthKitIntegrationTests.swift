import Testing
import SwiftData
import HealthKit
@testable import Bellows

struct HealthKitIntegrationTests {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init() {
        do {
            modelContainer = try ModelContainer(
                for: DayLog.self, ExerciseItem.self, ExerciseType.self, UnitType.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - HealthKit Activity Type Mapping Tests
    
    @MainActor
    @Test func healthKitActivityTypeMapping() {
        let service = HealthKitService()
        
        // Test core mappings that should exist in Bellows
        #expect(service.mapActivityTypeToExerciseName(.walking) == "Walk")
        #expect(service.mapActivityTypeToExerciseName(.running) == "Run")
        #expect(service.mapActivityTypeToExerciseName(.cycling) == "Cycling")
        #expect(service.mapActivityTypeToExerciseName(.yoga) == "Yoga")
        
        // Test fallback for unmapped activities
        #expect(service.mapActivityTypeToExerciseName(.tennis) == "Other")
        #expect(service.mapActivityTypeToExerciseName(.boxing) == "Other")
    }
    
    @MainActor
    @Test func healthKitWorkoutConversion() {
        // Setup test data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let service = HealthKitService()
        
        // Create mock workout data
        let startDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let endDate = Date()
        let duration = TimeInterval(3600) // 1 hour
        
        // Test workout conversion - using mock helper for testing
        let mockWorkout = MockHKWorkout(
            activityType: .running,
            start: startDate,
            end: endDate,
            duration: duration,
            totalDistance: HKQuantity(unit: .mile(), doubleValue: 5.0),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 400)
        )
        
        let result = service.convertWorkoutToExerciseItems(
            workout: mockWorkout,
            modelContext: modelContext
        )
        
        #expect(result.count == 1)
        
        let exerciseItem = result[0]
        #expect(exerciseItem.exercise?.name == "Run")
        #expect(exerciseItem.unit?.name == "Minutes") 
        #expect(exerciseItem.amount == 60.0) // 1 hour = 60 minutes
        #expect(exerciseItem.intensity == 3) // Default neutral intensity
        #expect(exerciseItem.enjoyment == 3) // Default neutral enjoyment
    }
    
    @MainActor
    @Test func healthKitWorkoutWithoutDistance() {
        // Setup test data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let service = HealthKitService()
        
        // Create workout without distance (like yoga)
        let startDate = Date().addingTimeInterval(-1800) // 30 minutes ago
        let endDate = Date()
        let duration = TimeInterval(1800) // 30 minutes
        
        // Use MockHKWorkout (WorkoutProtocol) for unit tests; HKWorkoutBuilder requires HealthKit auth
        let mockWorkout = MockHKWorkout(
            activityType: .yoga,
            start: startDate,
            end: endDate,
            duration: duration,
            totalDistance: nil, // No distance for yoga
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 150)
        )
        
        let result = service.convertWorkoutToExerciseItems(
            workout: mockWorkout,
            modelContext: modelContext
        )
        
        #expect(result.count == 1)
        
        let exerciseItem = result[0]
        #expect(exerciseItem.exercise?.name == "Yoga")
        #expect(exerciseItem.unit?.name == "Minutes")
        #expect(exerciseItem.amount == 30.0) // 30 minutes
    }
    
    @MainActor 
    @Test func healthKitPermissionStatus() {
        let service = HealthKitService()
        
        // Test that service correctly identifies required permissions
        let requiredTypes = service.requiredHealthKitTypes()
        #expect(requiredTypes.contains(.workoutType()))
        #expect(requiredTypes.count > 0)
    }
    
    @MainActor
    @Test func healthKitDataImportNonDestructive() {
        // Setup existing data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let today = Date().startOfDay()
        let dayLog = DayLog(date: today)
        modelContext.insert(dayLog)
        
        // Add existing exercise
        let walkType = try! modelContext.fetch(FetchDescriptor<ExerciseType>()).first { $0.name == "Walk" }!
        let minutesUnit = try! modelContext.fetch(FetchDescriptor<UnitType>()).first { $0.name == "Minutes" }!
        
        let existingItem = ExerciseItem(
            exercise: walkType,
            unit: minutesUnit, 
            amount: 30.0,
            enjoyment: 4,
            intensity: 2
        )
        dayLog.items = [existingItem]
        
        try! modelContext.save()
        
        // Import HealthKit workout for same day
        let service = HealthKitService()
        // Use MockHKWorkout (WorkoutProtocol) for unit tests; HKWorkoutBuilder requires HealthKit auth
        let mockWorkout = MockHKWorkout(
            activityType: .running,
            start: today.addingTimeInterval(3600), // Later in the day
            end: today.addingTimeInterval(7200),
            duration: 3600,
            totalDistance: HKQuantity(unit: .mile(), doubleValue: 3.0),
            totalEnergyBurned: nil
        )
        
        service.importWorkouts([mockWorkout], to: dayLog, modelContext: modelContext)
        
        try! modelContext.save()
        
        // Verify both exercises exist
        let updatedDayLog = try! modelContext.fetch(FetchDescriptor<DayLog>()).first!
        #expect(updatedDayLog.unwrappedItems.count == 2)
        
        // Original item should be unchanged
        let originalItem = updatedDayLog.unwrappedItems.first { $0.exercise?.name == "Walk" }
        #expect(originalItem != nil)
        #expect(originalItem?.enjoyment == 4)
        #expect(originalItem?.intensity == 2)
        
        // New item should have import metadata
        let importedItem = updatedDayLog.unwrappedItems.first { $0.exercise?.name == "Run" }
        #expect(importedItem != nil)
        #expect(importedItem?.note?.contains("Imported from Apple Health") == true)
    }
    
    @MainActor
    @Test func healthKitImportReversible() {
        // Setup test data
        SeedService.seedDefaultUnits(context: modelContext)
        SeedService.seedDefaultExercises(context: modelContext)
        
        let today = Date().startOfDay()
        let dayLog = DayLog(date: today)
        modelContext.insert(dayLog)
        
        let service = HealthKitService()
        // Use MockHKWorkout (WorkoutProtocol) for unit tests; HKWorkoutBuilder requires HealthKit auth
        let mockWorkout = MockHKWorkout(
            activityType: .cycling,
            start: today,
            end: today.addingTimeInterval(3600),
            duration: 3600,
            totalDistance: HKQuantity(unit: .mile(), doubleValue: 10.0),
            totalEnergyBurned: nil
        )
        
        // Import workout
        service.importWorkouts([mockWorkout], to: dayLog, modelContext: modelContext)
        try! modelContext.save()
        
        // Verify import
        let importedItems = dayLog.unwrappedItems.filter { service.isImportedFromHealthKit($0) }
        #expect(importedItems.count == 1)
        
        // Remove imported items
        service.removeHealthKitImports(from: dayLog, modelContext: modelContext)
        try! modelContext.save()
        
        // Verify removal
        let remainingImports = dayLog.unwrappedItems.filter { service.isImportedFromHealthKit($0) }
        #expect(remainingImports.count == 0)
    }
}

// MockHKWorkout is provided by TestsSupport.swift for reuse across tests.
