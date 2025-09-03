import SwiftUI
import SwiftData

@MainActor
struct ManageExerciseTypesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    
    @State private var editingExerciseType: ExerciseType?
    
    private var filteredExerciseTypes: [ExerciseType] {
        // De-duplicate by case-insensitive name, prefer latest createdAt
        let unique = Dictionary(grouping: exerciseTypes) { $0.name.lowercased() }
            .compactMap { _, dups in dups.max { $0.createdAt < $1.createdAt } }
        return unique.filter { $0.name.lowercased() != "other" }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Metrics.spacing) {
                    Text("Exercise Types").font(.headline)
                    SectionCard {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredExerciseTypes.enumerated()), id: \.element.persistentModelID) { index, exerciseType in
                                HStack(spacing: 12) {
                                    if let iconName = exerciseType.iconSystemName {
                                        Image(systemName: iconName)
                                            .frame(width: 20)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Rectangle().fill(Color.clear).frame(width: 20, height: 20)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exerciseType.name).font(.body)
                                        if let defaultUnit = exerciseType.defaultUnit {
                                            Text("Default unit: \(defaultUnit.name)").font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text("No default unit").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button("Edit") { editingExerciseType = exerciseType }
                                        .buttonStyle(.borderless)
                                        .foregroundStyle(DS.ColorToken.accent)
                                }
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                                .onTapGesture { editingExerciseType = exerciseType }
                                if index < filteredExerciseTypes.count - 1 { Divider().padding(.leading, 32) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Exercise Types")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingExerciseType) { exerciseType in
                EditExerciseTypeSheet(exerciseType: exerciseType)
            }
            #if os(macOS)
            .macPresentationFitted()
            .frame(minWidth: 480, idealWidth: 580, maxWidth: 680)
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
