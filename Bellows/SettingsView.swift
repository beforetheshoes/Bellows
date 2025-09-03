//
//  SettingsView.swift
//  Bellows
//
//  Created by Ryan Williams on 9/2/25.
//

import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showingManageExerciseTypes = false
    
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

                    // Data Management
                    Text("Data Management").font(.headline)
                    SectionCard {
                        VStack(spacing: 12) {
                            HStack { Text("Import Data"); Spacer(); Text("Coming Soon").foregroundStyle(.secondary) }
                            HStack { Text("Export Data"); Spacer(); Text("Coming Soon").foregroundStyle(.secondary) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingManageExerciseTypes) { ManageExerciseTypesView() }
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

                    // Data Management
                    Text("Data Management").font(.headline)
                    SectionCard {
                        VStack(spacing: 12) {
                            HStack { Text("Import Data"); Spacer(); Text("Coming Soon").foregroundStyle(.secondary) }
                            HStack { Text("Export Data"); Spacer(); Text("Coming Soon").foregroundStyle(.secondary) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showingManageExerciseTypes) { ManageExerciseTypesView() }
            .macPresentationFitted()
            .frame(minWidth: 380, idealWidth: 460, maxWidth: 560)
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
