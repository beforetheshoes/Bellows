import SwiftUI
import SwiftData

@MainActor
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Query(sort: \ExerciseType.name) private var exerciseTypes: [ExerciseType]
    @Query(sort: \UnitType.name) private var unitTypes: [UnitType]

    var body: some View {
        Group {
            #if os(iOS)
            if hSizeClass == .regular {
                SplitLayout()
            } else {
                PhoneLayout()
            }
            #else
            SplitLayout()
            #endif
        }
        .onAppear { seedDefaultsIfNeeded() }
    }

    // Idempotent seeding: ensure defaults exist without creating duplicates.
    private func seedDefaultsIfNeeded() {
        seedDefaultExercises()
        seedDefaultUnits()
    }

    private func seedDefaultExercises() {
        // Ensure each default exists (case-insensitive by name)
        let defaults = SeedDefaults.exerciseTypes

        for (rawName, met, repW, pace, icon) in defaults {
            let name = rawName.trimmingCharacters(in: .whitespaces)
            if let existing = exerciseTypes.first(where: { $0.name.lowercased() == name.lowercased() }) {
                _ = existing // already present; avoid duplicate
            } else {
                let e = ExerciseType(name: name, baseMET: met, repWeight: repW, defaultPaceMinPerMi: pace, iconSystemName: icon)
                modelContext.insert(e)
            }
        }
        do { try modelContext.save() } catch { print("ERROR: Seed exercises save failed: \(error)") }
    }

    private func seedDefaultUnits() {
        // Ensure each default exists (case-insensitive by name). If present but abbreviation empty, fill it in.
        let defaults = SeedDefaults.unitTypes

        for (rawName, rawAbbr, cat) in defaults {
            let name = rawName.trimmingCharacters(in: .whitespaces)
            let abbr = rawAbbr.trimmingCharacters(in: .whitespaces)
            if let existing = unitTypes.first(where: { $0.name.lowercased() == name.lowercased() }) {
                if existing.abbreviation.trimmingCharacters(in: .whitespaces).isEmpty {
                    existing.abbreviation = abbr
                }
                // Keep existing category to respect user edits
            } else {
                let u = UnitType(name: name, abbreviation: abbr, category: cat)
                modelContext.insert(u)
            }
        }
        do { try modelContext.save() } catch { print("ERROR: Seed units save failed: \(error)") }
    }
}

@MainActor
private struct PhoneLayout: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
        }
    }
}

@MainActor
private struct SplitLayout: View {
    var body: some View {
        NavigationSplitView {
            HistoryView()
        } detail: {
            HomeView()
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
    }
}
