import SwiftUI

@MainActor
struct NoteSection: View {
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
        .listRowBackground(
            RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius)
                .fill(DS.ColorToken.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Metrics.cornerRadius)
                        .stroke(DS.ColorToken.accent, lineWidth: 3)
                )
                .padding(.vertical, 2)
        )
    }
}