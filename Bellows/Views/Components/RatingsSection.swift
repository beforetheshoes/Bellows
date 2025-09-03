import SwiftUI

@MainActor
struct RatingsSection: View {
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