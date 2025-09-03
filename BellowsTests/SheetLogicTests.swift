import Testing
import SwiftData
@testable import Bellows

// Local pure helpers to avoid target membership surprises
private func shouldShowNewExerciseSheet(for selected: ExerciseType?) -> Bool { selected == nil }
private func shouldShowNewUnitSheet(for selected: UnitType?) -> Bool { selected == nil }

struct SheetLogicTests {
    @Test func newExerciseSheetOpensOnNilSelection() {
        let selected: ExerciseType? = nil
        #expect(shouldShowNewExerciseSheet(for: selected) == true)
    }

    @Test func newExerciseSheetDoesNotOpenWithSelection() {
        let ex = ExerciseType(name: "Run", baseMET: 9.8, repWeight: 0.15, defaultPaceMinPerMi: 6.0, defaultUnit: nil)
        #expect(shouldShowNewExerciseSheet(for: ex) == false)
    }

    @Test func newUnitSheetOpensOnNilSelection() {
        let selected: UnitType? = nil
        #expect(shouldShowNewUnitSheet(for: selected) == true)
    }

    @Test func newUnitSheetDoesNotOpenWithSelection() {
        let u = UnitType(name: "Minutes", abbreviation: "min", stepSize: 0.5, displayAsInteger: false)
        #expect(shouldShowNewUnitSheet(for: u) == false)
    }
}
