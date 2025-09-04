import SwiftUI
import SwiftData

@MainActor
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    private var themeManager = ThemeManager.shared
    @Query(sort: \DayLog.date, order: .reverse) private var logs: [DayLog]
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]

    @State private var today: DayLog?
    @State private var editingItem: ExerciseItem?

    @State private var showingAddSheet = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    SectionCard { streakHeader }
                    logExerciseButton
                    SectionCard { todaysExercisesContent }
                }
                .frame(maxWidth: DS.Metrics.contentMaxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 40)
            }
            .navigationTitle("Bellows")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(item: $editingItem) { item in
                EditExerciseItemSheet(item: item)
            }
            .sheet(isPresented: $showingAddSheet) {
                AddExerciseItemSheet(date: Date(), dayLog: today)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
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
        StreakHeaderView(streak: Analytics.currentStreak(days: logs), days: logs)
    }
    
    private var logExerciseButton: some View {
        Button(action: { showingAddSheet = true }) {
            HStack {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text("Log Exercise").font(.headline).fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(LinearGradient(colors: [DS.ColorToken.gradientStart, DS.ColorToken.gradientEnd], startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
    
    // Inner content used inside SectionCard above
    private var todaysExercisesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Exercises").font(.headline)
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
                    Text("No exercises logged today").foregroundStyle(.secondary)
                    Text("Tap the button above to get started!").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }
    
    private func exerciseRow(_ item: ExerciseItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label(for: item)).font(.body).fontWeight(.medium)
                Text(timeString(item.createdAt)).font(.caption).foregroundStyle(.secondary)
                if let note = item.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 12) {
                Label("\(item.enjoyment)", systemImage: "face.smiling.fill").font(.caption).foregroundStyle(.secondary)
                Label("\(item.intensity)", systemImage: "flame.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
        .contextMenu {
            Button("Edit") { editingItem = item }
            Button("Delete", role: .destructive) { modelContext.delete(item); try? modelContext.save() }
        }
    }

    // MARK: helpers
    private func label(for item: ExerciseItem) -> String {
        let name = item.exercise?.name ?? "Unknown"
        let abbr = item.unit?.abbreviation ?? ""
        let amountStr: String
        if let unit = item.unit {
            amountStr = unit.displayAsInteger ? String(Int(item.amount.rounded())) : String(format: "%.1f", item.amount)
        } else {
            amountStr = String(format: "%.1f", item.amount)
        }
        return abbr.isEmpty ? "\(amountStr) \(name)" : "\(amountStr) \(abbr) \(name)"
    }

    private func ensureToday() {
        let key = Date().startOfDay()
        cleanupAllDuplicateDayLogs()
        today = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: key) })
    }
    
    private func cleanupAllDuplicateDayLogs() {
        do {
            let all = try modelContext.fetch(FetchDescriptor<DayLog>())
            let grouped = Dictionary(grouping: all) { $0.date.startOfDay() }
            for (_, logs) in grouped where logs.count > 1 {
                let keeper = logs.max { a, b in
                    if a.createdAt == b.createdAt { return (a.items?.count ?? 0) < (b.items?.count ?? 0) }
                    return a.createdAt < b.createdAt
                }
                for log in logs where log !== keeper {
                    if let items = log.items, let keeperLog = keeper {
                        if keeperLog.items == nil { keeperLog.items = [] }
                        for item in items { keeperLog.items?.append(item) }
                    }
                    modelContext.delete(log)
                }
            }
            try modelContext.save()
        } catch { print("ERROR: cleanupDuplicateDayLogs failed: \(error)") }
    }

    private func findOrCreateExerciseType(name: String) -> ExerciseType {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let existing = exerciseTypes.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) { return existing }
        let newType = ExerciseType(name: trimmedName, baseMET: 4.0, repWeight: 0.15, defaultPaceMinPerMi: 10.0, iconSystemName: nil, defaultUnit: nil)
        modelContext.insert(newType)
        do { try modelContext.save() } catch { print("ERROR: Failed to save new ExerciseType: \(error)") }
        return newType
    }

    private func findOrCreateUnitType(name: String, abbreviation: String, category: UnitCategory) -> UnitType {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedAbbreviation = abbreviation.trimmingCharacters(in: .whitespaces)
        if let existing = unitTypes.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) { return existing }
        let newType = UnitType(name: trimmedName, abbreviation: trimmedAbbreviation, category: category)
        modelContext.insert(newType)
        do { try modelContext.save() } catch { print("ERROR: Failed to save new UnitType: \(error)") }
        return newType
    }

    private func dateString(_ d: Date) -> String { let f = DateFormatter(); f.dateStyle = .full; return f.string(from: d) }
    private func timeString(_ d: Date) -> String { let f = DateFormatter(); f.timeStyle = .short; return f.string(from: d) }
}

@MainActor
func __test_home_ensureToday(context: ModelContext) {
    let key = Date().startOfDay()
    do {
        let all = try context.fetch(FetchDescriptor<DayLog>())
        if all.first(where: { Calendar.current.isDate($0.date, inSameDayAs: key) }) == nil {
            context.insert(DayLog(date: key))
            try context.save()
        }
    } catch { print("ERROR: __test_home_ensureToday: \(error)") }
}

func __test_home_label(for item: ExerciseItem) -> String {
    let name = item.exercise?.name ?? "Unknown"
    let abbr = item.unit?.abbreviation ?? ""
    let amountStr: String
    if let unit = item.unit { amountStr = unit.displayAsInteger ? String(Int(item.amount.rounded())) : String(format: "%.1f", item.amount) } else { amountStr = String(format: "%.1f", item.amount) }
    return abbr.isEmpty ? "\(amountStr) \(name)" : "\(amountStr) \(abbr) \(name)"
}
