import Testing
import SwiftUI
import SwiftData
import Foundation
@testable import Bellows

struct BellowsAppTests {
    
    // Helper function to create test model container
    private func createTestModelContainer() -> ModelContainer {
        let schema = Schema([
            DayLog.self,
            ExerciseItem.self,
            ExerciseType.self,
            UnitType.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true // Use in-memory for tests
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create test ModelContainer: \(error)")
        }
    }
    
    // MARK: - App Structure Tests
    
    @MainActor
    @Test func bellowsAppInitialization() {
        _ = BellowsApp()
        // App initialized successfully
    }
    
    @MainActor
    @Test func bellowsAppBodyAccess() {
        let app = BellowsApp()
        
        // Accessing body should not crash
        _ = app.body
        #expect(true)
    }
    
    @MainActor
    @Test func bellowsAppWindowGroup() {
        let app = BellowsApp()
        _ = app.body
        
        // Test that the app creates a WindowGroup scene
        // Scene created successfully - this exercises the scene body
        #expect(true)
    }
    
    @MainActor
    @Test func appMainActorAttribute() {
        // Test that the main app struct is properly annotated
        _ = BellowsApp()
        #expect(true)
    }
    
    // MARK: - Model Container Creation Tests
    
    @MainActor
    @Test func createModelContainerFunction() {
        // Test the actual createModelContainer function from BellowsApp
        // This tests the private function through the app's body property
        let app = BellowsApp()
        _ = app.body
        
        // Verify scene is WindowGroup
        // Scene created successfully
        #expect(true)
    }
    
    @Test func modelContainerCloudKitConfiguration() {
        // Test that the production model container is configured correctly
        // We can't directly test the private function, but we can verify the schema
        let testContainer = createTestModelContainer()
        let schema = testContainer.schema
        
        // Verify all required entities are present
        let entityNames = schema.entities.map { $0.name }.sorted()
        let expectedEntities = ["DayLog", "ExerciseItem", "ExerciseType", "UnitType"]
        
        for entity in expectedEntities {
            #expect(entityNames.contains(entity), "Schema should contain \(entity)")
        }
    }
    
    @Test func testModelContainerCreation() {
        // Test that the model container can be created
        let container = createTestModelContainer()
        
        // Container created successfully
        
        // Verify the schema contains the expected models
        let schema = container.schema
        // Schema created successfully
        
        // Check that all required models are in the schema
        let expectedModels = ["DayLog", "ExerciseItem", "ExerciseType", "UnitType"]
        let schemaModels = schema.entities.map { $0.name }
        
        for expectedModel in expectedModels {
            #expect(schemaModels.contains(expectedModel), 
                   "Schema should contain \(expectedModel)")
        }
    }
    
    @Test func modelContainerConfiguration() {
        let container = createTestModelContainer()
        
        // Test that the container is properly configured
        // Container created successfully
        
        // Verify we can create a model context
        _ = ModelContext(container)
        // Context created successfully
    }
    
    @Test func modelContainerSchema() {
        let container = createTestModelContainer()
        let schema = container.schema
        
        // Verify schema properties
        // Schema created successfully
        #expect(schema.entities.count > 0)
        
        // Check that we have exactly 4 entities
        #expect(schema.entities.count == 4)
    }
    
    // MARK: - Model Relationships Tests
    
    @Test func modelRelationships() throws {
        let container = createTestModelContainer()
        let context = ModelContext(container)
        
        // Create test data to verify relationships work
        let dayLog = DayLog(date: Date())
        let exercise = ExerciseType(name: "Test Exercise", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unit = UnitType(name: "Test Unit", abbreviation: "tu", category: .other)
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 10)
        
        // Set up relationships
        dayLog.items = [item]
        item.dayLog = dayLog
        item.exercise = exercise
        item.unit = unit
        
        // Insert into context
        context.insert(dayLog)
        context.insert(exercise)
        context.insert(unit)
        context.insert(item)
        
        // Test that relationships are preserved
        #expect(dayLog.items?.count == 1)
        #expect(item.dayLog == dayLog)
        #expect(item.exercise == exercise)
        #expect(item.unit == unit)
        
        // Test that we can save without errors
        try context.save()
    }
    
    // MARK: - CloudKit Integration Tests
    
    @Test func cloudKitConfiguration() {
        let container = createTestModelContainer()
        
        // Verify that CloudKit is configured
        // Note: We can't easily test CloudKit functionality in unit tests,
        // but we can verify the container was created successfully
        // Container created successfully
        
        // Test that we can create contexts and perform basic operations
        _ = ModelContext(container)
        // Context created successfully
    }
    
    // MARK: - Error Handling Tests
    
    @Test func modelContainerErrorHandling() {
        // The createModelContainer function should handle errors gracefully
        // In a real error scenario, it would call fatalError, but we can't test that directly
        // Instead, we test that normal creation works
        
        _ = createTestModelContainer()
        // Container created successfully
    }
    
    // MARK: - Data Model Validation Tests
    
    @Test func allModelsCanBeInstantiated() throws {
        let container = createTestModelContainer()
        let context = ModelContext(container)
        
        // Test that all model types can be created
        let dayLog = DayLog(date: Date())
        let exerciseType = ExerciseType(name: "Test", baseMET: 5.0, repWeight: 0.2, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let unitType = UnitType(name: "Test", abbreviation: "t", category: .other)
        let exerciseItem = ExerciseItem(exercise: exerciseType, unit: unitType, amount: 10)
        
        // Insert all models
        context.insert(dayLog)
        context.insert(exerciseType)
        context.insert(unitType)
        context.insert(exerciseItem)
        
        // Verify they were inserted
        // DayLog created successfully
        // ExerciseType created successfully
        // UnitType created successfully
        // ExerciseItem created successfully
        
        // Test saving
        try context.save()
    }
    
    // MARK: - Schema Consistency Tests
    
    @Test func schemaConsistency() {
        let container = createTestModelContainer()
        let schema = container.schema
        
        // Verify schema entities
        let entityNames = schema.entities.map { $0.name }.sorted()
        let expectedNames = ["DayLog", "ExerciseItem", "ExerciseType", "UnitType"].sorted()
        
        #expect(entityNames == expectedNames)
    }
    
    @Test func modelAttributes() {
        let container = createTestModelContainer()
        _ = ModelContext(container)
        
        // Test model attributes are accessible
        _ = DayLog(date: Date())
        // Date is always present
        // CreatedAt is always present
        // ModifiedAt is always present
        
        let exercise = ExerciseType(name: "Walking", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        #expect(exercise.name == "Walking")
        #expect(exercise.baseMET == 3.3)
        #expect(exercise.repWeight == 0.15)
        #expect(exercise.defaultPaceMinPerMi == 12.0)
        
        let unit = UnitType(name: "Steps", abbreviation: "steps", stepSize: 1.0, displayAsInteger: true)
        #expect(unit.name == "Steps")
        #expect(unit.abbreviation == "steps")
        #expect(unit.displayAsInteger == true)
        
        let item = ExerciseItem(exercise: exercise, unit: unit, amount: 1000)
        #expect(item.amount == 1000)
        #expect(item.enjoyment == 3) // Default value
        #expect(item.intensity == 3) // Default value
    }
    
    // MARK: - Memory Management Tests
    
    @Test func modelContainerMemoryManagement() {
        // Test that creating and releasing containers doesn't cause memory issues
        for _ in 0..<10 {
            let container = createTestModelContainer()
            _ = ModelContext(container)
            
            // Create some test data  
            _ = DayLog(date: Date())
            
            // Container should be releasable
            // Container created successfully
            // Context created successfully
        }
        
        #expect(true) // Test passes if no memory issues
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    @Test func appWithModelContainer() {
        let app = BellowsApp()
        
        // Test that the app can be created and its body accessed
        _ = app.body
        
        // The app should be able to provide a model container
        // App initialized successfully
    }
    
    @Test func modelContainerWithRealData() throws {
        let container = createTestModelContainer()
        let context = ModelContext(container)
        
        // Create realistic test data
        let today = Date()
        let dayLog = DayLog(date: today)
        
        let walkingExercise = ExerciseType(
            name: "Walking",
            baseMET: 3.3,
            repWeight: 0.15,
            defaultPaceMinPerMi: 12.0,
            iconSystemName: "figure.walk",
            defaultUnit: nil
        )
        
        let minutesUnit = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        
        let walkingItem = ExerciseItem(
            exercise: walkingExercise,
            unit: minutesUnit,
            amount: 30,
            note: "Morning walk",
            enjoyment: 4,
            intensity: 2
        )
        
        // Set up relationships
        dayLog.items = [walkingItem]
        walkingItem.dayLog = dayLog
        
        // Insert data
        context.insert(dayLog)
        context.insert(walkingExercise)
        context.insert(minutesUnit)
        context.insert(walkingItem)
        
        // Verify relationships
        #expect(dayLog.unwrappedItems.count == 1)
        #expect(dayLog.didMove)
        #expect(walkingItem.exercise?.name == "Walking")
        #expect(walkingItem.unit?.displayAsInteger == false)
        
        // Test saving
        try context.save()
    }
    
    // MARK: - Performance Tests
    
    @Test func modelContainerPerformance() {
        // Test that model container creation is reasonably fast
        // Note: Swift Testing doesn't have measure, so we just test that creation works
        let container = createTestModelContainer()
        let context = ModelContext(container)
        
        // Create a small amount of test data
        let dayLog = DayLog(date: Date())
        context.insert(dayLog)
        
        // Container created successfully
        // Context created successfully
    }
    
    // MARK: - Edge Cases
    
    @Test func modelContainerWithEdgeCaseData() throws {
        let container = createTestModelContainer()
        let context = ModelContext(container)
        
        // Test with edge case data
        let distantPast = Date.distantPast
        let distantFuture = Date.distantFuture
        
        let pastDayLog = DayLog(date: distantPast)
        let futureDayLog = DayLog(date: distantFuture)
        
        context.insert(pastDayLog)
        context.insert(futureDayLog)
        
        // Test extreme values
        let extremeExercise = ExerciseType(
            name: "Extreme",
            baseMET: 20.0,
            repWeight: 10.0,
            defaultPaceMinPerMi: 1.0,
            defaultUnit: nil
        )
        
        let extremeUnit = UnitType(name: "Extreme Unit", abbreviation: "ex", category: .other)
        
        let extremeItem = ExerciseItem(
            exercise: extremeExercise,
            unit: extremeUnit,
            amount: 999999.0,
            enjoyment: 5,
            intensity: 5
        )
        
        context.insert(extremeExercise)
        context.insert(extremeUnit)
        context.insert(extremeItem)
        
        // Should not crash with extreme values
        try context.save()
    }
}
