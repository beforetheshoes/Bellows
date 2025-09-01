import SwiftUI
import SwiftData

@MainActor
struct DayDetailView: View {
    let date: Date
    @Environment(\.modelContext) private var modelContext
    @Query private var logs: [DayLog]
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]
    
    @State private var editingItem: ExerciseItem?
    @State private var showingAddSheet = false
    
    init(date: Date) {
        self.date = date
        let startOfDay = date.startOfDay()
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        _logs = Query(filter: #Predicate<DayLog> { log in
            log.date >= startOfDay && log.date < endOfDay
        })
    }
    
    private var dayLog: DayLog? {
        logs.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let dayLog = dayLog {
                    if dayLog.unwrappedItems.isEmpty {
                        VStack(spacing: 12) {
                            Text("No exercises logged")
                                .font(.headline)
                            Text("No activities were recorded for this day.")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        exercisesList(for: dayLog)
                        
                        if let averages = dailyAverages(for: dayLog) {
                            summaryCard(averages: averages)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("No data")
                            .font(.headline)
                        Text("No log entry exists for this date.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle(dateString(date))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingItem) { item in
            EditExerciseItemSheet(item: item)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddExerciseItemSheet(date: date, dayLog: dayLog)
        }
    }
    
    private func exercisesList(for dayLog: DayLog) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(dayLog.unwrappedItems, id: \.persistentModelID) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label(for: item))
                                .font(.body)
                            
                            if let note = item.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 8) {
                                Label("\(item.enjoyment)", systemImage: "face.smiling")
                                Label("\(item.intensity)", systemImage: "flame")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
                    
                    if item.persistentModelID != dayLog.unwrappedItems.last?.persistentModelID {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func summaryCard(averages: (enjoyment: Double, intensity: Double)) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Summary")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Enjoyment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(String(format: "%.1f", averages.enjoyment), systemImage: "face.smiling")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average Intensity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(String(format: "%.1f", averages.intensity), systemImage: "flame")
                        .font(.title3)
                        .fontWeight(.medium)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    
    
    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func dailyAverages(for dayLog: DayLog) -> (enjoyment: Double, intensity: Double)? {
        let items = dayLog.unwrappedItems
        guard !items.isEmpty else { return nil }
        let eAvg = Double(items.map { $0.enjoyment }.reduce(0, +)) / Double(items.count)
        let iAvg = Double(items.map { $0.intensity }.reduce(0, +)) / Double(items.count)
        return (eAvg, iAvg)
    }
}

func __test_daydetail_label(for item: ExerciseItem) -> String {
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

func __test_daydetail_dailyAverages(for dayLog: DayLog) -> (enjoyment: Double, intensity: Double)? {
    let items = dayLog.unwrappedItems
    guard !items.isEmpty else { return nil }
    let eAvg = Double(items.map { $0.enjoyment }.reduce(0, +)) / Double(items.count)
    let iAvg = Double(items.map { $0.intensity }.reduce(0, +)) / Double(items.count)
    return (eAvg, iAvg)
}
