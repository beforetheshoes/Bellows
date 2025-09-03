import SwiftData
import Foundation

@MainActor
struct DedupService {
    static func cleanupDuplicateDayLogs(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<DayLog>())
            let grouped = Dictionary(grouping: all) { $0.date.startOfDay() }
            
            for (_, logs) in grouped {
                if logs.count > 1 {
                    // Keep the one with the most recent createdAt (or most items if createdAt is same)
                    let keeper = logs.max { a, b in
                        if a.createdAt == b.createdAt {
                            return (a.items?.count ?? 0) < (b.items?.count ?? 0)
                        }
                        return a.createdAt < b.createdAt
                    }
                    
                    for log in logs {
                        if log !== keeper {
                            // Move items from duplicate to keeper before deletion
                            if let items = log.items, let keeperLog = keeper {
                                if keeperLog.items == nil {
                                    keeperLog.items = []
                                }
                                for item in items {
                                    keeperLog.items?.append(item)
                                }
                            }
                            context.delete(log)
                        }
                    }
                }
            }
            
            try context.save()
        } catch {
            print("ERROR: cleanupDuplicateDayLogs failed: \(error)")
        }
    }
    
    static func cleanupDuplicateExerciseTypes(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<ExerciseType>())
            let grouped = Dictionary(grouping: all) { $0.name.lowercased() }
            
            for (_, types) in grouped {
                if types.count > 1 {
                    // Keep the one with the most recent createdAt
                    let keeper = types.max { $0.createdAt < $1.createdAt }
                    
                    for type in types {
                        if type !== keeper {
                            // Reassign any ExerciseItems pointing at the duplicate
                            if let items = type.exerciseItems, let keepRef = keeper {
                                for item in items {
                                    item.exercise = keepRef
                                }
                            }
                            context.delete(type)
                        }
                    }
                }
            }
            
            try context.save()
        } catch {
            print("ERROR: cleanupDuplicateExerciseTypes failed: \(error)")
        }
    }
    
    static func cleanupDuplicateUnitTypes(context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<UnitType>())
            let grouped = Dictionary(grouping: all) { $0.name.lowercased() }
            
            for (_, types) in grouped {
                if types.count > 1 {
                    // Keep the one with the most recent createdAt
                    let keeper = types.max { $0.createdAt < $1.createdAt }
                    
                    for type in types {
                        if type !== keeper {
                            // Reassign ExerciseItems and ExerciseTypes defaults
                            if let items = type.exerciseItems, let keepRef = keeper {
                                for item in items { item.unit = keepRef }
                            }
                            if let defaults = type.exerciseTypesUsingAsDefault, let keepRef = keeper {
                                for ex in defaults { ex.defaultUnit = keepRef }
                            }
                            context.delete(type)
                        }
                    }
                }
            }
            
            try context.save()
        } catch {
            print("ERROR: cleanupDuplicateUnitTypes failed: \(error)")
        }
    }
}
