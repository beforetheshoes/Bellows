import SwiftUI
import SwiftData
import Foundation

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
        
        // Additional fallback: normalized name similarity (handles "mins" vs "minutes", "minute(s)", punctuation)
        func normalize(_ s: String) -> String {
            var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            t = t.replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression)
            if t.hasSuffix("s") { t.removeLast() } // naive singularization
            return t
        }
        let target = normalize(defaultUnit.name)

        // Exact normalized equality
        if let eq = units.first(where: { normalize($0.name) == target }) { return eq }

        // Contains (either direction) on normalized forms
        if let contains = units.first(where: {
            let n = normalize($0.name)
            return n.contains(target) || target.contains(n)
        }) { return contains }

        // Common prefix length heuristic (>= 3)
        if let pref = units.first(where: {
            let n = normalize($0.name)
            let common = String(zip(n, target).prefix { $0 == $1 }.map { $0.0 })
            return common.count >= 3
        }) { return pref }
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
