//
//  ContentView.swift
//  BellowsWatch Watch App
//
//  Created by Ryan Williams on 9/5/25.
//

import SwiftUI
import WatchConnectivity
import Observation
#if canImport(ClockKit)
import ClockKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class WatchStatusVM: NSObject, WCSessionDelegate {
    var isReachable: Bool = false
    var lastSyncDate: Date? = nil
    var syncEnabled: Bool = true
    var streak: Int = 0
    var emberIntensity: Double = 0
    var isActivated: Bool = false
    private var didRequestState = false

    // Quick Add selections
    var selectedExercise: String = "Walk"
    var selectedUnit: String = "Minutes"
    var amount: Double = 15
    // Full‑screen overlay + loading state
    var isSaving: Bool = false
    var showResultOverlay: Bool = false
    var resultOK: Bool = false

    override init() {
        super.init()
        ensureActivated()
    }

    func ensureActivated() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        if s.delegate == nil { s.delegate = self }
        if s.activationState != .activated { s.activate() }
        isReachable = s.isReachable
        isActivated = (s.activationState == .activated)
        if isActivated && !didRequestState { requestStateIfPossible() }
    }

    func sendAddEntry() {
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        isSaving = true
        let payload: [String: Any] = [
            "exerciseName": selectedExercise,
            "unitName": selectedUnit,
            "amount": amount,
            "enjoyment": 3,
            "intensity": 3
        ]
        let msg: [String: Any] = ["v": 1, "type": "add_entry", "payload": payload]
        WCSession.default.sendMessage(msg, replyHandler: { reply in
            Task { @MainActor in
                if let s = reply["streak"] as? Int { self.streak = s }
                if let e = reply["emberIntensity"] as? Double { self.emberIntensity = e }
                self.updateComplicationSharedStore(streak: self.streak, intensity: self.emberIntensity)
                WKInterfaceDevice.current().play(.success)
                // Full‑screen overlay
                self.resultOK = true
                self.isSaving = false
                withAnimation(.easeInOut(duration: 0.2)) { self.showResultOverlay = true }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeInOut(duration: 0.2)) { self.showResultOverlay = false }
            }
        }, errorHandler: { _ in
            Task { @MainActor in
                WKInterfaceDevice.current().play(.failure)
                self.resultOK = false
                self.isSaving = false
                withAnimation(.easeInOut(duration: 0.2)) { self.showResultOverlay = true }
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeInOut(duration: 0.2)) { self.showResultOverlay = false }
            }
        })
    }

    // MARK: - Amount options per unit
    func stepSize(for unit: String) -> Double {
        switch unit.lowercased() {
        case "reps": return 5
        case "seconds": return 5
        case "minutes": return 1
        case "miles": return 0.25
        default: return 1
        }
    }

    func allowedAmounts(for unit: String) -> [Double] {
        switch unit.lowercased() {
        case "reps": return stride(from: 5.0, through: 200.0, by: 5.0).map { $0 }
        case "seconds": return stride(from: 5.0, through: 180.0, by: 5.0).map { $0 }
        case "minutes": return stride(from: 1.0, through: 180.0, by: 1.0).map { $0 }
        case "miles": return stride(from: 0.25, through: 100.0, by: 0.25).map { $0 }
        default: return stride(from: 1.0, through: 100.0, by: 1.0).map { $0 }
        }
    }

    func displayAmount(_ value: Double) -> String {
        switch selectedUnit.lowercased() {
        case "reps": return String(Int(value))
        case "seconds": return String(Int(value))
        case "minutes": return String(Int(value))
        case "miles": return String(format: "%.2f", value)
        default: return String(format: "%.0f", value)
        }
    }

    func clampAndSnapAmountForCurrentUnit() {
        let opts = allowedAmounts(for: selectedUnit)
        guard !opts.isEmpty else { return }
        // Snap to nearest available option
        if let nearest = opts.min(by: { abs($0 - amount) < abs($1 - amount) }) {
            amount = nearest
        } else {
            amount = opts.first!
        }
    }

    private func updateComplicationSharedStore(streak: Int, intensity: Double) {
        let groupID = "group.com.ryanleewilliams.Bellows"
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil {
            let defaults = UserDefaults(suiteName: groupID)
            let lastStreak = defaults?.integer(forKey: "complication_streak") ?? Int.min
            defaults?.set(streak, forKey: "complication_streak")
            defaults?.set(intensity, forKey: "complication_intensity")
            #if canImport(WidgetKit)
            // Targeted reload for our complication kind, only when streak changes
            if streak != lastStreak {
                WidgetCenter.shared.reloadTimelines(ofKind: "BellowsComplication")
            }
            #endif
            #if canImport(ClockKit)
            // Also refresh any legacy ClockKit complications if present (only when streak changes)
            if streak != lastStreak {
                let server = CLKComplicationServer.sharedInstance()
                server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
            }
            #endif
        }
    }

    // MARK: WCSessionDelegate
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isActivated = (activationState == .activated)
            self.isReachable = session.isReachable
            if self.isActivated && !self.didRequestState {
                self.requestStateIfPossible()
            }
        }
    }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if self.isReachable && self.isActivated && !self.didRequestState {
                self.requestStateIfPossible()
            }
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            if let v = applicationContext["v"] as? Int, v == 1 {
                if let iso = applicationContext["lastSyncAt"] as? String, let d = ISO8601DateFormatter().date(from: iso) {
                    self.lastSyncDate = d
                }
                if let enabled = applicationContext["syncEnabled"] as? Bool { self.syncEnabled = enabled }
                if let s = applicationContext["streak"] as? Int { self.streak = s }
                if let e = applicationContext["emberIntensity"] as? Double { self.emberIntensity = e }
                self.updateComplicationSharedStore(streak: self.streak, intensity: self.emberIntensity)
            }
        }
    }

    // Receive background userInfo updates (reliable even if app isn't in foreground)  
    // This method handles BOTH regular transfers and complication transfers
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            if let v = userInfo["v"] as? Int, v == 1 {
                if let iso = userInfo["lastSyncAt"] as? String, let d = ISO8601DateFormatter().date(from: iso) { self.lastSyncDate = d }
                if let enabled = userInfo["syncEnabled"] as? Bool { self.syncEnabled = enabled }
                if let s = userInfo["streak"] as? Int { self.streak = s }
                if let e = userInfo["emberIntensity"] as? Double { self.emberIntensity = e }
                self.updateComplicationSharedStore(streak: self.streak, intensity: self.emberIntensity)
            }
        }
    }

    @MainActor
    private func requestStateIfPossible() {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["v": 1, "type": "request_state"], replyHandler: { reply in
            Task { @MainActor in
                if let v = reply["v"] as? Int, v == 1 {
                    if let iso = reply["lastSyncAt"] as? String, let d = ISO8601DateFormatter().date(from: iso) { self.lastSyncDate = d }
                    if let enabled = reply["syncEnabled"] as? Bool { self.syncEnabled = enabled }
                    if let s = reply["streak"] as? Int { self.streak = s }
                    if let e = reply["emberIntensity"] as? Double { self.emberIntensity = e }
                    self.updateComplicationSharedStore(streak: self.streak, intensity: self.emberIntensity)
                }
            }
        }, errorHandler: nil)
        didRequestState = true
    }
}

struct ContentView: View {
    @State private var vm = WatchStatusVM()

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                Picker("Exercise", selection: $vm.selectedExercise) {
                    ForEach(["Walk","Run","Cycling","Yoga","Plank","Pushups","Squats","Other"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.navigationLink)

                Picker("Unit", selection: $vm.selectedUnit) {
                    ForEach(["Reps","Seconds","Minutes","Miles"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.navigationLink)

                HStack {
                    Stepper(vm.displayAmount(vm.amount), value: $vm.amount, in: {
                        switch vm.selectedUnit.lowercased() {
                        case "reps": return 5.0...200.0
                        case "seconds": return 5.0...180.0
                        case "minutes": return 1.0...180.0
                        case "miles": return 0.25...20.0
                        default: return 1.0...100.0
                        }
                    }(), step: vm.stepSize(for: vm.selectedUnit))
                    .labelsHidden()
                }

                Button("Log Exercise") { vm.sendAddEntry() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!(vm.isReachable && vm.isActivated) || vm.isSaving)
                }
            }
            // Loading overlay
            if vm.isSaving {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Saving…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity)
            }
            // Full‑screen result overlay
            if vm.showResultOverlay {
                ZStack {
                    (vm.resultOK ? Color.green : Color.red).opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 8) {
                        Image(systemName: vm.resultOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                        Text(vm.resultOK ? "Saved" : "Not Saved")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear { vm.ensureActivated(); vm.clampAndSnapAmountForCurrentUnit() }
        .onChange(of: vm.selectedUnit) { _, _ in vm.clampAndSnapAmountForCurrentUnit() }
    }
}

#Preview {
    ContentView()
}
