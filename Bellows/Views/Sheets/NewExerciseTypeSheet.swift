import SwiftUI
import SwiftData

struct NewExerciseTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]
    var onSaved: ((ExerciseType) -> Void)? = nil
    @State private var name = ""
    @State private var selectedIcon: String? = nil
    @State private var iconQuery: String = ""
    @State private var selectedDefaultUnit: UnitType? = nil
    @State private var showingNewUnitType = false
    
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
    
    private var filteredUnitTypes: [UnitType] {
        let grouped = Dictionary(grouping: unitTypes) { $0.name.lowercased() }
        let unique = grouped.compactMap { _, dups in 
            dups.max { $0.createdAt < $1.createdAt } 
        }
        return unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Metrics.spacing) {
                    Text("Exercise").font(.headline)
                    SectionCard {
                        LabeledContent("Name") { TextField("", text: $name).textFieldStyle(.roundedBorder) }
                    }

                    Text("Default Unit (optional)").font(.headline)
                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Default Unit")
                                Spacer()
                                Picker("", selection: $selectedDefaultUnit) {
                                    Text("None").tag(nil as UnitType?)
                                    ForEach(filteredUnitTypes) { unit in Text(unit.name).tag(Optional(unit)) }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            Button("Add New Unit") { showingNewUnitType = true }
                                .foregroundStyle(DS.ColorToken.accent)
                        }
                    }

                    Text("Icon (optional)").font(.headline)
                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Search symbols", text: $iconQuery).textFieldStyle(.roundedBorder)
                            let choices = (iconQuery.trimmingCharacters(in: .whitespaces).isEmpty ? fitnessSymbols : fitnessSymbols.filter { $0.localizedCaseInsensitiveContains(iconQuery) })
                            let cols = [GridItem(.adaptive(minimum: 44, maximum: 72), spacing: 12)]
                            LazyVGrid(columns: cols, spacing: 12) {
                                ForEach(choices, id: \.self) { sym in
                                    Button(action: { selectedIcon = selectedIcon == sym ? nil : sym }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(selectedIcon == sym ? DS.ColorToken.accent.opacity(0.2) : Color.clear)
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
                                            .stroke(selectedIcon == sym ? DS.ColorToken.accent : Color.secondary.opacity(0.3), lineWidth: selectedIcon == sym ? 2 : 1)
                                    )
                                    .help(sym)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
                                    iconSystemName: selectedIcon,
                                    defaultUnit: selectedDefaultUnit
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
            .sheet(isPresented: $showingNewUnitType) {
                NewUnitTypeSheet { newUnit in
                    selectedDefaultUnit = newUnit
                }
            }
#if os(iOS)
            .presentationDetents([.medium, .large])
            #elseif os(macOS)
            .macPresentationFitted()
            .frame(minWidth: 420, idealWidth: 520, maxWidth: 620)
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
