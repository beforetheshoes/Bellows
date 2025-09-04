//
//  SettingsView.swift
//  Bellows
//
//  Created by Ryan Williams on 9/2/25.
//

import SwiftUI
import SwiftData
import HealthKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable private var themeManager = ThemeManager.shared
    @Bindable private var healthKitService = HealthKitService.shared
    @State private var showingManageExerciseTypes = false
    @State private var showingHealthKitInfo = false
    
    var body: some View {
        #if os(iOS)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Metrics.spacing) {
                    // Exercise Types
                    Text("Exercise Types").font(.headline)
                    SectionCard {
                        Button(action: { showingManageExerciseTypes = true }) {
                            HStack {
                                Image(systemName: "list.bullet").font(.title3)
                                Text("Manage Exercise Types").font(.headline).fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DS.ColorToken.accent.opacity(0.1))
                            .foregroundStyle(DS.ColorToken.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    // Appearance & Theme
                    Text("Appearance & Theme").font(.headline)
                    SectionCard {
                        VStack(spacing: 12) {
                            LabeledContent("Appearance") {
                                Picker("Appearance", selection: $themeManager.currentAppearanceMode) {
                                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: themeManager.currentAppearanceMode) { _, newMode in
                                    themeManager.setAppearanceMode(newMode)
                                }
                            }

                            LabeledContent("Theme") {
                                Picker("Theme", selection: $themeManager.currentTheme) {
                                    ForEach(Theme.allCases, id: \.self) { theme in
                                        HStack {
                                        Circle()
                                            .fill(theme.accentColor)
                                                .frame(width: 12, height: 12)
                                            Text(theme.displayName)
                                        }
                                        .tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: themeManager.currentTheme) { _, newTheme in
                                    themeManager.setTheme(newTheme)
                                }
                            }
                        }
                    }

                    // Apple Health Integration
                    Text("Apple Health").font(.headline)
                    SectionCard {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(healthKitService.setupState.title)
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    Text(healthKitService.setupState.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if case .ready = healthKitService.setupState {
                                    Toggle("Sync Workouts", isOn: $healthKitService.syncEnabled)
                                        .labelsHidden()
                                }
                            }
                            .padding(.vertical, 4)

                            // Import preference
                            LabeledContent("Import As") {
                                Picker("Import As", selection: $healthKitService.importUnitPreference) {
                                    ForEach(HealthKitService.ImportUnitPreference.allCases) { pref in
                                        Text(pref.displayName).tag(pref)
                                    }
                                }
                                .pickerStyle(.menu)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            
                            // Action buttons based on setup state
                            switch healthKitService.setupState {
                            case .unknown:
                                Button("Check HealthKit Status") {
                                    Task { await healthKitService.checkSetupStatus() }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.bordered)
                                
                            case .unsupported:
                                // No action needed - just shows info
                                EmptyView()
                                
                            case .needsPermission:
                                Button("Grant HealthKit Access") {
                                    Task {
                                        await healthKitService.requestAuthorization()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                
                            case .ready:
                                VStack(alignment: .leading, spacing: 8) {
                                    // Side-by-side actions with app-consistent rounded corners
                                    HStack(spacing: 10) {
                                        // Left: Sync Now (regular)
                                        Button {
                                            Task { await healthKitService.syncRecentWorkouts(days: 7, modelContext: modelContext) }
                                        } label: {
                                            Label("Sync Now", systemImage: "arrow.clockwise")
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(DS.ColorToken.accent.opacity(0.12))
                                                .foregroundStyle(DS.ColorToken.accent)
                                                .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                                        }
                                        .buttonStyle(.plain)

                                        // Right: Choose Imports (override dedupe)
                                        Button {
                                            showingHealthKitInfo = true
                                        } label: {
                                            Label("Choose Imports", systemImage: "square.and.arrow.down")
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(DS.ColorToken.card)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous)
                                                        .stroke(DS.ColorToken.accent.opacity(0.3), lineWidth: 1)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(healthKitService.isSyncing || !healthKitService.syncEnabled)
                                    }

                                    // Brief explanations
                                    VStack(alignment: .leading, spacing: 4) {
                                        (Text("Sync Now: ").fontWeight(.semibold) + Text("perform a regular import from Apple Health."))
                                        (Text("Choose Imports: ").fontWeight(.semibold) + Text("override de‑duplication; use if a workout didn’t import."))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)

                                    // Background sync note
                                    Text("Background sync runs automatically when ‘Sync Workouts’ is enabled. These controls are optional for extra control or to fix a missing workout.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 6)

                                    // Bottom status row (always visible): last sync (left) and imported count (right)
                                    HStack {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary)
                                            if let last = healthKitService.lastSyncDate {
                                                Text("Last: ") + Text(last, style: .relative)
                                            } else {
                                                Text("Last: Never")
                                            }
                                        }
                                        .foregroundStyle(.secondary)
                                        Spacer()
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                            let importedCount: Int = {
                                                if case .success(let c)? = healthKitService.lastSyncResult { return c } else { return 0 }
                                            }()
                                            Text("Imported: \(importedCount)")
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .font(.caption)
                                }
                
                            case .error(let error):
                                VStack(spacing: 8) {
                                    Text(error.localizedDescription)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Button("Try Again") {
                                        Task { await healthKitService.checkSetupStatus() }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }

                    // Data Export
                    Text("Data Management").font(.headline)
                    SectionCard {
                        HStack { Text("Export Data"); Spacer(); Text("Coming Soon").foregroundStyle(.secondary) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingManageExerciseTypes) { ManageExerciseTypesView() }
            .sheet(isPresented: $showingHealthKitInfo) {
                ImportRecentWorkoutsSheet()
            }
            .task {
                await healthKitService.checkSetupStatus()
            }
            .preferredColorScheme(themeManager.currentAppearanceMode.colorScheme)
        }
        #else
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Metrics.spacing) {
                    // Exercise Types
                    Text("Exercise Types").font(.headline)
                    SectionCard {
                        Button(action: { showingManageExerciseTypes = true }) {
                            HStack {
                                Image(systemName: "list.bullet").font(.title3)
                                Text("Manage Exercise Types").font(.headline).fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(DS.ColorToken.accent.opacity(0.1))
                            .foregroundStyle(DS.ColorToken.accent)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Metrics.chipCorner, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    // Appearance & Theme
                    Text("Appearance & Theme").font(.headline)
                    SectionCard {
                        VStack(spacing: 12) {
                            #if os(macOS)
                            HStack {
                                Text("Appearance")
                                Spacer()
                                Picker("Appearance", selection: $themeManager.currentAppearanceMode) {
                                    ForEach(AppearanceMode.allCases, id: \.self) { mode in Text(mode.displayName).tag(mode) }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .onChange(of: themeManager.currentAppearanceMode) { _, newMode in themeManager.setAppearanceMode(newMode) }
                            }
                            .frame(maxWidth: .infinity)
                            
                            HStack {
                                Text("Theme")
                                Spacer()
                                Picker("Theme", selection: $themeManager.currentTheme) {
                                    ForEach(Theme.allCases, id: \.self) { theme in
                                        HStack { Circle().fill(theme.accentColor).frame(width: 12, height: 12); Text(theme.displayName) }.tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .onChange(of: themeManager.currentTheme) { _, newTheme in themeManager.setTheme(newTheme) }
                            }
                            .frame(maxWidth: .infinity)
                            #else
                            LabeledContent("Appearance") {
                                Picker("Appearance", selection: $themeManager.currentAppearanceMode) {
                                    ForEach(AppearanceMode.allCases, id: \.self) { mode in Text(mode.displayName).tag(mode) }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: themeManager.currentAppearanceMode) { _, newMode in themeManager.setAppearanceMode(newMode) }
                            }

                            LabeledContent("Theme") {
                                Picker("Theme", selection: $themeManager.currentTheme) {
                                    ForEach(Theme.allCases, id: \.self) { theme in
                                        HStack { Circle().fill(theme.accentColor).frame(width: 12, height: 12); Text(theme.displayName) }.tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: themeManager.currentTheme) { _, newTheme in themeManager.setTheme(newTheme) }
                            }
                            #endif
                        }
                    }

                    // Apple Health Integration
                    Text("Apple Health").font(.headline)
                    SectionCard {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(healthKitService.setupState.title)
                                        .font(.headline)
                                        .fontWeight(.medium)
                                    Text(healthKitService.setupState.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if case .ready = healthKitService.setupState {
                                    Toggle("Sync Workouts", isOn: $healthKitService.syncEnabled)
                                        .labelsHidden()
                                }
                            }
                            .padding(.vertical, 4)
                            // Action buttons based on setup state
                            switch healthKitService.setupState {
                            case .unknown:
                                Button("Check HealthKit Status") {
                                    Task { await healthKitService.checkSetupStatus() }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.bordered)
                                
                            case .unsupported:
                                // No action needed - just shows info
                                EmptyView()
                                
                            case .needsPermission:
                                Button("Grant HealthKit Access") {
                                    Task {
                                        await healthKitService.requestAuthorization()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .buttonStyle(.borderedProminent)
                                
                            case .ready:
                                VStack(spacing: 6) {
                                    HStack(spacing: 8) {
                                        Button("Import Recent Workouts…") { showingHealthKitInfo = true }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                        Button(healthKitService.isSyncing ? "Syncing…" : "Sync Recent") {
                                            Task { await healthKitService.syncRecentWorkouts(days: 7, modelContext: modelContext) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(healthKitService.isSyncing || !healthKitService.syncEnabled)
                                    }

                                    // Compact status row
                                    HStack(spacing: 10) {
                                        if let result = healthKitService.lastSyncResult {
                                            switch result {
                                            case .success(let count):
                                                HStack(spacing: 4) {
                                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                                    Text(count > 0 ? "Imported \(count)" : "No new workouts")
                                                }
                                                .foregroundStyle(count > 0 ? .green : .secondary)
                                            case .error(let message):
                                                HStack(spacing: 4) {
                                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                                    Text(message)
                                                }
                                                .foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                    .font(.caption)
                                }
                                
                            case .error(let error):
                                VStack(spacing: 8) {
                                    Text(error.localizedDescription)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Button("Try Again") {
                                        Task { await healthKitService.checkSetupStatus() }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }

                    // Data Export
                    Text("Data Management").font(.headline)
                    SectionCard {
                        HStack { Text("Export Data"); Spacer(); Text("Coming Soon").foregroundStyle(.secondary) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingManageExerciseTypes) { ManageExerciseTypesView() }
            .sheet(isPresented: $showingHealthKitInfo) {
                ImportRecentWorkoutsSheet()
            }
            .task {
                await healthKitService.checkSetupStatus()
            }
            .macPresentationFitted()
            .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
            .preferredColorScheme(themeManager.currentAppearanceMode.colorScheme)
        }
        #endif
    }
}

#if os(macOS)
private extension View {
    @ViewBuilder
    func macPresentationFitted() -> some View {
        if #available(macOS 15.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
    }
}
#endif

// SectionCard is defined in Components/SectionCard.swift

// Fallback definition here to ensure availability even if Xcode target membership
// isn't set for the separate file. If the separate file is included, this
// duplicate will be optimized away by removing this block.
@MainActor
struct ImportRecentWorkoutsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable private var service = HealthKitService.shared

    @State private var isLoading = true
    @State private var errorText: String?
    @State private var rows: [WorkoutRow] = []
    @State private var importing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let err = errorText { Text(err).foregroundStyle(.red).font(.footnote) }
                List {
                    ForEach(rows) { row in
                        HStack(spacing: 12) {
                            Toggle(isOn: binding(for: row.id)) { EmptyView() }
                                .labelsHidden()
                                .toggleStyle(.switch)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title).font(.headline)
                                Text(row.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .overlay { if isLoading { ProgressView().controlSize(.large) } }
                .disabled(importing || isLoading)

                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                    Button(importing ? "Importing…" : "Import Selected") { Task { await importSelected() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(importing || rows.allSatisfy { !$0.selected })
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Import Recent Workouts")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task { await loadRecent() }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding {
            rows.first(where: { $0.id == id })?.selected ?? false
        } set: { newValue in
            if let idx = rows.firstIndex(where: { $0.id == id }) {
                rows[idx].selected = newValue
            }
        }
    }

    private func loadRecent() async {
        isLoading = true
        defer { isLoading = false }
        errorText = nil
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: end) ?? end
        let workouts = await service.fetchWorkouts(from: start, to: end)
        let sorted = workouts.sorted { $0.startDate > $1.startDate }
        let lastFive = Array(sorted.prefix(5))
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        rows = lastFive.map { w in
            let title = service.mapActivityTypeToExerciseName(w.workoutActivityType)
            let detail: String = {
                switch service.importUnitPreference {
                case .time, .auto:
                    // Prefer minutes for preview unless preference is distance
                    let minutes = Int((w.duration / 60.0).rounded())
                    return "\(minutes) min"
                case .distance:
                    if let meters = w.totalDistance?.doubleValue(for: HKUnit.meter()) {
                        let useMiles: Bool = {
                            if let region = Locale.current.region?.identifier { return ["US","LR","MM","GB"].contains(region) }
                            return false
                        }()
                        if useMiles {
                            let miles = meters / 1609.344
                            return String(format: "%.2f mi", miles)
                        } else {
                            let km = meters / 1000.0
                            return String(format: "%.2f km", km)
                        }
                    } else {
                        let minutes = Int((w.duration / 60.0).rounded())
                        return "\(minutes) min"
                    }
                }
            }()
            let subtitle = "\(df.string(from: w.startDate)) – \(detail)"
            return WorkoutRow(id: w.uuid, workout: w, title: title, subtitle: subtitle, selected: true)
        }
        if rows.isEmpty { errorText = "No recent workouts found." }
    }

    private func importSelected() async {
        importing = true
        defer { importing = false }
        let selected = rows.filter { $0.selected }.map { $0.workout }
        let count = await service.importSpecificWorkoutsIgnoringDedup(selected, modelContext: modelContext)
        if count >= 0 { dismiss() }
    }
}

private struct WorkoutRow: Identifiable {
    let id: UUID
    let workout: WorkoutProtocol
    let title: String
    let subtitle: String
    var selected: Bool
}
