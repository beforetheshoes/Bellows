import Foundation

struct Analytics {
    static func currentStreak(days: [DayLog], calendar: Calendar = .current) -> Int {
        let byDate = Dictionary(grouping: days, by: { $0.date.startOfDay(calendar: calendar) })
        var streak = 0
        let today = Date().startOfDay(calendar: calendar)
        
        // Start checking from yesterday, not today
        // This allows today to be empty without breaking the streak
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        
        var d = yesterday
        while true {
            if let logs = byDate[d], logs.first?.didMove == true {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: d) else { break }
                d = prev
            } else {
                break
            }
        }
        
        // If today has activity, include it in the streak
        if let todayLogs = byDate[today], todayLogs.first?.didMove == true {
            streak += 1
        }
        
        return streak
    }

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

    static func todayBand(today: Double, history: [Double]) -> String {
        guard !history.isEmpty else { return "—" }
        let mean = history.reduce(0, +) / Double(history.count)
        let variance = history.reduce(0) { $0 + pow($1 - mean, 2) } / Double(history.count)
        let sd = sqrt(variance)
        switch today {
        case ..<(mean - 0.5*sd): return "low"
        case (mean - 0.5*sd)...(mean + 0.5*sd): return "medium"
        default: return "high"
        }
    }
}
