import SwiftUI
import SwiftData

@MainActor
struct ExerciseSelectionSection: View {
    let filteredExerciseTypes: [ExerciseType]
    let filteredUnitTypes: [UnitType]
    @Binding var selectedExercise: ExerciseType?
    @Binding var selectedUnit: UnitType?
    @Binding var amount: Double
    @Binding var showingNewExerciseType: Bool
    @Binding var showingNewUnitType: Bool
    @Binding var previousSelectedExercise: ExerciseType?
    @Binding var previousSelectedUnit: UnitType?
    
    var body: some View {
        Section("Exercise") {
            LabeledContent("Exercise") {
                Picker("Exercise", selection: $selectedExercise) {
                    Text("Add New Exercise…").tag(nil as ExerciseType?)
                    Divider()
                    ForEach(filteredExerciseTypes) { exercise in
                        Text(exercise.name).tag(Optional(exercise))
                    }
                }
                .labelsHidden()
            }
            
            LabeledContent("Unit") {
                Picker("Unit", selection: $selectedUnit) {
                    Text("Add New Unit…").tag(nil as UnitType?)
                    ForEach(filteredUnitTypes) { unit in
                        Text(unit.name).tag(Optional(unit))
                    }
                }
                .labelsHidden()
            }
            
            LabeledContent("Amount") {
                HStack {
                    Text(amountOnlyString(amount, unit: selectedUnit))
                        .monospacedDigit()
                        .fontWeight(.medium)
                    Spacer()
                    Stepper("", value: $amount, in: 0...10_000, step: stepForUnit(selectedUnit))
                        .labelsHidden()
                }
            }
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius)
                .fill(DS.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius)
                        .stroke(DS.ColorToken.accent, lineWidth: 3)
                )
                .padding(.vertical, 2)
        )
        .onChange(of: selectedExercise?.persistentModelID) { oldID, newID in
            if selectedExercise == nil {
                showingNewExerciseType = true
                selectedExercise = previousSelectedExercise ?? filteredExerciseTypes.first
            } else {
                previousSelectedExercise = selectedExercise
                
                if oldID != newID, let exercise = selectedExercise {
                    if let bestUnit = findBestMatchingUnit(for: exercise, from: filteredUnitTypes) {
                        selectedUnit = bestUnit
                        previousSelectedUnit = bestUnit
                    }
                }
            }
        }
        .onChange(of: selectedUnit?.persistentModelID) { _, _ in
            if selectedUnit == nil {
                showingNewUnitType = true
                selectedUnit = previousSelectedUnit ?? filteredUnitTypes.first
            } else {
                previousSelectedUnit = selectedUnit
            }
        }
    }
}
