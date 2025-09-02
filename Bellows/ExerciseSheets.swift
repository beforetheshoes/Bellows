import SwiftUI
import SwiftData

// MARK: - Section Views for AddExerciseItemSheet
@MainActor
private struct ExerciseSelectionSection: View {
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
        .onChange(of: selectedExercise) { oldValue, newValue in
            if newValue == nil {
                showingNewExerciseType = true
                selectedExercise = previousSelectedExercise ?? filteredExerciseTypes.first
            } else {
                previousSelectedExercise = newValue
                
                if oldValue != newValue, let exercise = newValue {
                    if let bestUnit = findBestMatchingUnit(for: exercise, from: filteredUnitTypes) {
                        selectedUnit = bestUnit
                        previousSelectedUnit = bestUnit
                    }
                }
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
    }
}

@MainActor
private struct RatingsSection: View {
    @Binding var enjoyment: Int
    @Binding var intensity: Int
    
    var body: some View {
        Section("Ratings") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enjoyment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Enjoyment", selection: $enjoyment) {
                    ForEach(1...5, id: \.self) { rating in 
                        Text("\(rating)").tag(rating) 
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Intensity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Intensity", selection: $intensity) {
                    ForEach(1...5, id: \.self) { rating in 
                        Text("\(rating)").tag(rating) 
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

@MainActor
private struct NoteSection: View {
    @Binding var note: String
    
    var body: some View {
        Section("Note") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Optional", text: $note, axis: .vertical)
                    .font(.body)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

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
            Form {
                ExerciseSelectionSection(
                    filteredExerciseTypes: filteredExerciseTypes,
                    filteredUnitTypes: filteredUnitTypes,
                    selectedExercise: $selectedExercise,
                    selectedUnit: $selectedUnit,
                    amount: $amount,
                    showingNewExerciseType: $showingNewExerciseType,
                    showingNewUnitType: $showingNewUnitType,
                    previousSelectedExercise: $previousSelectedExercise,
                    previousSelectedUnit: $previousSelectedUnit
                )
                
                RatingsSection(
                    enjoyment: $enjoyment,
                    intensity: $intensity
                )
                
                NoteSection(note: $note)
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
#if os(macOS)
            .formStyle(.grouped)
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

// MARK: - Section Views for EditExerciseItemSheet  
@MainActor
private struct EditExerciseSelectionSection: View {
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
        .onChange(of: selectedExercise) { oldValue, newValue in
            if newValue == nil {
                showingNewExerciseType = true
                selectedExercise = previousSelectedExercise ?? filteredExerciseTypes.first
            } else {
                previousSelectedExercise = newValue
                
                if oldValue != newValue, let exercise = newValue {
                    if let bestUnit = findBestMatchingUnit(for: exercise, from: filteredUnitTypes) {
                        selectedUnit = bestUnit
                        previousSelectedUnit = bestUnit
                    }
                }
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
        let grouped = Dictionary(grouping: unitTypes) { $0.name.lowercased() }
        let unique = grouped.compactMap { _, dups in 
            dups.max { $0.createdAt < $1.createdAt } 
        }
        let filtered = unique.filter { $0.name.lowercased() != "other" }
        return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                EditExerciseSelectionSection(
                    filteredExerciseTypes: filteredExerciseTypes,
                    filteredUnitTypes: filteredUnitTypes,
                    selectedExercise: $selectedExercise,
                    selectedUnit: $selectedUnit,
                    amount: $amount,
                    showingNewExerciseType: $showingNewExerciseType,
                    showingNewUnitType: $showingNewUnitType,
                    previousSelectedExercise: $previousSelectedExercise,
                    previousSelectedUnit: $previousSelectedUnit
                )
                
                RatingsSection(
                    enjoyment: $enjoyment,
                    intensity: $intensity
                )
                
                NoteSection(note: $note)
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
                setupInitialValues()
            }
            .sheet(isPresented: $showingNewExerciseType) { NewExerciseTypeSheet { e in
                selectedExercise = e
                previousSelectedExercise = e
            } }
            .sheet(isPresented: $showingNewUnitType) { NewUnitTypeSheet { u in
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
            } }
#if os(macOS)
            .formStyle(.grouped)
            .macPresentationFitted()
            .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
#endif
        }
    }
    
    private func setupInitialValues() {
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


// Helper function for default unit selection
func findBestMatchingUnit(for exercise: ExerciseType, from units: [UnitType]) -> UnitType? {
    guard !units.isEmpty else { return nil }
    
    // If exercise has a directly specified default unit, try to find it in the available units
    if let defaultUnit = exercise.defaultUnit {
        // First try to find by object identity
        if let matchingUnit = units.first(where: { $0 === defaultUnit }) {
            return matchingUnit
        }
        
        // Then try to find by persistent model ID (if available)
        if let matchingUnit = units.first(where: { $0.persistentModelID == defaultUnit.persistentModelID }) {
            return matchingUnit
        }
        
        // If the exact unit isn't available, try to find one with the same name
        let defaultUnitName = defaultUnit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let matchingByName = units.first(where: { unit in
            let unitName = unit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return unitName == defaultUnitName
        }) {
            return matchingByName
        }
        
        // Additional fallback: try partial name matching with preference for the target pattern
        // First try to find units that contain the expected name
        if let partialMatch = units.first(where: { unit in
            let unitName = unit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return unitName.contains(defaultUnitName)
        }) {
            return partialMatch
        }
        
        // Then try the reverse (default name contains unit name)
        if let reverseMatch = units.first(where: { unit in
            let unitName = unit.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return defaultUnitName.contains(unitName)
        }) {
            return reverseMatch
        }
    }
    
    // Migration support: If exercise still has a default unit category, find the first unit that matches the expected properties for that category
    if let defaultCategory = exercise.defaultUnitCategory {
        let expectedStepSize: Double
        let expectedDisplayAsInteger: Bool
        
        switch defaultCategory {
        case .time:
            expectedStepSize = 0.5
            expectedDisplayAsInteger = false
        case .distance:
            expectedStepSize = 0.1
            expectedDisplayAsInteger = false
        case .reps, .steps:
            expectedStepSize = 1.0
            expectedDisplayAsInteger = true
        case .other:
            expectedStepSize = 1.0
            expectedDisplayAsInteger = false
        }
        
        if let matchingUnit = units.first(where: { $0.stepSize == expectedStepSize && $0.displayAsInteger == expectedDisplayAsInteger }) {
            return matchingUnit
        }
    }
    
    // Fallback to first unit if no match found
    return units.first
}

func amountOnlyString(_ amount: Double, unit: UnitType?) -> String {
    guard let unit else { return String(format: "%.1f", amount) }
    
    if unit.displayAsInteger {
        return String(Int(amount.rounded()))
    } else {
        return String(format: "%.1f", amount)
    }
}

