import SwiftUI
import SwiftData

@MainActor
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var logs: [DayLog]
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]

    @State private var today: DayLog?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    streakHeader
                    addInlineCard
                    trendCard
                }
                .frame(maxWidth: DS.Metrics.contentMaxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 40)
            }
            .navigationTitle("Bellows")
            /* inline title iOS only */
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "calendar")
                    }
                }
            }
            .onAppear { ensureToday() }
        }
    }

    private var header: some View {
        HStack {
            Text(dateString(Date()))
                .font(.headline).bold()
            Spacer()
            Text("Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var streakHeader: some View {
        StreakHeaderView(streak: Analytics.currentStreak(days: logs))
    }

    // Inline add card for fast, single-view logging
    @State private var selectedExercise: ExerciseType?
    @State private var selectedUnit: UnitType?
    @State private var selectedEnjoyment: Int?
    @State private var selectedIntensity: Int?
    @State private var amount: Double = 10
    @State private var note: String = ""
    @State private var showNewExercise = false
    @State private var showNewUnit = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Filter out placeholder types like "Other"
    private var filteredExerciseTypes: [ExerciseType] {
        exerciseTypes.filter { $0.name.lowercased() != "other" }
    }
    private var filteredUnitTypes: [UnitType] {
        unitTypes.filter { $0.name.lowercased() != "other" }
    }
    
    private var addInlineCard: some View {
        Section("Add Activity") {
            VStack(spacing: 12) {
                if horizontalSizeClass == .compact {
                    compactLayout
                } else {
                    regularLayout
                }
                
                HStack(spacing: 16) {
                    Picker("Enjoyment", selection: Binding(
                        get: { selectedEnjoyment ?? 3 },
                        set: { selectedEnjoyment = max(1, min(5, $0)) }
                    )) {
                        ForEach(1...5, id: \.self) { e in
                            Text("\(e)").tag(e)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                            .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                    )

                    Picker("Intensity", selection: Binding(
                        get: { selectedIntensity ?? 3 },
                        set: { selectedIntensity = max(1, min(5, $0)) }
                    )) {
                        ForEach(1...5, id: \.self) { i in
                            Text("\(i)").tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                            .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                    )
                }
                
                VStack(spacing: 6) {
                    TextField("Note (optional)", text: $note)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.thickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                        )
                }
                
                Button(action: addFromInline) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled((selectedExercise ?? filteredExerciseTypes.first) == nil || (selectedUnit ?? filteredUnitTypes.first) == nil || amount <= 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(.quaternary.opacity(0.3), lineWidth: 0.5)
            )
            .sheet(isPresented: $showNewExercise) { NewExerciseTypeSheet() }
            .sheet(isPresented: $showNewUnit) { NewUnitTypeSheet() }
            .onAppear {
                if selectedExercise == nil { selectedExercise = filteredExerciseTypes.first }
                if selectedUnit == nil { selectedUnit = filteredUnitTypes.first }
            }
        }
        .font(.subheadline)
    }
    
    private var compactLayout: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Picker("Exercise", selection: Binding(
                    get: { selectedExercise ?? filteredExerciseTypes.first },
                    set: { selectedExercise = $0 }
                )) {
                    ForEach(filteredExerciseTypes) { t in
                        Text(t.name).tag(Optional(t))
                    }
                    Divider()
                    Text("Add Exercise…").tag(Optional<ExerciseType>.none)
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                        .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                )
                .onChange(of: selectedExercise) { _, newValue in
                    if newValue == nil {
                        showNewExercise = true
                        // revert to first available option for visual stability
                        selectedExercise = filteredExerciseTypes.first
                    }
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Stepper(value: $amount, in: 0...10_000, step: stepForSelectedUnit(selectedUnit)) {
                            Text(amountOnlyString(amount, unit: selectedUnit ?? filteredUnitTypes.first))
                                .monospacedDigit()
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.thickMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                                .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                        )
                    }
                    
                    Picker("Unit", selection: Binding(
                        get: { selectedUnit ?? filteredUnitTypes.first },
                        set: { selectedUnit = $0 }
                    )) {
                        ForEach(filteredUnitTypes) { u in
                            Text(u.name).tag(Optional(u))
                        }
                        Divider()
                        Text("Add Unit…").tag(Optional<UnitType>.none)
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                            .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                    )
                    .onChange(of: selectedUnit) { _, newValue in
                        if newValue == nil {
                            showNewUnit = true
                            selectedUnit = filteredUnitTypes.first
                        }
                    }
                }
            }
        }
    }
    
    private var regularLayout: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Picker("Exercise", selection: Binding(
                    get: { selectedExercise ?? filteredExerciseTypes.first },
                    set: { selectedExercise = $0 }
                )) {
                    ForEach(filteredExerciseTypes) { t in
                        Text(t.name).tag(Optional(t))
                    }
                    Divider()
                    Text("Add Exercise…").tag(Optional<ExerciseType>.none)
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                        .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                )
                .onChange(of: selectedExercise) { _, newValue in
                    if newValue == nil {
                        showNewExercise = true
                        selectedExercise = filteredExerciseTypes.first
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Stepper(value: $amount, in: 0...10_000, step: stepForSelectedUnit(selectedUnit)) {
                        Text(amountOnlyString(amount, unit: selectedUnit ?? filteredUnitTypes.first))
                            .monospacedDigit()
                            .fontWeight(.medium)
                            .frame(minWidth: 60)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                            .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                    )
                }
            
                Picker("Unit", selection: Binding(
                    get: { selectedUnit ?? filteredUnitTypes.first },
                    set: { selectedUnit = $0 }
                )) {
                    ForEach(filteredUnitTypes) { u in
                        Text(u.name).tag(Optional(u))
                    }
                    Divider()
                    Text("Add Unit…").tag(Optional<UnitType>.none)
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                        .strokeBorder(.quaternary.opacity(0.5), lineWidth: 1)
                )
                .onChange(of: selectedUnit) { _, newValue in
                    if newValue == nil {
                        showNewUnit = true
                        selectedUnit = filteredUnitTypes.first
                    }
                }
            }
        }
    }
    

    // Replaces the old Intensity Trend with today's exercises list
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today’s Exercises")
                    .font(.headline)
                Spacer()
                if let count = today?.unwrappedItems.count { Text("\(count)") .foregroundStyle(.secondary) }
            }

            if let today {
                if today.unwrappedItems.isEmpty {
                    VStack(spacing: 6) {
                        Text("No items yet")
                        Text("Use the form above to add an item")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(today.unwrappedItems.enumerated()), id: \.element) { idx, item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(label(for: item))
                                Spacer()
                                Text(scoreString(item.intensityScore))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 6)
                            if idx < today.unwrappedItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius).strokeBorder(.quaternary, lineWidth: 0.5))
    }

    // MARK: helpers

    private func ensureToday() {
        let key = Date().startOfDay()
        
        // Clean up any duplicates first - both DayLog and type duplicates
        removeDuplicateEntries(for: key)
        removeDuplicateExerciseTypes()
        removeDuplicateUnitTypes()
        
        // First try to find existing entry by comparing dates properly
        if let existing = logs.first(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: key) 
        }) {
            print("DEBUG: Found existing DayLog for today: \(existing.date)")
            today = existing
            return
        }
        
        // Create new entry only if none exists
        print("DEBUG: Creating new DayLog for: \(key)")
        let new = DayLog(date: key)
        modelContext.insert(new)
        
        // Save immediately to prevent race conditions
        do {
            try modelContext.save()
            print("DEBUG: Successfully saved new DayLog")
        } catch {
            print("ERROR: Failed to save new DayLog: \(error)")
        }
        
        today = new
    }
    
    private func removeDuplicateEntries(for targetDate: Date) {
        // Find all entries for the same day
        let duplicates = logs.filter { log in
            Calendar.current.isDate(log.date, inSameDayAs: targetDate)
        }
        
        // If we have more than one entry for this day, keep the first one and delete the rest
        if duplicates.count > 1 {
            print("DEBUG: Found \(duplicates.count) duplicate DayLog entries for \(targetDate)")
            
            // Keep the first one (or the one with items if any)
            let toKeep = duplicates.first { !$0.unwrappedItems.isEmpty } ?? duplicates.first!
            let toDelete = duplicates.filter { $0 !== toKeep }
            
            print("DEBUG: Keeping DayLog entry from \(toKeep.date), deleting \(toDelete.count) duplicates")
            
            for duplicate in toDelete {
                print("DEBUG: Deleting duplicate DayLog entry: \(duplicate.date) with \(duplicate.unwrappedItems.count) items")
                modelContext.delete(duplicate)
            }
            
            // Save the cleanup
            do {
                try modelContext.save()
                print("DEBUG: Successfully cleaned up DayLog duplicates")
            } catch {
                print("ERROR: Failed to save after DayLog duplicate cleanup: \(error)")
            }
        }
    }
    
    private func removeDuplicateExerciseTypes() {
        // Group exercise types by name (case-insensitive)
        let grouped = Dictionary(grouping: exerciseTypes) { $0.name.lowercased() }
        
        for (name, duplicates) in grouped {
            if duplicates.count > 1 {
                print("DEBUG: Found \(duplicates.count) duplicate ExerciseType entries for '\(name)'")
                
                // Keep the one with the most recent creation date, or first one if same
                let toKeep = duplicates.max { $0.createdAt < $1.createdAt } ?? duplicates.first!
                let toDelete = duplicates.filter { $0 !== toKeep }
                
                print("DEBUG: Keeping ExerciseType '\(toKeep.name)' (created: \(toKeep.createdAt)), deleting \(toDelete.count) duplicates")
                
                // Update any ExerciseItems that reference the duplicates to use the kept one
                for duplicate in toDelete {
                    if let items = duplicate.exerciseItems {
                        for item in items {
                            item.exercise = toKeep
                        }
                    }
                    print("DEBUG: Deleting duplicate ExerciseType: \(duplicate.name)")
                    modelContext.delete(duplicate)
                }
                
                // Save the cleanup
                do {
                    try modelContext.save()
                    print("DEBUG: Successfully cleaned up ExerciseType duplicates for '\(name)'")
                } catch {
                    print("ERROR: Failed to save after ExerciseType duplicate cleanup: \(error)")
                }
            }
        }
    }
    
    private func removeDuplicateUnitTypes() {
        // Group unit types by name (case-insensitive)
        let grouped = Dictionary(grouping: unitTypes) { $0.name.lowercased() }
        
        for (name, duplicates) in grouped {
            if duplicates.count > 1 {
                print("DEBUG: Found \(duplicates.count) duplicate UnitType entries for '\(name)'")
                
                // Keep the one with the most recent creation date, or first one if same
                let toKeep = duplicates.max { $0.createdAt < $1.createdAt } ?? duplicates.first!
                let toDelete = duplicates.filter { $0 !== toKeep }
                
                print("DEBUG: Keeping UnitType '\(toKeep.name)' (created: \(toKeep.createdAt)), deleting \(toDelete.count) duplicates")
                
                // Update any ExerciseItems that reference the duplicates to use the kept one
                for duplicate in toDelete {
                    if let items = duplicate.exerciseItems {
                        for item in items {
                            item.unit = toKeep
                        }
                    }
                    print("DEBUG: Deleting duplicate UnitType: \(duplicate.name)")
                    modelContext.delete(duplicate)
                }
                
                // Save the cleanup
                do {
                    try modelContext.save()
                    print("DEBUG: Successfully cleaned up UnitType duplicates for '\(name)'")
                } catch {
                    print("ERROR: Failed to save after UnitType duplicate cleanup: \(error)")
                }
            }
        }
    }
    
    // MARK: - Uniqueness Helper Functions
    
    private func findOrCreateExerciseType(name: String) -> ExerciseType {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Look for existing exercise type (case-insensitive)
        if let existing = exerciseTypes.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            return existing
        }
        
        // Create new one if not found
        let newType = ExerciseType(
            name: trimmedName,
            baseMET: 4.0,
            repWeight: 0.15,
            defaultPaceMinPerMi: 10.0,
            iconSystemName: nil
        )
        modelContext.insert(newType)
        
        do {
            try modelContext.save()
            print("DEBUG: Created new ExerciseType: \(trimmedName)")
        } catch {
            print("ERROR: Failed to save new ExerciseType: \(error)")
        }
        
        return newType
    }
    
    private func findOrCreateUnitType(name: String, abbreviation: String, category: UnitCategory) -> UnitType {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedAbbreviation = abbreviation.trimmingCharacters(in: .whitespaces)
        
        // Look for existing unit type (case-insensitive name)
        if let existing = unitTypes.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            return existing
        }
        
        // Create new one if not found
        let newType = UnitType(name: trimmedName, abbreviation: trimmedAbbreviation, category: category)
        modelContext.insert(newType)
        
        do {
            try modelContext.save()
            print("DEBUG: Created new UnitType: \(trimmedName) (\(trimmedAbbreviation))")
        } catch {
            print("ERROR: Failed to save new UnitType: \(error)")
        }
        
        return newType
    }

    private func addFromInline() {
        guard let today else { return }
        guard let ex = selectedExercise ?? filteredExerciseTypes.first, let u = selectedUnit ?? filteredUnitTypes.first else { return }
        let item = ExerciseItem(exercise: ex, unit: u, amount: amount, note: note.isEmpty ? nil : note, enjoyment: selectedEnjoyment ?? 3, intensity: selectedIntensity ?? 3)
        today.items?.append(item)
        // reset quickly for next add
        amount = 10
        note = ""
    }

    private func label(for item: ExerciseItem) -> String {
        let name = item.exercise?.name ?? "Unknown"
        let abbr = item.unit?.abbreviation ?? ""
        switch item.unit?.category ?? .other {
        case .reps: return "\(Int(item.amount)) \(name)"
        case .minutes: return "\(Int(item.amount)) \(abbr) \(name)"
        case .steps: return "\(Int(item.amount)) \(abbr) \(name)"
        case .distanceMi: return String(format: "%.1f %@ %@", item.amount, abbr, name)
        case .other: return String(format: "%.1f %@ %@", item.amount, abbr, name)
        }
    }

    private func scoreString(_ s: Double) -> String { String(format: "%.0f", s) }
    private func trim(_ d: Double) -> String { String(format: "%g", d) }
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .full; return f.string(from: d)
    }
}

// New type/unit sheets
struct NewExerciseTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var name = ""
    @State private var selectedIcon: String? = nil
    private let iconChoices: [String] = [
        "figure.walk", "figure.run", "bicycle", "figure.mind.and.body", "figure.core.training",
        "figure.strengthtraining.traditional", "figure.strengthtraining.functional", "flame", "bolt",
        "heart", "leaf", "sun.max", "moon", "drop", "hare", "tortoise", "figure.yoga",
        "figure.disc.sports", "sportscourt", "tennis.racket", "soccerball", "basketball",
        "figure.elliptical", "figure.cross.training", "figure.hiking", "figure.skiing.downhill",
        "figure.surfing", "figure.climbing", "medal", "star"
    ]
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    LabeledContent("Name") {
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Section("Icon (optional)") {
                    let cols = [GridItem(.adaptive(minimum: 44, maximum: 72), spacing: 12)]
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(iconChoices, id: \.self) { sym in
                            Button(action: { selectedIcon = selectedIcon == sym ? nil : sym }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedIcon == sym ? Color.accentColor.opacity(0.2) : Color.clear)
                                    Image(systemName: sym)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(8)
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(selectedIcon == sym ? .accent : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selectedIcon == sym ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selectedIcon == sym ? 2 : 1)
                            )
                            .help(sym)
                        }
                    }
                }
            }
            .navigationTitle("New Exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        do {
                            let all = try ctx.fetch(FetchDescriptor<ExerciseType>())
                            if all.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                                // Exercise already exists; nothing to update
                                print("DEBUG: ExerciseType already exists: \(trimmedName)")
                            } else {
                                let e = ExerciseType(
                                    name: trimmedName,
                                    baseMET: 4.0,
                                    repWeight: 0.15,
                                    defaultPaceMinPerMi: 10.0,
                                    iconSystemName: selectedIcon
                                )
                                ctx.insert(e)
                                print("DEBUG: Created new ExerciseType: \(trimmedName)")
                            }
                            try ctx.save()
                        } catch {
                            print("ERROR: ExerciseType save failed: \(error)")
                        }
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
#if os(iOS)
            .presentationDetents([.medium, .large])
#elseif os(macOS)
            .formStyle(.grouped)
            .macPresentationFitted()
            .frame(minWidth: 420, idealWidth: 520, maxWidth: 620)
#endif
        }
    }
}

struct NewUnitTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var name = ""
    @State private var abbr = ""
    @State private var category: UnitCategory = .other
    var body: some View {
        NavigationStack {
            Form {
                Section("Unit") {
                    LabeledContent("Name") {
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("Abbreviation") {
                        TextField("", text: $abbr)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Section("Category") {
                    LabeledContent("Category") {
                        Picker("Category", selection: $category) {
                            ForEach(UnitCategory.allCases) { c in Text(c.rawValue).tag(c) }
                        }
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("New Unit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        let trimmedAbbr = abbr.trimmingCharacters(in: .whitespaces)

                        do {
                            let all = try ctx.fetch(FetchDescriptor<UnitType>())
                            if let existing = all.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                                existing.abbreviation = trimmedAbbr
                                existing.category = category
                                print("DEBUG: Updated existing UnitType: \(trimmedName)")
                            } else {
                                let u = UnitType(name: trimmedName, abbreviation: trimmedAbbr, category: category)
                                ctx.insert(u)
                                print("DEBUG: Created new UnitType: \(trimmedName)")
                            }
                            try ctx.save()
                        } catch {
                            print("ERROR: UnitType save failed: \(error)")
                        }
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
#if os(iOS)
            .presentationDetents([.medium, .large])
#elseif os(macOS)
            .formStyle(.grouped)
            .macPresentationFitted()
            .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
#endif
        }
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

// Amount/unit helpers for entry UI
private func displayAmount(_ amount: Double, unit: UnitType?) -> String {
    guard let unit else { return String(format: "%.0f", amount) }
    switch unit.category {
    case .reps, .steps:
        return "\(Int(amount)) \(unit.abbreviation)"
    default:
        return String(format: "%.1f %@", amount, unit.abbreviation)
    }
}

private func amountOnlyString(_ amount: Double, unit: UnitType?) -> String {
    guard let unit else { return String(format: "%.0f", amount) }
    switch unit.category {
    case .reps, .steps:
        return String(Int(amount))
    default:
        return String(format: "%.1f", amount)
    }
}

private func stepForSelectedUnit(_ unit: UnitType? = nil) -> Double {
    switch unit?.category {
    case .reps, .steps: return 1
    case .distanceMi: return 0.1
    case .minutes: return 0.5
    default: return 0.5
    }
}
