import SwiftUI
import SwiftData

@MainActor
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var logs: [DayLog]
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]

    @State private var today: DayLog?
    @State private var editingItem: ExerciseItem?

    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    streakHeader
                    logExerciseButton
                    todaysExercises
                }
                .frame(maxWidth: DS.Metrics.contentMaxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 40)
            }
            .navigationTitle("Bellows")
            .sheet(item: $editingItem) { item in
                EditExerciseItemSheet(item: item)
            }
            .sheet(isPresented: $showingAddSheet) {
                AddExerciseItemSheet(date: Date(), dayLog: today)
            }
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
            }
            .onAppear {
                ensureToday()
            }
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
    
    private var logExerciseButton: some View {
        Button(action: { showingAddSheet = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("Log Exercise")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(.blue.gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    private var todaysExercises: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Exercises")
                    .font(.headline)
                Spacer()
            }
            
            if let today = today, !today.unwrappedItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(today.unwrappedItems, id: \.persistentModelID) { item in
                        exerciseRow(item)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("No exercises logged today")
                        .foregroundStyle(.secondary)
                    Text("Tap the button above to get started!")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func exerciseRow(_ item: ExerciseItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label(for: item))
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(timeString(item.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Label("\(item.enjoyment)", systemImage: "face.smiling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label("\(item.intensity)", systemImage: "flame")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            editingItem = item
        }
        .contextMenu {
            Button("Edit") {
                editingItem = item
            }
            
            Button("Delete", role: .destructive) {
                modelContext.delete(item)
                try? modelContext.save()
            }
        }
    }

    // Helper functions
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
    

    // MARK: helpers

    private func ensureToday() {
        let key = Date().startOfDay()
        
        // Always run duplicate cleanup first to ensure clean state
        DedupService.cleanupDuplicateDayLogs(context: modelContext)
        
        // Find today's entry if it exists; do not auto-create
        today = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: key) })
    }
    
    private func cleanupAllDuplicateDayLogs() {
        DedupService.cleanupDuplicateDayLogs(context: modelContext)
    }
    
    private func cleanupDuplicateExerciseTypes() {
        DedupService.cleanupDuplicateExerciseTypes(context: modelContext)
    }
    
    private func cleanupDuplicateUnitTypes() {
        DedupService.cleanupDuplicateUnitTypes(context: modelContext)
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
        } catch {
            print("ERROR: Failed to save new UnitType: \(error)")
        }
        
        return newType
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .full; return f.string(from: d)
    }
    
    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: d)
    }
}

@MainActor
func __test_home_ensureToday(context: ModelContext) {
    let key = Date().startOfDay()
    DedupService.cleanupDuplicateDayLogs(context: context)
    do {
        let all = try context.fetch(FetchDescriptor<DayLog>())
        if all.first(where: { Calendar.current.isDate($0.date, inSameDayAs: key) }) == nil {
            context.insert(DayLog(date: key))
            try context.save()
        }
    } catch {
        print("ERROR: __test_home_ensureToday: \(error)")
    }
}

func __test_home_label(for item: ExerciseItem) -> String {
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

// MARK: - New type/unit sheets
struct NewExerciseTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    var onSaved: ((ExerciseType) -> Void)? = nil
    @State private var name = ""
    @State private var selectedIcon: String? = nil
    @State private var iconQuery: String = ""
    private let fitnessSymbols: [String] = [
        "figure.walk",
        "figure.run",
        "figure.mind.and.body",
        "figure.core.training",
        "figure.strengthtraining.traditional",
        "figure.strengthtraining.functional",
        "figure.elliptical",
        "figure.cross.training",
        "figure.hiking",
        "figure.skiing.downhill",
        "figure.surfing",
        "figure.climbing",
        "figure.disc.sports",
        "figure.golf",
        "bicycle",
        "dumbbell",
        "sportscourt",
        "soccerball",
        "basketball",
        "tennis.racket",
        "medal",
        "star",
        "flame"
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
                    TextField("Search symbols", text: $iconQuery)
                        .textFieldStyle(.roundedBorder)
                    let choices = (iconQuery.trimmingCharacters(in: .whitespaces).isEmpty ? fitnessSymbols : fitnessSymbols.filter { $0.localizedCaseInsensitiveContains(iconQuery) })
                    let cols = [GridItem(.adaptive(minimum: 44, maximum: 72), spacing: 12)]
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(choices, id: \.self) { sym in
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
                            let e: ExerciseType
                            if let existing = all.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                                e = existing
                            } else {
                                e = ExerciseType(
                                    name: trimmedName,
                                    baseMET: 4.0,
                                    repWeight: 0.15,
                                    defaultPaceMinPerMi: 10.0,
                                    iconSystemName: selectedIcon
                                )
                                ctx.insert(e)
                            }
                            try ctx.save()
                            onSaved?(e)
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
    var onSaved: ((UnitType) -> Void)? = nil
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
                            let u: UnitType
                            if let existing = all.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                                existing.abbreviation = trimmedAbbr
                                existing.category = category
                                u = existing
                            } else {
                                u = UnitType(name: trimmedName, abbreviation: trimmedAbbr, category: category)
                                ctx.insert(u)
                            }
                            try ctx.save()
                            onSaved?(u)
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
