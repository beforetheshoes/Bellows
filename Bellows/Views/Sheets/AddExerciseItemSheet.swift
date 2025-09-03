import SwiftUI
import SwiftData

@MainActor
struct AddExerciseItemSheet: View {
    let date: Date
    let dayLog: DayLog?
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]
    
    @State private var selectedExercise: ExerciseType?
    @State private var selectedUnit: UnitType?
    @State private var amount: Double = 10
    @State private var enjoyment: Int = 3
    @State private var intensity: Int = 3
    @State private var note: String = ""
    @State private var showingNewExerciseType = false
    @State private var showingNewUnitType = false
    @State private var previousSelectedExercise: ExerciseType?
    @State private var previousSelectedUnit: UnitType?
    
    private var filteredExerciseTypes: [ExerciseType] {
        // De-duplicate by case-insensitive name, prefer latest createdAt
        let grouped = Dictionary(grouping: exerciseTypes) { $0.name.lowercased() }
        let unique = grouped.compactMap { _, dups in 
            dups.max { $0.createdAt < $1.createdAt } 
        }
        let filtered = unique.filter { $0.name.lowercased() != "other" }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var filteredUnitTypes: [UnitType] {
        let grouped = Dictionary(grouping: unitTypes) { $0.name.lowercased() }
        let unique = grouped.compactMap { _, dups in 
            dups.max { $0.createdAt < $1.createdAt } 
        }
        let filtered = unique.filter { $0.name.lowercased() != "other" }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Metrics.spacing) {
                    Text("Exercise").font(.headline)
                    SectionCard {
                        VStack(spacing: 12) {
                            // Exercise picker
                            HStack {
                                Text("Exercise")
                                Spacer()
                                Picker("", selection: $selectedExercise) {
                                    Text("Add New Exercise…").tag(nil as ExerciseType?)
                                    Divider()
                                    ForEach(filteredExerciseTypes) { exercise in
                                        Text(exercise.name).tag(Optional(exercise))
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            // Unit picker
                            HStack {
                                Text("Unit")
                                Spacer()
                                Picker("", selection: $selectedUnit) {
                                    Text("Add New Unit…").tag(nil as UnitType?)
                                    ForEach(filteredUnitTypes) { unit in
                                        Text(unit.name).tag(Optional(unit))
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            // Amount stepper
                            HStack {
                                Text("Amount")
                                Spacer()
                                HStack {
                                    Text(amountOnlyString(amount, unit: selectedUnit))
                                        .monospacedDigit()
                                        .fontWeight(.medium)
                                    Stepper("", value: $amount, in: 0...10_000, step: stepForUnit(selectedUnit))
                                        .labelsHidden()
                                }
                            }
                        }
                    }

                    // Ratings
                    Text("Ratings").font(.headline)
                    SectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("", selection: $enjoyment) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }
                                    .pickerStyle(.segmented)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("", selection: $intensity) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }
                                    .pickerStyle(.segmented)
                            }
                        }
                    }

                    // Note
                    Text("Note").font(.headline)
                    SectionCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Note").font(.caption).foregroundStyle(.secondary)
                            TextField("Optional", text: $note, axis: .vertical)
                                .font(.body)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Log Exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addExercise()
                        dismiss()
                    }
                    .disabled(selectedExercise == nil || selectedUnit == nil || amount <= 0)
                }
            }
            .onAppear {
                setupInitialSelections()
            }
                .sheet(isPresented: $showingNewExerciseType) {
                    NewExerciseTypeSheet { e in
                        selectedExercise = e
                        previousSelectedExercise = e
                    }
                }
            .sheet(isPresented: $showingNewUnitType) {
                NewUnitTypeSheet { u in
                    // Use async dispatch to ensure SwiftData @Query has updated
                    DispatchQueue.main.async {
                        // Find the unit in the updated filtered list, or use the passed unit as fallback
                        if let matchingUnit = filteredUnitTypes.first(where: { $0.name.lowercased() == u.name.lowercased() }) {
                            selectedUnit = matchingUnit
                            previousSelectedUnit = matchingUnit
                        } else {
                            // Fallback: use the original unit even if not in filtered list yet
                            selectedUnit = u
                            previousSelectedUnit = u
                        }
                    }
                }
            }
            // Present creation sheets when the nil options are chosen
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
            #if os(macOS)
            .macPresentationFitted()
            .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
            #endif
        }
    }
    
    private func setupInitialSelections() {
        // Auto-select first exercise if none selected
        if selectedExercise == nil && !filteredExerciseTypes.isEmpty { 
            selectedExercise = filteredExerciseTypes.first 
        }
        
        // Auto-select best matching unit based on exercise's default category
        if selectedUnit == nil, let exercise = selectedExercise {
            selectedUnit = findBestMatchingUnit(for: exercise, from: filteredUnitTypes)
        }
        if selectedUnit == nil && !filteredUnitTypes.isEmpty { 
            selectedUnit = filteredUnitTypes.first 
        }
        
        previousSelectedExercise = selectedExercise
        previousSelectedUnit = selectedUnit
    }
    
    private func addExercise() {
        guard let exercise = selectedExercise, let unit = selectedUnit else { return }
        
        // Create or find the DayLog for this date
        let targetDayLog: DayLog
        if let existing = dayLog {
            targetDayLog = existing
        } else {
            // Create new DayLog if it doesn't exist
            let newDayLog = DayLog(date: date.startOfDay())
            modelContext.insert(newDayLog)
            targetDayLog = newDayLog
        }
        
        // Create the new exercise item
        let item = ExerciseItem(
            exercise: exercise,
            unit: unit,
            amount: amount,
            note: note.isEmpty ? nil : note,
            enjoyment: enjoyment,
            intensity: intensity
        )
        
        if targetDayLog.items == nil {
            targetDayLog.items = []
        }
        targetDayLog.items?.append(item)
        
        try? modelContext.save()
    }
}

#if os(macOS)
private extension View {
    @ViewBuilder
    func macPresentationFitted() -> some View {
        if #available(macOS 15.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
    }
}
#endif
