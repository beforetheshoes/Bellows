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
    
    // MARK: - Workload Calculations
    
    /// Calculates recent workload based on amount × intensity over the specified number of days
    static func recentWorkload(days: [DayLog], daysBack: Int, calendar: Calendar = .current) -> Double {
        guard daysBack > 0 else { return 0.0 }
        
        let today = Date().startOfDay(calendar: calendar)
        let cutoffDate = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? Date.distantPast
        let recentDays = days.filter { $0.date.startOfDay(calendar: calendar) >= cutoffDate }
        
        var totalWorkload = 0.0
        
        for dayLog in recentDays {
            for item in dayLog.unwrappedItems {
                let normalizedAmount = normalizeUnitValue(amount: item.amount, unit: item.unit)
                totalWorkload += normalizedAmount * Double(item.intensity)
            }
        }
        
        return totalWorkload
    }
    
    /// Calculates EWMA-smoothed workload over recent days
    static func ewmaWorkload(days: [DayLog], daysBack: Int = 7, alpha: Double = 0.3, calendar: Calendar = .current) -> Double {
        guard daysBack > 0 else { return 0.0 }
        
        let today = Date().startOfDay(calendar: calendar)
        let cutoffDate = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? Date.distantPast
        let recentDays = days.filter { $0.date.startOfDay(calendar: calendar) >= cutoffDate }
        
        // Group by date and calculate daily workloads
        let byDate = Dictionary(grouping: recentDays, by: { $0.date.startOfDay(calendar: calendar) })
        var dailyWorkloads: [Double] = []
        
        // Create chronological list of daily workloads
        for i in 0..<daysBack {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dayStart = date.startOfDay(calendar: calendar)
            
            var dayWorkload = 0.0
            if let dayLogs = byDate[dayStart] {
                for dayLog in dayLogs {
                    for item in dayLog.unwrappedItems {
                        let normalizedAmount = normalizeUnitValue(amount: item.amount, unit: item.unit)
                        dayWorkload += normalizedAmount * Double(item.intensity)
                    }
                }
            }
            dailyWorkloads.append(dayWorkload)
        }
        
        // Reverse to get chronological order (oldest first)
        dailyWorkloads.reverse()
        
        guard !dailyWorkloads.isEmpty else { return 0.0 }
        
        let ewmaValues = ewma(values: dailyWorkloads, alpha: alpha)
        return ewmaValues.last ?? 0.0
    }
    
    /// Normalizes unit values to a common scale (minutes equivalent)
    static func normalizeUnitValue(amount: Double, unit: UnitType?) -> Double {
        guard let unit = unit else { return amount }
        
        // Use unit name to determine category and normalization
        let unitName = unit.name.lowercased()
        let unitAbbr = unit.abbreviation.lowercased()
        
        // Time units - 1:1 ratio
        if unitName.contains("minute") || unitName.contains("min") || unitAbbr == "min" ||
           unitName.contains("second") || unitAbbr == "sec" {
            return amount
        }
        
        // Distance units - 1 mile/km ≈ 10 minutes equivalent
        if unitName.contains("mile") || unitAbbr == "mi" ||
           unitName.contains("kilometer") || unitAbbr == "km" ||
           unitName.contains("lap") {
            return amount * 10.0
        }
        
        // Reps/count units - 1 rep ≈ 0.5 minutes equivalent
        if unitName.contains("rep") || unitAbbr == "reps" {
            return amount * 0.5
        }
        
        // Steps units - 100 steps ≈ 1 minute equivalent  
        if unitName.contains("step") || unitAbbr == "steps" {
            return amount / 100.0
        }
        
        // Default to 1:1 ratio for unknown units
        return amount
    }
    
    /// Enhanced ember intensity that combines streak length with recent workload
    static func enhancedEmberIntensity(streak: Int, days: [DayLog]) -> Double {
        guard streak > 0 else { return 0.0 }
        
        // Base intensity from streak length (same as original)
        let streakIntensity = min(1.0, Double(streak) / 30.0)
        
        // Calculate workload boost from recent 7 days
        let recentWorkload = ewmaWorkload(days: days, daysBack: 7)
        
        // Workload boost calculation:
        // - Normalize workload to 0-1 scale (peak around 500 normalized workload units)
        // - Apply diminishing returns using square root
        let workloadBoost = min(0.5, sqrt(recentWorkload) / sqrt(500.0))
        
        // Combine streak and workload with weighting
        // 70% streak importance, 30% workload importance
        let combinedIntensity = (streakIntensity * 0.7) + (workloadBoost * 0.3)
        
        // Cap at maximum intensity
        return min(1.0, combinedIntensity)
    }
}
