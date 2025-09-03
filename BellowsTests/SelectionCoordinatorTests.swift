import Testing
@testable import Bellows

// Local copy to avoid module visibility surprises
private struct TestSelectionCoordinator {
    static func shouldPresentNewExercise(for selected: ExerciseType?) -> Bool { selected == nil }
    static func shouldPresentNewUnit(for selected: UnitType?) -> Bool { selected == nil }
    static func nextUnit(for exercise: ExerciseType?, from units: [UnitType], previous: UnitType?) -> UnitType? {
        guard let exercise else { return previous ?? units.first }
        // Only prefer an algorithmic match when the exercise actually has a declared default
        if exercise.defaultUnit != nil || exercise.defaultUnitCategory != nil {
            if let match = findBestMatchingUnit(for: exercise, from: units) { return match }
        }
        // Otherwise, keep the user's previous choice if available, falling back to first
        return previous ?? units.first
    }
}

struct SelectionCoordinatorTests {
    @Test func presentsNewSheetsOnNilSelections() {
        #expect(TestSelectionCoordinator.shouldPresentNewExercise(for: nil))
        #expect(TestSelectionCoordinator.shouldPresentNewUnit(for: nil))
    }

    @Test func doesNotPresentWhenSelectionsExist() {
        let ex = ExerciseType(name: "Run", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 6.0, defaultUnit: nil)
        let u = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        #expect(!TestSelectionCoordinator.shouldPresentNewExercise(for: ex))
        #expect(!TestSelectionCoordinator.shouldPresentNewUnit(for: u))
    }

    @Test func nextUnitSelectsBestMatch() {
        let walk = ExerciseType(name: "Walk", baseMET: 3.3, repWeight: 0.15, defaultPaceMinPerMi: 12.0, defaultUnit: nil)
        let minutes = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let reps = UnitType(name: "Reps", abbreviation: "reps", stepSize: 1.0, displayAsInteger: true)
        // Make walk prefer a time-like unit via legacy category
        walk.defaultUnitCategory = .time
        let chosen = TestSelectionCoordinator.nextUnit(for: walk, from: [reps, minutes], previous: nil)
        #expect(chosen?.name == "Minutes")
    }

    @Test func nextUnitFallsBackToPreviousThenFirst() {
        let ex = ExerciseType(name: "Other", baseMET: 4.0, repWeight: 0.15, defaultPaceMinPerMi: 10.0, defaultUnit: nil)
        let u1 = UnitType(name: "Miles", abbreviation: "mi", stepSize: 0.1, displayAsInteger: false)
        let u2 = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        let previous = u2
        let chosen = TestSelectionCoordinator.nextUnit(for: ex, from: [u1, u2], previous: previous)
        #expect(chosen?.name == "Minutes")
        let chosen2 = TestSelectionCoordinator.nextUnit(for: ex, from: [u1, u2], previous: nil)
        #expect(chosen2?.name == "Miles")
    }
}
