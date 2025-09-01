import SwiftUI
import SwiftData

@MainActor
struct HistoryView: View {
    @Query(sort: \DayLog.date, order: .reverse) private var logs: [DayLog]
    init() {}

    var body: some View {
        List {
            // Show a continuous 30-day window (including today),
            // synthesizing rows for dates with no DayLog.
            let calendar = Calendar.current
            let today = Date().startOfDay()
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            let byDate = Dictionary(grouping: logs, by: { $0.date.startOfDay() })

            ForEach(0..<30, id: \.self) { i in
                let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
                if let day = byDate[date]?.first {
                    NavigationLink(value: day.date) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(day.didMove ? Color.green.opacity(0.7) : Color.secondary.opacity(0.3))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                if let avgs = dailyAverages(for: day) {
                                    HStack {
                                        Text("\(dateString(day.date))")
                                            .font(.body)
                                        Spacer()
                                        Label("\(Int(round(avgs.enjoyment)))", systemImage: "face.smiling.fill")
                                    }
                                    HStack {
                                        Text("\(day.unwrappedItems.count) logged exercises")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Label("\(Int(round(avgs.intensity)))", systemImage: "flame.fill")
                                    }
                                } else {
                                    Text(dateString(day.date))
                                        .font(.body)
                                    Text("No items")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                } else {
                    NavigationLink(value: date) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(dateString(date))")
                                    .font(.body)
                                Text("No items")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }

            // Append any older logs beyond the 30-day window
            ForEach(logs.filter { $0.date.startOfDay() < start }) { day in
                NavigationLink(value: day.date) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(day.didMove ? Color.green.opacity(0.7) : Color.secondary.opacity(0.3))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            if let avgs = dailyAverages(for: day) {
                                HStack {
                                    Text("\(dateString(day.date))")
                                        .font(.body)
                                    Spacer()
                                    Label("\(Int(round(avgs.enjoyment)))", systemImage: "face.smiling.fill")
                                }
                                HStack {
                                    Text("\(day.unwrappedItems.count) logged exercises")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Label("\(Int(round(avgs.intensity)))", systemImage: "flame.fill")
                                }
                            } else {
                                Text(dateString(day.date))
                                    .font(.body)
                                Text("No items")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }

    // Daily averages for enjoyment and intensity; returns nil if no items
    private func dailyAverages(for d: DayLog) -> (enjoyment: Double, intensity: Double)? {
        let items = d.unwrappedItems
        guard !items.isEmpty else { return nil }
        let eAvg = Double(items.map { $0.enjoyment }.reduce(0, +)) / Double(items.count)
        let iAvg = Double(items.map { $0.intensity }.reduce(0, +)) / Double(items.count)
        return (eAvg, iAvg)
    }
}
