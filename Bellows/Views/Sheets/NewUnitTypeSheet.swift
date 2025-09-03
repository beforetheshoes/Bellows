import SwiftUI
import SwiftData

struct NewUnitTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    var onSaved: ((UnitType) -> Void)? = nil
    @State private var name = ""
    @State private var abbr = ""
    @State private var stepSize: Double = 1.0
    @State private var displayAsInteger: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Metrics.spacing) {
                    Text("Unit Details").font(.headline)
                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("Name") { TextField("e.g. Minutes, Reps, Miles", text: $name).textFieldStyle(.roundedBorder) }
                            LabeledContent("Abbreviation") { TextField("e.g. min, reps, mi", text: $abbr).textFieldStyle(.roundedBorder) }
                        }
                    }
                    Text("Display Settings").font(.headline)
                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Step Size")
                                Spacer()
                                HStack {
                                    TextField("1.0", value: $stepSize, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                    Text("Amount to add/subtract with stepper").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            HStack {
                                Text("Display Format")
                                Spacer()
                                Toggle("Show as whole numbers", isOn: $displayAsInteger)
                                    .labelsHidden()
                            }
                        }
                    }
                    Text("Common Settings").font(.headline)
                    SectionCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Examples:").font(.caption).foregroundStyle(.secondary)
                            Text("• Time units: step size 0.5, decimal display").font(.caption2).foregroundStyle(.tertiary)
                            Text("• Distance: step size 0.1, decimal display").font(.caption2).foregroundStyle(.tertiary)
                            Text("• Counts/Reps: step size 1.0, whole numbers").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
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
                                existing.stepSize = stepSize
                                existing.displayAsInteger = displayAsInteger
                                u = existing
                            } else {
                                u = UnitType(name: trimmedName, abbreviation: trimmedAbbr, stepSize: stepSize, displayAsInteger: displayAsInteger)
                                ctx.insert(u)
                            }
                            try ctx.save()
                            onSaved?(u)
                        } catch {
                            print("ERROR: UnitType save failed: \(error)")
                        }
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || stepSize <= 0)
                }
            }
#if os(iOS)
            .presentationDetents([.medium, .large])
            #elseif os(macOS)
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
