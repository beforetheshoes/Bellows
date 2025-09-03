import SwiftUI
import SwiftData

// Helper function for default unit selection
func findBestMatchingUnit(for exercise: ExerciseType, from units: [UnitType]) -> UnitType? {
    guard !units.isEmpty else { return nil }
    
    // If exercise has a directly specified default unit, try to find it in the available units
    if let defaultUnit = exercise.defaultUnit {
        // First try to find by object identity
        if let matchingUnit = units.first(where: { $0 === defaultUnit }) {
            return matchingUnit
        }
        
        // Then try to find by persistent model ID (if available)
        if let matchingUnit = units.first(where: { $0.persistentModelID == defaultUnit.persistentModelID }) {
            return matchingUnit
        }
        
        // If the exact unit isn't available, try to find one with the same name
        let defaultUnitName = defaultUnit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let matchingByName = units.first(where: { unit in
            let unitName = unit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return unitName == defaultUnitName
        }) {
            return matchingByName
        }
        
        // Additional fallback: try partial name matching with preference for the target pattern
        // First try to find units that contain the expected name
        if let partialMatch = units.first(where: { unit in
            let unitName = unit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return unitName.contains(defaultUnitName)
        }) {
            return partialMatch
        }
        
        // Then try the reverse (default name contains unit name)
        if let reverseMatch = units.first(where: { unit in
            let unitName = unit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return defaultUnitName.contains(unitName)
        }) {
            return reverseMatch
        }
    }
    
    // Migration support: If exercise still has a default unit category, find the first unit that matches the expected properties for that category
    if let defaultCategory = exercise.defaultUnitCategory {
        let expectedStepSize: Double
        let expectedDisplayAsInteger: Bool
        
        switch defaultCategory {
        case .time:
            expectedStepSize = 0.5
            expectedDisplayAsInteger = false
        case .distance:
            expectedStepSize = 0.1
            expectedDisplayAsInteger = false
        case .reps, .steps:
            expectedStepSize = 1.0
            expectedDisplayAsInteger = true
        case .other:
            expectedStepSize = 1.0
            expectedDisplayAsInteger = false
        }
        
        if let matchingUnit = units.first(where: { $0.stepSize == expectedStepSize && $0.displayAsInteger == expectedDisplayAsInteger }) {
            return matchingUnit
        }
    }
    
    // Fallback to first unit if no match found
    return units.first
}

func amountOnlyString(_ amount: Double, unit: UnitType?) -> String {
    guard let unit else { return String(format: "%.1f", amount) }
    
    if unit.displayAsInteger {
        return String(Int(amount.rounded()))
    } else {
        return String(format: "%.1f", amount)
    }
}

func stepForUnit(_ unit: UnitType?) -> Double {
    return unit?.stepSize ?? 1.0
}