import Foundation
import SwiftData

// Lightweight re-exports of test helper entry points to guarantee availability in the Bellows module.
// These mirror the implementations in Helpers/TestHelpers.swift and are marked @MainActor.

@MainActor
public func __test_newExerciseTypeSave(context: ModelContext, name: String, iconSystemName: String?, defaultUnitCategory: UnitCategory? = nil) {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    do {
        let all = try context.fetch(FetchDescriptor<ExerciseType>())
        if !all.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            let e = ExerciseType(name: trimmed, baseMET: 4.0, repWeight: 0.15, defaultPaceMinPerMi: 10.0, iconSystemName: iconSystemName, defaultUnitCategory: defaultUnitCategory)
            context.insert(e)
        }
        try context.save()
    } catch {
        print("ERROR: __test_newExerciseTypeSave failed: \(error)")
    }
}

@MainActor
public func __test_newUnitTypeSave(context: ModelContext, name: String, abbreviation: String, stepSize: Double, displayAsInteger: Bool) {
    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    let trimmedAbbr = abbreviation.trimmingCharacters(in: .whitespaces)
    do {
        let all = try context.fetch(FetchDescriptor<UnitType>())
        if let existing = all.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            existing.abbreviation = trimmedAbbr
            existing.stepSize = stepSize
            existing.displayAsInteger = displayAsInteger
        } else {
            let u = UnitType(name: trimmedName, abbreviation: trimmedAbbr, stepSize: stepSize, displayAsInteger: displayAsInteger)
            context.insert(u)
        }
        try context.save()
    } catch {
        print("ERROR: __test_newUnitTypeSave failed: \(error)")
    }
}

// Public shim to access internal fitness symbols list from tests without widening access on the enum.
@inlinable
public func __test_allFitnessSymbols() -> [String] {
    return SFFitnessSymbols.all
}
