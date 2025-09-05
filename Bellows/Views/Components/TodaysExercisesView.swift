import SwiftUI
import SwiftData

struct TodaysExercisesView: View {
    let dayLog: DayLog?
    let onEditItem: (ExerciseItem) -> Void
    let onDeleteItem: (ExerciseItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Exercises")
                    .font(.headline)
                Spacer()
            }
            
            if let dayLog = dayLog, !dayLog.unwrappedItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(dayLog.unwrappedItems.sorted(by: { $0.createdAt > $1.createdAt }), id: \.persistentModelID) { item in
                        ExerciseRowView(
                            item: item,
                            onEdit: { onEditItem(item) },
                            onDelete: { onDeleteItem(item) }
                        )
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
}
