import SwiftData
import Foundation

@MainActor
struct SeedService {
    static func seedDefaultExercises(context: ModelContext) {
        do {
            let defaults = SeedDefaults.exerciseTypes
            var existing = try context.fetch(FetchDescriptor<ExerciseType>())
            let allUnits = try context.fetch(FetchDescriptor<UnitType>())

            for (rawName, met, repW, pace, icon, defaultUnitName) in defaults {
                let name = rawName.trimmingCharacters(in: .whitespaces)
                if existing.first(where: { $0.name.lowercased() == name.lowercased() }) == nil {
                    // Find the default unit by name
                    let defaultUnit = defaultUnitName.map { unitName in
                        allUnits.first { $0.name.lowercased() == unitName.lowercased() }
                    } ?? nil

                    let e = ExerciseType(
                        name: name,
                        baseMET: met,
                        repWeight: repW,
                        defaultPaceMinPerMi: pace,
                        iconSystemName: icon,
                        defaultUnit: defaultUnit
                    )
                    context.insert(e)
                    existing.append(e)
                }
            }
            try context.save()
        } catch {
            print("ERROR: SeedService.seedDefaultExercises failed: \(error)")
        }
    }

    static func seedDefaultUnits(context: ModelContext) {
        do {
            let defaults = SeedDefaults.unitTypes
            var existing = try context.fetch(FetchDescriptor<UnitType>())
            for (rawName, rawAbbr, stepSize, displayAsInteger) in defaults {
                let name = rawName.trimmingCharacters(in: .whitespaces)
                let abbr = rawAbbr.trimmingCharacters(in: .whitespaces)
                if let found = existing.first(where: { $0.name.lowercased() == name.lowercased() }) {
                    // Update existing unit with new properties if they're using defaults
                    if found.abbreviation.trimmingCharacters(in: .whitespaces).isEmpty {
                        found.abbreviation = abbr
                    }
                    // Update step size and display format for existing units
                    found.stepSize = stepSize
                    found.displayAsInteger = displayAsInteger
                } else {
                    let u = UnitType(name: name, abbreviation: abbr, stepSize: stepSize, displayAsInteger: displayAsInteger)
                    context.insert(u)
                    existing.append(u)
                }
            }
            try context.save()
        } catch {
            print("ERROR: SeedService.seedDefaultUnits failed: \(error)")
        }
    }
}

