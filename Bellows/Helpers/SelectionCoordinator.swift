import Foundation

struct SelectionCoordinator {
    static func shouldPresentNewExercise(for selected: ExerciseType?) -> Bool { selected == nil }
    static func shouldPresentNewUnit(for selected: UnitType?) -> Bool { selected == nil }

    static func nextUnit(for exercise: ExerciseType?, from units: [UnitType], previous: UnitType?) -> UnitType? {
        guard let exercise else { return previous ?? units.first }
        if let match = findBestMatchingUnit(for: exercise, from: units) { return match }
        return previous ?? units.first
    }
}

