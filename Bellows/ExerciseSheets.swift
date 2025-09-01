import SwiftUI
import SwiftData

// MARK: - Add Exercise Sheet
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
        let unique = Dictionary(grouping: exerciseTypes) { $0.name.lowercased() }
            .compactMap { _, dups in dups.max { $0.createdAt < $1.createdAt } }
        return unique.filter { $0.name.lowercased() != "other" }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var filteredUnitTypes: [UnitType] {
        let unique = Dictionary(grouping: unitTypes) { $0.name.lowercased() }
            .compactMap { _, dups in dups.max { $0.createdAt < $1.createdAt } }
        return unique.filter { $0.name.lowercased() != "other" }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    LabeledContent("Exercise") {
                        Picker("Exercise", selection: $selectedExercise) {
                            // Special action row to add a new type
                            Text("Add New Exercise…").tag(nil as ExerciseType?)
                            ForEach(filteredExerciseTypes) { exercise in
                                Text(exercise.name).tag(Optional(exercise))
                            }
                        }
                        .labelsHidden()
                    }
                    // Inline add handled via special row in Picker
                    
                    LabeledContent("Unit") {
                        Picker("Unit", selection: $selectedUnit) {
                            // Special action row to add a new type
                            Text("Add New Unit…").tag(nil as UnitType?)
                            ForEach(filteredUnitTypes) { unit in
                                Text(unit.name).tag(Optional(unit))
                            }
                        }
                        .labelsHidden()
                    }
                    // Inline add handled via special row in Picker
                    
                    LabeledContent("Amount") {
                        HStack {
                            Text(amountOnlyString(amount, unit: selectedUnit))
                                .monospacedDigit()
                                .fontWeight(.medium)
                            Spacer()
                            Stepper("", value: $amount, in: 0...10_000, step: stepForSelectedUnit())
                                .labelsHidden()
                        }
                    }
                }
                
                Section("Ratings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enjoyment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Enjoyment", selection: $enjoyment) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Intensity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Intensity", selection: $intensity) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section("Note") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Optional", text: $note, axis: .vertical)
                            .font(.body) // Fix small placeholder/text on macOS
                            .textFieldStyle(.roundedBorder)
                    }
                }
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
                if selectedExercise == nil { selectedExercise = filteredExerciseTypes.first }
                if selectedUnit == nil { selectedUnit = filteredUnitTypes.first }
                previousSelectedExercise = selectedExercise
                previousSelectedUnit = selectedUnit
            }
            .onChange(of: selectedExercise) { _, newValue in
                if newValue == nil {
                    // Trigger add-new sheet and restore previous selection
                    showingNewExerciseType = true
                    selectedExercise = previousSelectedExercise ?? filteredExerciseTypes.first
                } else {
                    previousSelectedExercise = newValue
                }
            }
            .onChange(of: selectedUnit) { _, newValue in
                if newValue == nil {
                    showingNewUnitType = true
                    selectedUnit = previousSelectedUnit ?? filteredUnitTypes.first
                } else {
                    previousSelectedUnit = newValue
                }
            }
            .sheet(isPresented: $showingNewExerciseType) {
                NewExerciseTypeSheet { e in
                    selectedExercise = e
                    previousSelectedExercise = e
                }
            }
            .sheet(isPresented: $showingNewUnitType) {
                NewUnitTypeSheet { u in
                    selectedUnit = u
                    previousSelectedUnit = u
                }
            }
#if os(macOS)
            .formStyle(.grouped)
            .macPresentationFitted()
            .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
#endif
        }
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
    
    private func stepForSelectedUnit() -> Double { stepForUnitCategory(selectedUnit?.category) }
}

// MARK: - Test hooks
@MainActor
func __test_addExercise(context: ModelContext, date: Date, dayLog: DayLog?, exercise: ExerciseType, unit: UnitType, amount: Double, enjoyment: Int, intensity: Int, note: String?) {
    // Mirror the addExercise() logic
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

@MainActor
func __test_newExerciseTypeSave(context: ModelContext, name: String, iconSystemName: String?) {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    do {
        let all = try context.fetch(FetchDescriptor<ExerciseType>())
        if !all.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            let e = ExerciseType(name: trimmed, baseMET: 4.0, repWeight: 0.15, defaultPaceMinPerMi: 10.0, iconSystemName: iconSystemName)
            context.insert(e)
        }
        try context.save()
    } catch {
        print("ERROR: __test_newExerciseTypeSave failed: \(error)")
    }
}

@MainActor
func __test_newUnitTypeSave(context: ModelContext, name: String, abbreviation: String, category: UnitCategory) {
    let trimmedName = name.trimmingCharacters(in: .whitespaces)
    let trimmedAbbr = abbreviation.trimmingCharacters(in: .whitespaces)
    do {
        let all = try context.fetch(FetchDescriptor<UnitType>())
        if let existing = all.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            existing.abbreviation = trimmedAbbr
            existing.category = category
        } else {
            let u = UnitType(name: trimmedName, abbreviation: trimmedAbbr, category: category)
            context.insert(u)
        }
        try context.save()
    } catch {
        print("ERROR: __test_newUnitTypeSave failed: \(error)")
    }
}

// MARK: - Edit Exercise Sheet
@MainActor
struct EditExerciseItemSheet: View {
    let item: ExerciseItem
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]
    
    @State private var selectedExercise: ExerciseType?
    @State private var selectedUnit: UnitType?
    @State private var amount: Double = 0
    @State private var enjoyment: Int = 3
    @State private var intensity: Int = 3
    @State private var note: String = ""
    @State private var showingNewExerciseType = false
    @State private var showingNewUnitType = false
    @State private var previousSelectedExercise: ExerciseType?
    @State private var previousSelectedUnit: UnitType?
    
    private var filteredExerciseTypes: [ExerciseType] {
        let unique = Dictionary(grouping: exerciseTypes) { $0.name.lowercased() }
            .compactMap { _, dups in dups.max { $0.createdAt < $1.createdAt } }
        return unique.filter { $0.name.lowercased() != "other" }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var filteredUnitTypes: [UnitType] {
        let unique = Dictionary(grouping: unitTypes) { $0.name.lowercased() }
            .compactMap { _, dups in dups.max { $0.createdAt < $1.createdAt } }
        return unique.filter { $0.name.lowercased() != "other" }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    LabeledContent("Exercise") {
                        Picker("Exercise", selection: $selectedExercise) {
                            // Special action row to add a new type
                            Text("Add New Exercise…").tag(nil as ExerciseType?)
                            ForEach(filteredExerciseTypes) { exercise in
                                Text(exercise.name).tag(Optional(exercise))
                            }
                        }
                        .labelsHidden()
                    }
                    
                    LabeledContent("Unit") {
                        Picker("Unit", selection: $selectedUnit) {
                            // Special action row to add a new type
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
                            Stepper("", value: $amount, in: 0...10_000, step: stepForSelectedUnit())
                                .labelsHidden()
                        }
                    }
                }
                
                Section("Ratings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enjoyment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Enjoyment", selection: $enjoyment) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Intensity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Intensity", selection: $intensity) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section("Note") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Optional", text: $note, axis: .vertical)
                            .font(.body) // Fix small placeholder/text on macOS
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .navigationTitle("Edit Exercise")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Pre-populate with current values
                selectedExercise = item.exercise
                selectedUnit = item.unit
                amount = item.amount
                enjoyment = item.enjoyment
                intensity = item.intensity
                note = item.note ?? ""
                previousSelectedExercise = selectedExercise
                previousSelectedUnit = selectedUnit
            }
            .onChange(of: selectedExercise) { _, newValue in
                if newValue == nil {
                    showingNewExerciseType = true
                    selectedExercise = previousSelectedExercise ?? filteredExerciseTypes.first
                } else {
                    previousSelectedExercise = newValue
                }
            }
            .onChange(of: selectedUnit) { _, newValue in
                if newValue == nil {
                    showingNewUnitType = true
                    selectedUnit = previousSelectedUnit ?? filteredUnitTypes.first
                } else {
                    previousSelectedUnit = newValue
                }
            }
            .sheet(isPresented: $showingNewExerciseType) { NewExerciseTypeSheet { e in
                selectedExercise = e
                previousSelectedExercise = e
            } }
            .sheet(isPresented: $showingNewUnitType) { NewUnitTypeSheet { u in
                selectedUnit = u
                previousSelectedUnit = u
            } }
#if os(macOS)
            .formStyle(.grouped)
            .macPresentationFitted()
            .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
#endif
        }
    }
    
    private func saveChanges() {
        item.exercise = selectedExercise
        item.unit = selectedUnit
        item.amount = amount
        item.enjoyment = enjoyment
        item.intensity = intensity
        item.note = note.isEmpty ? nil : note
        item.modifiedAt = Date()
        
        try? modelContext.save()
    }
    
    private func stepForSelectedUnit() -> Double { stepForUnitCategory(selectedUnit?.category) }
}

// MARK: - Helper Functions
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

func amountOnlyString(_ amount: Double, unit: UnitType?) -> String {
    guard let unit else { return String(format: "%.0f", amount) }
    switch unit.category {
    case .reps, .steps:
        return String(Int(amount))
    default:
        return String(format: "%.1f", amount)
    }
}
