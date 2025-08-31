import SwiftUI
import SwiftData

@MainActor
struct HistoryView: View {
    @Query(sort: \DayLog.date, order: .reverse) private var logs: [DayLog]
    init() {}

    var body: some View {
        List {
            ForEach(logs) { day in
                NavigationLink(value: day.date) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(day.didMove ? Color.green.opacity(0.7) : Color.secondary.opacity(0.3))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateString(day.date))
                                .font(.body)
                            Text(summary(for: day))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if day.didMove {
                            Text(String(format: "%.0f", day.intensityScore))
                                .font(.subheadline).foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }

    private func summary(for d: DayLog) -> String {
        if d.unwrappedItems.isEmpty { return "No items" }
        if d.unwrappedItems.count == 1 { return label(for: d.unwrappedItems[0]) }
        return "\(d.unwrappedItems.count) items"
    }

    private func label(for item: ExerciseItem) -> String {
        let name = item.exercise?.name ?? "Unknown"
        let abbr = item.unit?.abbreviation ?? ""
        switch item.unit?.category ?? .other {
        case .reps:
            return "\(Int(item.amount)) \(name)"
        case .minutes:
            return "\(Int(item.amount)) \(abbr) \(name)"
        case .steps:
            return "\(Int(item.amount)) \(abbr) \(name)"
        case .distanceMi:
            return String(format: "%.1f %@ %@", item.amount, abbr, name)
        case .other:
            return String(format: "%.1f %@ %@", item.amount, abbr, name)
        }
    }
}
