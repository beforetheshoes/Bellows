import SwiftUI
import SwiftData
import HealthKit

@MainActor
struct ImportRecentWorkoutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable private var service = HealthKitService.shared

    @State private var isLoading = true
    @State private var errorText: String?
    @State private var rows: [WorkoutRow] = []
    @State private var importing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if let err = errorText { Text(err).foregroundStyle(.red).font(.footnote) }
                List {
                    ForEach(rows) { row in
                        HStack(alignment: .center, spacing: 12) {
                            Toggle(isOn: binding(for: row.id)) { EmptyView() }
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(row.title)").font(.headline)
                                Text("\(row.subtitle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if isLoading { ProgressView().controlSize(.large) }
                }
                .disabled(importing || isLoading)

                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }.buttonStyle(.bordered).controlSize(.small)

                    Button(importing ? "Importing…" : "Import Selected") {
                        Task { await importSelected() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(importing || rows.allSatisfy { !$0.selected })
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Import Recent Workouts")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task { await loadRecent() }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding {
            rows.first(where: { $0.id == id })?.selected ?? false
        } set: { newValue in
            if let idx = rows.firstIndex(where: { $0.id == id }) {
                rows[idx].selected = newValue
            }
        }
    }

    private func loadRecent() async {
        isLoading = true
        defer { isLoading = false }
        errorText = nil

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end
        let workouts = await service.fetchWorkouts(from: start, to: end)
        let sorted = workouts.sorted { $0.startDate > $1.startDate }
        let lastFive = Array(sorted.prefix(5))

        rows = lastFive.map { w in
            let minutes = Int((w.duration / 60.0).rounded())
            let title = service.mapActivityTypeToExerciseName(w.workoutActivityType)
            let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
            let subtitle = "\(df.string(from: w.startDate)) – \(minutes) min"
            return WorkoutRow(id: w.uuid, workout: w, title: title, subtitle: subtitle, selected: true)
        }
        if rows.isEmpty { errorText = "No recent workouts found." }
    }

    private func importSelected() async {
        importing = true
        defer { importing = false }
        let selected = rows.filter { $0.selected }.map { $0.workout }
        let count = await service.importSpecificWorkoutsIgnoringDedup(selected, modelContext: modelContext)
        if count >= 0 { dismiss() }
    }
}

private struct WorkoutRow: Identifiable {
    let id: UUID
    let workout: WorkoutProtocol
    let title: String
    let subtitle: String
    var selected: Bool
}
