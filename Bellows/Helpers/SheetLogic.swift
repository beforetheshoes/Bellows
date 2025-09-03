import Foundation
import SwiftData

// Pure helpers so tests can validate sheet presentation logic
func shouldShowNewExerciseSheet(for selected: ExerciseType?) -> Bool { selected == nil }
func shouldShowNewUnitSheet(for selected: UnitType?) -> Bool { selected == nil }

