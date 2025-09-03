import SwiftUI
import SwiftData

struct ExerciseRowView: View {
    let item: ExerciseItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
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
                Label("\(item.enjoyment)", systemImage: "face.smiling.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label("\(item.intensity)", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .contextMenu {
            Button("Edit") {
                onEdit()
            }
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
    
    private func label(for item: ExerciseItem) -> String {
        let name = item.exercise?.name ?? "Unknown"
        let abbr = item.unit?.abbreviation ?? ""
        
        // Use the unit's display settings
        let amountStr: String
        if let unit = item.unit {
            if unit.displayAsInteger {
                amountStr = String(Int(item.amount.rounded()))
            } else {
                amountStr = String(format: "%.1f", item.amount)
            }
        } else {
            amountStr = String(format: "%.1f", item.amount)
        }
        
        // For units without abbreviation (like "Reps"), don't show abbreviation
        if abbr.isEmpty {
            return "\(amountStr) \(name)"
        } else {
            return "\(amountStr) \(abbr) \(name)"
        }
    }
    
    private func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: d)
    }
}