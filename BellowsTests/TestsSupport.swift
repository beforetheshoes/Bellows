import Foundation
import SwiftData
@testable import Bellows

// Re-export minimal helpers for tests to avoid symbol visibility issues.
@MainActor
func __test_newExerciseTypeSave(context: ModelContext, name: String, iconSystemName: String?, defaultUnitCategory: UnitCategory? = nil) {
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
func __test_newUnitTypeSave(context: ModelContext, name: String, abbreviation: String, stepSize: Double, displayAsInteger: Bool) {
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

@MainActor
func __test_addExercise(context: ModelContext, date: Date, dayLog: DayLog?, exercise: ExerciseType, unit: UnitType, amount: Double, enjoyment: Int, intensity: Int, note: String?) {
    let targetDayLog: DayLog
    do {
        if let dayLog = dayLog {
            targetDayLog = dayLog
        } else {
            let start = date.startOfDay()
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
            let logs = try context.fetch(FetchDescriptor<DayLog>())
            if let existing = logs.first(where: { $0.date >= start && $0.date < end }) {
                targetDayLog = existing
            } else {
                let newDayLog = DayLog(date: date.startOfDay())
                context.insert(newDayLog)
                targetDayLog = newDayLog
            }
        }

        let item = ExerciseItem(
            exercise: exercise,
            unit: unit,
            amount: amount,
            note: (note ?? "").isEmpty ? nil : note,
            enjoyment: enjoyment,
            intensity: intensity
        )

        if targetDayLog.items == nil { targetDayLog.items = [] }
        targetDayLog.items?.append(item)
        try context.save()
    } catch {
        print("ERROR: __test_addExercise failed: \(error)")
    }
}

@MainActor
func __test_editExerciseSave(context: ModelContext, item: ExerciseItem, exercise: ExerciseType?, unit: UnitType?, amount: Double, enjoyment: Int, intensity: Int, note: String?) {
    item.exercise = exercise
    item.unit = unit
    item.amount = amount
    item.enjoyment = enjoyment
    item.intensity = intensity
    item.note = (note ?? "").isEmpty ? nil : note
    item.modifiedAt = Date()
    try? context.save()
}
