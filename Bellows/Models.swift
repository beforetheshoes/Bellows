import Foundation
import SwiftData
import CloudKit

@Model
final class DayLog {
    var date: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \ExerciseItem.dayLog) var items: [ExerciseItem]? = []
    var notes: String? = nil
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(date: Date) {
        self.date = date.startOfDay()
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
    
    var unwrappedItems: [ExerciseItem] {
        items ?? []
    }

    var didMove: Bool { !unwrappedItems.isEmpty }

    var intensityScore: Double {
        unwrappedItems.reduce(0) { $0 + $1.intensityScore }
    }
}

enum UnitCategory: String, Codable, CaseIterable, Identifiable {
    case minutes, reps, steps, distanceMi, other
    var id: String { rawValue }
}

@Model
final class UnitType {
    var name: String = "Unknown"
    var abbreviation: String = ""
    var category: UnitCategory = UnitCategory.other
    @Relationship(inverse: \ExerciseItem.unit) var exerciseItems: [ExerciseItem]? = []
    var createdAt: Date = Date()

    init(name: String, abbreviation: String, category: UnitCategory) {
        self.name = name
        self.abbreviation = abbreviation
        self.category = category
        self.createdAt = Date()
    }
}

@Model
final class ExerciseType {
    var name: String = "Unknown"
    var baseMET: Double = 4.0
    var repWeight: Double = 0.15
    var defaultPaceMinPerMi: Double = 10.0
    @Relationship(inverse: \ExerciseItem.exercise) var exerciseItems: [ExerciseItem]? = []
    var iconSystemName: String?
    var createdAt: Date = Date()

    init(name: String, baseMET: Double, repWeight: Double, defaultPaceMinPerMi: Double, iconSystemName: String? = nil) {
        self.name = name
        self.baseMET = baseMET
        self.repWeight = repWeight
        self.defaultPaceMinPerMi = defaultPaceMinPerMi
        self.iconSystemName = iconSystemName
        self.createdAt = Date()
    }
}

@Model
final class ExerciseItem {
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var dayLog: DayLog?
    var exercise: ExerciseType?
    var unit: UnitType?
    var amount: Double = 0.0
    var note: String?
    var enjoyment: Int = 3 // 1..5 per item
    var intensity: Int = 3 // 1..5 per item

    init(exercise: ExerciseType, unit: UnitType, amount: Double, note: String? = nil, enjoyment: Int = 3, intensity: Int = 3, at: Date = .now) {
        self.exercise = exercise
        self.unit = unit
        self.amount = amount
        self.note = note
        self.enjoyment = max(1, min(5, enjoyment))
        self.intensity = max(1, min(5, intensity))
        self.createdAt = at
        self.modifiedAt = Date()
    }

    // Convenience initializer for intensity-only logging (no unit/amount)
    init(exercise: ExerciseType, note: String? = nil, enjoyment: Int = 3, intensity: Int = 3, at: Date = .now) {
        self.exercise = exercise
        self.unit = nil
        self.amount = 0
        self.note = note
        self.enjoyment = max(1, min(5, enjoyment))
        self.intensity = max(1, min(5, intensity))
        self.createdAt = at
        self.modifiedAt = Date()
    }

    var intensityScore: Double { Double(intensity) }
}

extension Date {
    func startOfDay(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
}

// Seed helpers
struct SeedDefaults {
    static let unitTypes: [(String, String, UnitCategory)] = [
        ("Minutes", "min", .minutes),
        ("Reps", "reps", .reps),
        ("Steps", "steps", .steps),
        ("Miles", "mi", .distanceMi),
        ("Other", "", .other)
    ]

    static let exerciseTypes: [(String, Double, Double, Double, String?)] = [
        ("Walk", 3.3, 0.15, 12.0, "figure.walk"),
        ("Run", 9.8, 0.15, 6.0, "figure.run"),
        ("Cycling", 6.8, 0.15, 2.0, "bicycle"),
        ("Yoga", 2.5, 0.15, 10.0, "figure.mind.and.body"),
        ("Plank", 3.8, 0.15, 10.0, "figure.core.training"),
        ("Pushups", 8.0, 0.6, 10.0, "figure.strengthtraining.traditional"),
        ("Squats", 5.0, 0.25, 10.0, "figure.strengthtraining.functional"),
        ("Other", 4.0, 0.15, 10.0, "square.grid.2x2")
    ]
}
