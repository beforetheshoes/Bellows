import SwiftUI
import SwiftData

@MainActor
struct HistoryView: View {
    @Query(sort: \DayLog.date, order: .reverse) private var logs: [DayLog]
    @State private var showCalendarView = true
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    
    init() {}

    var body: some View {
        VStack(spacing: 0) {
            if showCalendarView {
                calendarView
            } else {
                listView
            }
        }
        .navigationTitle("History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button(action: { showCalendarView = true }) {
                        Image(systemName: "calendar")
                            .foregroundColor(showCalendarView ? .accentColor : .secondary)
                    }
                    Button(action: { showCalendarView = false }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(showCalendarView ? .secondary : .accentColor)
                    }
                }
                #if os(iOS)
                .padding(.horizontal, 6)
                #endif
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            // Note: Navigation will happen when user taps on the date in DayDetailView navigation
        }
    }
    
    private var calendarView: some View {
        VStack(spacing: 4) {
            // Small fixed top spacing to separate from nav bar
            Color.clear.frame(height: 8)
            // Month navigation header (single source of truth)
            HStack(alignment: .center) {
                Button(action: { shiftMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Text(monthYearString(currentMonth))
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer(minLength: 8)

                Button(action: { shiftMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Small fixed space below header before weekday row
            Color.clear.frame(height: 6)

            // Weekday labels aligned to user's locale/firstWeekday
            HStack(spacing: 0) {
                ForEach(weekdaySymbolsAligned(), id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(daysForDisplay(), id: \.self) { day in
                    let inMonth = Calendar.current.isDate(day, equalTo: currentMonth, toGranularity: .month)
                    let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                    let hasActivity = activitySet.contains(day.startOfDay())

                    #if os(iOS)
                    Button(action: { selectedDate = day }) {
                        VStack(spacing: 4) {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                }
                                Text("\(Calendar.current.component(.day, from: day))")
                                    .font(.body)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .frame(width: 32, height: 32)
                            }
                            // Dot indicator
                            Circle()
                                .fill(hasActivity ? Color.green.opacity(0.9) : Color.clear)
                                .frame(width: 6, height: 6)
                                .opacity(inMonth ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .foregroundStyle(inMonth ? .primary : .secondary)
                        .opacity(inMonth ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!inMonth)
                    #else
                    NavigationLink(value: day) {
                        VStack(spacing: 4) {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                }
                                Text("\(Calendar.current.component(.day, from: day))")
                                    .font(.body)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .frame(width: 32, height: 32)
                            }
                            // Dot indicator
                            Circle()
                                .fill(hasActivity ? Color.green.opacity(0.9) : Color.clear)
                                .frame(width: 6, height: 6)
                                .opacity(inMonth ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .foregroundStyle(inMonth ? .primary : .secondary)
                        .opacity(inMonth ? 1 : 0.35)
                    }
                    .simultaneousGesture(TapGesture().onEnded { _ in selectedDate = day })
                    .disabled(!inMonth)
                    #endif
                }
            }
            .padding(.horizontal)

            #if os(iOS)
            // Inline details for selected day
            if let day = dayLog(for: selectedDate) {
                if day.unwrappedItems.isEmpty {
                    Text("No items for this day")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(day.unwrappedItems) { item in
                                HStack(alignment: .firstTextBaseline) {
                                    HStack(spacing: 6) {
                                        Text(item.exercise?.name ?? "Exercise")
                                            .font(.body)
                                        Text("·")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formattedTime(item))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    let amt = formattedAmount(item)
                                    if !amt.isEmpty {
                                        Text(amt)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                    }
                    .frame(maxHeight: 260)
                }
            } else {
                Text("No items for this day")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            #endif

            // Activity summary for current month
            if !activeDaysInMonth.isEmpty {
                Text("\(activeDaysInMonth.count) active days this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.default, value: currentMonth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var listView: some View {
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
    
    // Calendar helper functions
    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var activeDaysInMonth: [Date] {
        logs.compactMap { log in
            log.didMove ? log.date.startOfDay() : nil
        }.filter { date in
            Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
        }
    }

    // Fast lookup set for activity days
    private var activitySet: Set<Date> {
        Set(logs.compactMap { $0.didMove ? $0.date.startOfDay() : nil })
    }

    private func shiftMonth(by delta: Int) {
        currentMonth = Calendar.current.date(byAdding: .month, value: delta, to: currentMonth) ?? currentMonth
        // Keep selection within the visible month when shifting
        if !Calendar.current.isDate(selectedDate, equalTo: currentMonth, toGranularity: .month) {
            if let first = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: currentMonth)) {
                selectedDate = first
            }
        }
    }

    // Returns all dates to render in the 7xN grid, including leading/trailing days
    private func daysForDisplay() -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        let monthDays = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }

        // Leading placeholders
        let weekdayOfFirst = calendar.component(.weekday, from: startOfMonth)
        let firstWeekday = calendar.firstWeekday // 1 = Sunday in US locales
        let leadingCount = (weekdayOfFirst - firstWeekday + 7) % 7
        let startOfGrid = calendar.date(byAdding: .day, value: -leadingCount, to: startOfMonth)!

        // Build a grid spanning full weeks to cover the month
        let totalCount = leadingCount + monthDays.count
        // Round up to the next multiple of 7
        let rows = Int(ceil(Double(totalCount) / 7.0))
        let gridCount = rows * 7

        return (0..<gridCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfGrid)
        }
    }

    private func weekdaySymbolsAligned() -> [String] {
        let calendar = Calendar.current
        let symbols = DateFormatter().shortWeekdaySymbols ?? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        let first = calendar.firstWeekday - 1 // symbols are 0-indexed
        return Array(symbols[first...]) + Array(symbols[..<first])
    }
    
    private func dayLog(for date: Date) -> DayLog? {
        let day = date.startOfDay()
        return logs.first(where: { $0.date.startOfDay() == day })
    }

    private func formattedAmount(_ item: ExerciseItem) -> String {
        guard let unit = item.unit else { return "" }
        if unit.displayAsInteger {
            return "\(Int(item.amount)) \(unit.abbreviation)"
        } else {
            let value = (item.amount * 10).rounded() / 10
            return String(format: "%.1f %@", value, unit.abbreviation)
        }
    }

    private func formattedTime(_ item: ExerciseItem) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: item.createdAt)
    }
}
