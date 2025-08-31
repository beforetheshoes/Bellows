Heck yes—this is totally buildable in SwiftUI/SwiftData as a single “Daily Exercise” log with itemized entries, a **binary streak** (any items today = streak continues), a **smoothed intensity trend**, and a **one-tap, beautiful input** flow across iOS/iPadOS/macOS.

Here’s a tight blueprint + working skeleton to get you moving fast.

------

# Core idea

- **One log per day** (`DayLog`), not one habit per activity.
- Each day contains a **list of items** (`ExerciseItem`) like “10 pushups”, “30-min walk”.
- **Streak** = number of consecutive days (including today) with at least one item.
- **Intensity** = sum of item scores (simple MET-ish heuristic) → smoothed into an **EWMA trend**.
- **Enjoyment** = 1–5 daily slider (fast, frictionless).

------

# Data model (SwiftData)

```swift
import SwiftData
import Foundation

@Model
final class DayLog {
    // Always store date at start-of-day in the user's calendar
    @Attribute(.unique) var date: Date
    var items: [ExerciseItem] = []
    var enjoyment: Int = 3  // 1..5; optional but defaults mid
    var notes: String? = nil

    init(date: Date) {
        self.date = date.startOfDay()
    }

    var didMove: Bool { !items.isEmpty }

    // Sum of item intensities (see heuristic below)
    var intensityScore: Double {
        items.reduce(0) { $0 + $1.intensityScore }
    }
}

@Model
final class ExerciseItem {
    var createdAt: Date
    var kind: ActivityKind
    var unit: ActivityUnit
    var amount: Double        // minutes, reps, steps, etc.
    var note: String?

    init(kind: ActivityKind, unit: ActivityUnit, amount: Double, note: String? = nil, at: Date = .now) {
        self.kind = kind
        self.unit = unit
        self.amount = amount
        self.note = note
        self.createdAt = at
    }

    // Heuristic scoring: simple, calibratable
    var intensityScore: Double {
        let met = kind.baseMET
        switch unit {
        case .minutes:
            return met * amount
        case .reps:
            // Convert reps to "met-min" roughness; tweak per kind
            return kind.repWeight * amount
        case .steps:
            // ~100 steps ≈ 1 min of easy walking
            let minutes = amount / 100.0
            return 3.0 * minutes
        case .distanceKm:
            // Convert km to minutes using an assumed pace, then MET
            let minutes = kind.defaultPaceMinPerKm * amount
            return met * minutes
        case .other:
            return met * amount
        }
    }
}

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case walk, run, cycling, pushups, squats, plank, yoga, other
    var id: String { rawValue }

    // Baseline MET-ish values; tune in Settings
    var baseMET: Double {
        switch self {
        case .walk:   return 3.3
        case .run:    return 9.8
        case .cycling:return 6.8
        case .yoga:   return 2.5
        case .plank:  return 3.8
        case .pushups:return 8.0
        case .squats: return 5.0
        case .other:  return 4.0
        }
    }

    // Rough “reps→intensity” scalar (met-min per rep)
    var repWeight: Double {
        switch self {
        case .pushups: return 0.6
        case .squats:  return 0.25
        default:       return 0.15
        }
    }

    // Defaults used when logging distance
    var defaultPaceMinPerKm: Double {
        switch self {
        case .walk:   return 12.0
        case .run:    return 6.0
        case .cycling:return 2.0  // 30 km/h ~ 2 min/km
        default:      return 10.0
        }
    }
}

enum ActivityUnit: String, Codable, CaseIterable, Identifiable {
    case minutes, reps, steps, distanceKm, other
    var id: String { rawValue }
}

extension Date {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}
```

**Why this works:** the **day** is the unit of success (matches your streak psychology), and items are just details inside that day. Intensity/enjoyment live at day level to keep input fast.

------

# Streak + Trend logic

```swift
import Foundation

struct Analytics {
    // Count from 'today' backwards until you hit a blank day.
    static func currentStreak(days: [DayLog], calendar: Calendar = .current) -> Int {
        let byDate = Dictionary(grouping: days, by: { $0.date.startOfDay(calendar: calendar) })
        var streak = 0
        var d = Date().startOfDay(calendar: calendar)
        while true {
            if let logs = byDate[d], logs.first?.didMove == true {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: d) else { break }
                d = prev
            } else {
                break
            }
        }
        return streak
    }

    // Exponentially Weighted Moving Average for smooth “intensity trend”
    static func ewma(values: [Double], alpha: Double = 0.3) -> [Double] {
        guard !values.isEmpty else { return [] }
        var output: [Double] = []
        var last = values[0]
        for v in values {
            let next = alpha * v + (1 - alpha) * last
            output.append(next)
            last = next
        }
        return output
    }

    // Label today’s intensity relative to last 14 days
    static func todayBand(today: Double, history: [Double]) -> String {
        guard !history.isEmpty else { return "—" }
        let mean = history.reduce(0, +) / Double(history.count)
        let variance = history.reduce(0) { $0 + pow($1 - mean, 2) } / Double(history.count)
        let sd = sqrt(variance)
        switch today {
        case ..<mean - 0.5*sd: return "low"
        case (mean - 0.5*sd)...(mean + 0.5*sd): return "medium"
        default: return "high"
        }
    }
}
```

------

# UI skeleton (fast, one-tap logging)

```swift
import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DayLog.date, order: .reverse) private var logs: [DayLog]

    @State private var today: DayLog?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                quickAdd
                enjoymentRow
                todayList
                trendCard
            }
            .padding()
            .navigationTitle("Move, Daily")
            .onAppear { ensureToday() }
        }
    }

    private var header: some View {
        HStack {
            Text(dateString(Date()))
                .font(.title2).bold()
            Spacer()
            Text("Streak \(Analytics.currentStreak(days: logs)) 🔥")
                .font(.headline)
        }
    }

    // One-tap chips that add an item to *today’s* log
    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Add")
                .font(.headline)
            FlowLayout(spacing: 8) {
                QuickButton("10 pushups") { add(.pushups, .reps, 10) }
                QuickButton("20 squats")  { add(.squats,  .reps, 20) }
                QuickButton("10-min walk"){ add(.walk,    .minutes, 10) }
                QuickButton("30-min walk"){ add(.walk,    .minutes, 30) }
                QuickButton("Plank 60s")  { add(.plank,   .minutes, 1) }
                QuickButton("1 km run")   { add(.run,     .distanceKm, 1) }
            }
        }
    }

    private var enjoymentRow: some View {
        HStack {
            Text("Enjoyment")
            Spacer()
            if let today {
                Stepper(value: Binding(
                    get: { today.enjoyment },
                    set: { today.enjoyment = max(1, min(5, $0)) }
                ), in: 1...5) {
                    Text("\(today.enjoyment) \(emoji(for: today.enjoyment))")
                }
            } else {
                Text("—")
            }
        }
        .font(.subheadline)
    }

    private var todayList: some View {
        Group {
            if let today, today.items.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(Text("No items yet—add one above").padding())
                    .frame(height: 80)
            } else if let today {
                List {
                    Section("Today’s Items") {
                        ForEach(today.items) { item in
                            HStack {
                                Text(label(for: item))
                                Spacer()
                                Text(scoreString(item.intensityScore))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexes in
                            indexes.compactMap { today.items[$0] }.forEach(modelContext.delete)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .frame(maxHeight: 260)
            }
        }
    }

    private var trendCard: some View {
        let recent = Array(logs.prefix(21)).reversed() // oldest→newest
        let values = recent.map { $0.intensityScore }
        let smooth = Analytics.ewma(values: values)
        let todayIntensity = today?.intensityScore ?? 0
        let band = Analytics.todayBand(today: todayIntensity, history: Array(values.dropLast()))

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Intensity Trend")
                    .font(.headline)
                Spacer()
                Text("Today: \(band)")
                    .foregroundStyle(.secondary)
            }
            if smooth.count > 1 {
                Chart {
                    ForEach(Array(smooth.enumerated()), id: \.offset) { i, v in
                        LineMark(x: .value("Day", i), y: .value("EWMA", v))
                    }
                    if let last = smooth.last {
                        PointMark(x: .value("Day", smooth.count - 1),
                                  y: .value("EWMA", last))
                    }
                }
                .frame(height: 140)
            } else {
                Text("Not enough history yet.")
                    .foregroundStyle(.secondary)
                    .frame(height: 140, alignment: .center)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    // MARK: helpers

    private func ensureToday() {
        let key = Date().startOfDay()
        if let existing = logs.first(where: { $0.date == key }) {
            today = existing
            return
        }
        let new = DayLog(date: key)
        modelContext.insert(new)
        today = new
    }

    private func add(_ kind: ActivityKind, _ unit: ActivityUnit, _ amount: Double) {
        guard let today else { return }
        today.items.append(ExerciseItem(kind: kind, unit: unit, amount: amount))
        // No need to save explicitly; SwiftData auto-saves on change by default.
    }

    private func label(for item: ExerciseItem) -> String {
        switch item.unit {
        case .reps: return "\(Int(item.amount)) \(item.kind.rawValue.capitalized)"
        case .minutes: return "\(Int(item.amount)) min \(item.kind.rawValue)"
        case .steps: return "\(Int(item.amount)) steps \(item.kind.rawValue)"
        case .distanceKm: return "\(trim(item.amount)) km \(item.kind.rawValue)"
        case .other: return "\(trim(item.amount)) \(item.kind.rawValue)"
        }
    }

    private func scoreString(_ s: Double) -> String { String(format: "%.0f", s) }
    private func trim(_ d: Double) -> String { String(format: "%g", d) }
    private func emoji(for e: Int) -> String { ["😖","🙁","😐","🙂","🤩"][max(1,min(5,e))-1] }
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .full; return f.string(from: d)
    }
}

// Simple flow layout for chips
struct FlowLayout<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content
    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                content
                    .fixedSize()
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0; height -= (d.height + spacing)
                        }
                        let result = width
                        width -= (d.width + spacing)
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        return result
                    }
            }
        }
        .frame(height: 120)
    }
}

// Reusable chip button
struct QuickButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(title).padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(.thinMaterial)
        .clipShape(Capsule())
    }
}
```

> **Design notes**
>
> - “**Any items today**” keeps your streak alive (binary, not ring math).
> - Quick-add chips make logging **one tap**.
> - Enjoyment is **right on the main view** (no modal friction).
> - Trend uses **EWMA** so a single huge day doesn’t whiplash the chart.

------

# Multi-platform + Sync

**App target:** iOS 17+/iPadOS/macOS 14+ (unified SwiftUI).
**Sync:** SwiftData + CloudKit container.

```swift
// In your @main App
import SwiftUI
import SwiftData

@main
struct MoveDailyApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [DayLog.self, ExerciseItem.self],
                        configurations: ModelConfiguration(isStoredInMemoryOnly: false, cloudKitDatabase: .automatic))
    }
}
```

------

# Optional niceties (you can add later)

- **HealthKit import**: auto-add Walk/Run workouts or Steps as items (keeps your “one log per day” model, but reduces manual entry).
- **Widgets**: “Add 10 pushups”/“Add 10-min walk” buttons via App Intents.
- **Shortcuts**: voice log from Apple Watch (“Add 20 squats”).
- **Export**: Markdown/CSV → Obsidian (fits your vault workflow).
- **Customization**: editable quick-add chips + per-kind weights (purists can tweak METs, you can keep defaults).

------

# Why this fits you

- Preserves your **streak psychology** without the brittle ring thresholds.
- **Ice-cream-friendly**: success is doing *something*, not burning a number of calories.
- **Strength days count** even if they’re short (you can log one set and keep momentum).
- Beautiful, minimal UI; super-low friction.

If you want, I can layer in **HealthKit read** (steps/workouts) and **Widgets/App Intents** next so you can add items from the Lock Screen/Watch with one tap or voice.