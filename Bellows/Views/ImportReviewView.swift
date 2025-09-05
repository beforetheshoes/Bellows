import SwiftUI
import SwiftData

@MainActor
struct ImportReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State var viewModel: ImportReviewViewModel

    var body: some View {
        NavigationStack {
            List {
                #if os(macOS)
                // On macOS, show summary at the top inside the list to avoid overlay issues
                let sTop = viewModel.predictedSummary()
                Section("Summary") {
                    HStack(spacing: 16) {
                        Label("\(sTop.willUpdate) updates", systemImage: "arrow.triangle.2.circlepath.circle")
                        Label("\(sTop.willRestore) restores", systemImage: "arrow.uturn.backward.circle")
                        Label("\(sTop.willInsert) inserts", systemImage: "plus.circle")
                        Label("\(sTop.willSkip) skips", systemImage: "slash.circle")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                }
                #endif
                if let err = viewModel.lastError {
                    Section {
                        Text("Error: \(err.localizedDescription)")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                Section("Mode") {
                    Toggle("Restore mode (include previously deleted items)", isOn: $viewModel.restoreMode)
                        .onChange(of: viewModel.restoreMode) { _, _ in
                            try? viewModel.loadPlan()
                        }
                    Text(restoreCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // New Items first — most likely desired actions
                if !viewModel.plan.plannedInserts.isEmpty {
                    Section("New Items") {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(viewModel.plan.plannedInserts.enumerated()), id: \.offset) { _, ins in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(nearDupTitle(name: ins.snapshot.exerciseName, unit: ins.snapshot.unitName, amount: ins.snapshot.amount))
                                            Text(fmtDate(ins.snapshot.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        let skipping = viewModel.skipInsertKeys.contains(ins.decisionKey)
                                        Button(skipping ? "Include" : "Skip") { viewModel.toggleSkipInsert(key: ins.decisionKey) }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        presentDiff(local: nil, incoming: ins.snapshot, title: nearDupTitle(name: ins.snapshot.exerciseName, unit: ins.snapshot.unitName, amount: ins.snapshot.amount), mode: .newItem(decisionKey: ins.decisionKey, isSkipping: viewModel.skipInsertKeys.contains(ins.decisionKey)))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: sectionMaxHeight)
                    }
                }

                if !viewModel.plan.identityConflicts.isEmpty {
                    Section("Conflicts") {
                        HStack {
                            Text("Resolve all:")
                            Spacer()
                            Button("Recommend") { viewModel.chooseRecommendedForAllConflicts() }
                            Button("Keep Local for All") { viewModel.chooseKeepLocalForAll() }
                            Button("Keep Import for All") { viewModel.chooseKeepImportForAll() }
                        }
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(viewModel.plan.identityConflicts.enumerated()), id: \.offset) { _, c in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(conflictTitle(c))
                                            .font(.headline)
                                        conflictRow(label: "Local", s: c.local)
                                        conflictRow(label: "Import", s: c.incoming)
                                        HStack {
                                            Spacer()
                                            Button("Keep Local") { viewModel.chooseKeepLocal(for: c) }
                                            Button("Keep Import") { viewModel.chooseKeepImport(for: c) }
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let key = viewModel.keyForConflict(c) {
                                            presentDiff(local: c.local, incoming: c.incoming, title: conflictTitle(c), mode: .conflict(conflictKey: key))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: sectionMaxHeight)
                    }
                }

                if !viewModel.plan.tombstoneConflicts.isEmpty {
                    Section("Previously Deleted") {
                        HStack {
                            Text("Apply to all:")
                            Spacer()
                            Button("Restore All") { viewModel.allowRestoreForAll() }
                        }
                        ForEach(Array(viewModel.plan.tombstoneConflicts.enumerated()), id: \.offset) { _, c in
                            HStack {
                                Text(conflictTitle(c))
                                Spacer()
                                Button("Restore") { viewModel.allowRestore(for: c) }
                                Button("Skip") { viewModel.disallowRestore(for: c) }
                            }
                        }
                    }
                }

                if !viewModel.plan.alreadyExists.isEmpty {
                    Section("Already Exists") {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(viewModel.plan.alreadyExists.enumerated()), id: \.offset) { _, ex in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(alreadyTitle(ex.snapshot))
                                            Text(fmtDate(ex.snapshot.createdAt))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        let key = viewModel.keyForLegacy(exerciseName: ex.snapshot.exerciseName, unitName: ex.snapshot.unitName, amount: ex.snapshot.amount, enjoyment: ex.snapshot.enjoyment, intensity: ex.snapshot.intensity, createdAt: ex.snapshot.createdAt)
                                        let included = viewModel.insertLegacyKeys.contains(key)
                                        Button(included ? "Remove" : "Insert") {
                                            viewModel.toggleInsertLegacy(
                                                exerciseName: ex.snapshot.exerciseName,
                                                unitName: ex.snapshot.unitName,
                                                amount: ex.snapshot.amount,
                                                enjoyment: ex.snapshot.enjoyment,
                                                intensity: ex.snapshot.intensity,
                                                createdAt: ex.snapshot.createdAt
                                            )
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        let legacyKey = viewModel.keyForLegacy(exerciseName: ex.snapshot.exerciseName, unitName: ex.snapshot.unitName, amount: ex.snapshot.amount, enjoyment: ex.snapshot.enjoyment, intensity: ex.snapshot.intensity, createdAt: ex.snapshot.createdAt)
                                        presentDiff(local: ex.snapshot, incoming: ex.snapshot, title: alreadyTitle(ex.snapshot), mode: .existingInsert(legacyKey: legacyKey, isIncluded: viewModel.insertLegacyKeys.contains(legacyKey)))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: sectionMaxHeight)
                    }
                }

                if !viewModel.plan.nearDuplicates.isEmpty {
                    Section("Near Duplicates") {
                        HStack {
                            Text("Insert all near duplicates")
                            Spacer()
                            Button("Insert All") { viewModel.forceInsertAllNearDuplicates() }
                        }
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(viewModel.plan.nearDuplicates.enumerated()), id: \.offset) { _, nd in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(nearDupTitle(name: nd.exerciseName, unit: nd.unitName, amount: nd.amount))
                                            Text("Local: \(fmtDate(nd.localCreatedAt))  Import: \(fmtDate(nd.importCreatedAt))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        let key = viewModel.keyForLegacy(exerciseName: nd.exerciseName, unitName: nd.unitName, amount: nd.amount, enjoyment: nd.enjoyment, intensity: nd.intensity, createdAt: nd.importCreatedAt)
                                        let included = viewModel.insertLegacyKeys.contains(key)
                                        Button(included ? "Remove" : "Insert") {
                                            viewModel.toggleInsertLegacy(
                                                exerciseName: nd.exerciseName,
                                                unitName: nd.unitName,
                                                amount: nd.amount,
                                                enjoyment: nd.enjoyment,
                                                intensity: nd.intensity,
                                                createdAt: nd.importCreatedAt
                                            )
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        let localSnap = DataImportService.ImportPlan.Snapshot(
                                            id: nil,
                                            exerciseName: nd.exerciseName,
                                            unitName: nd.unitName,
                                            amount: nd.amount,
                                            enjoyment: nd.enjoyment,
                                            intensity: nd.intensity,
                                            createdAt: nd.localCreatedAt,
                                            modifiedAt: nil
                                        )
                                        let importSnap = DataImportService.ImportPlan.Snapshot(
                                            id: nil,
                                            exerciseName: nd.exerciseName,
                                            unitName: nd.unitName,
                                            amount: nd.amount,
                                            enjoyment: nd.enjoyment,
                                            intensity: nd.intensity,
                                            createdAt: nd.importCreatedAt,
                                            modifiedAt: nil
                                        )
                                        let legacyKey = viewModel.keyForLegacy(exerciseName: nd.exerciseName, unitName: nd.unitName, amount: nd.amount, enjoyment: nd.enjoyment, intensity: nd.intensity, createdAt: nd.importCreatedAt)
                                        presentDiff(local: localSnap, incoming: importSnap, title: nearDupTitle(name: nd.exerciseName, unit: nd.unitName, amount: nd.amount), mode: .nearDup(legacyKey: legacyKey, isIncluded: viewModel.insertLegacyKeys.contains(legacyKey)))
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: sectionMaxHeight)
                    }
                }
            }
            .navigationTitle("Review Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { do { try viewModel.apply(); dismiss() } catch { } }
                }
            }
            .onAppear { try? viewModel.loadPlan() }
            #if os(iOS)
            .safeAreaInset(edge: .bottom) {
                let s = viewModel.predictedSummary()
                HStack(spacing: 16) {
                    Label("\(s.willUpdate) updates", systemImage: "arrow.triangle.2.circlepath.circle")
                    Label("\(s.willRestore) restores", systemImage: "arrow.uturn.backward.circle")
                    Label("\(s.willInsert) inserts", systemImage: "plus.circle")
                    Label("\(s.willSkip) skips", systemImage: "slash.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 680, maxWidth: 900, minHeight: 460, idealHeight: 560, maxHeight: 900)
        .applyMacFitted()
        #endif
        .sheet(item: $diffItem) { item in
            VStack(spacing: 0) {
                ImportItemDiffView(local: mapSnapshot(item.local, title: "Local"), incoming: mapSnapshot(item.incoming, title: "Import"))
                Divider()
                HStack(spacing: 12) {
                    Button("Cancel") { diffItem = nil }
                    Spacer()
                    switch item.mode {
                    case .newItem(let key, let isSkipping):
                        Button(isSkipping ? "Include" : "Skip") { viewModel.toggleSkipInsert(key: key); diffItem = nil }
                            .buttonStyle(.borderedProminent)
                    case .existingInsert(_, let isIncluded):
                        Button(isIncluded ? "Remove" : "Insert") { viewModel.toggleInsertLegacy(exerciseName: mapTitle(item.incoming).0, unitName: mapTitle(item.incoming).1, amount: mapTitle(item.incoming).2, enjoyment: mapTitle(item.incoming).3, intensity: mapTitle(item.incoming).4, createdAt: mapTitle(item.incoming).5); diffItem = nil }
                            .buttonStyle(.borderedProminent)
                    case .nearDup(_, let isIncluded):
                        Button(isIncluded ? "Remove" : "Insert") { viewModel.toggleInsertLegacy(exerciseName: mapTitle(item.incoming).0, unitName: mapTitle(item.incoming).1, amount: mapTitle(item.incoming).2, enjoyment: mapTitle(item.incoming).3, intensity: mapTitle(item.incoming).4, createdAt: mapTitle(item.incoming).5); diffItem = nil }
                            .buttonStyle(.borderedProminent)
                    case .conflict(let cKey):
                        Button("Keep Local") { viewModel.chooseKeepLocal(byKey: cKey); diffItem = nil }
                        Button("Keep Import") { viewModel.chooseKeepImport(byKey: cKey); diffItem = nil }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
    }

    private func conflictTitle(_ c: DataImportService.ImportPlan.Conflict) -> String {
        if let hk = c.hkUUID { return "HK \(hk)" }
        if let lid = c.logicalID { return lid }
        return "Conflict"
    }

    private func fmtDate(_ d: Date?) -> String {
        guard let d else { return "-" }
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f.string(from: d)
    }

    private var restoreCaption: String {
        let t = viewModel.tombstoneCount
        if viewModel.restoreMode {
            return t > 0 ? "Will include \(t) previously deleted item\(t == 1 ? "" : "s")." : "No previously deleted items in this file."
        } else {
            return t > 0 ? "Will skip \(t) previously deleted item\(t == 1 ? "" : "s"). Enable Restore to include them." : "No previously deleted items to skip."
        }
    }

    private var sectionMaxHeight: CGFloat {
        #if os(iOS)
        return 260
        #else
        return 320
        #endif
    }

    @ViewBuilder
    private func conflictRow(label: String, s: DataImportService.ImportPlan.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(label).font(.caption).foregroundStyle(.secondary); Spacer(); Text(s.id ?? "").font(.caption).foregroundStyle(.tertiary).lineLimit(1) }
            Text(nearDupTitle(name: s.exerciseName, unit: s.unitName, amount: s.amount))
            Text(fmtDate(s.createdAt)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func nearDupTitle(name: String, unit: String?, amount: Double) -> String {
        let amt = String(format: amount.rounded() == amount ? "%.0f" : "%.2f", amount)
        if let unit, !unit.isEmpty { return "\(amt) \(unit) \(name)" }
        return "\(amt) \(name)"
    }

    private func alreadyTitle(_ s: DataImportService.ImportPlan.Snapshot) -> String {
        nearDupTitle(name: s.exerciseName, unit: s.unitName, amount: s.amount)
    }
    // Diff handling
    private struct DiffItem: Identifiable {
        enum Mode {
            case newItem(decisionKey: String, isSkipping: Bool)
            case existingInsert(legacyKey: String, isIncluded: Bool)
            case nearDup(legacyKey: String, isIncluded: Bool)
            case conflict(conflictKey: String)
        }
        let id = UUID()
        let local: DataImportService.ImportPlan.Snapshot?
        let incoming: DataImportService.ImportPlan.Snapshot?
        let mode: Mode
    }
    @State private var diffItem: DiffItem?

    private func presentDiff(local: DataImportService.ImportPlan.Snapshot?, incoming: DataImportService.ImportPlan.Snapshot?, title: String, mode: DiffItem.Mode) {
        diffItem = DiffItem(local: local, incoming: incoming, mode: mode)
    }

    private func mapSnapshot(_ s: DataImportService.ImportPlan.Snapshot?, title: String) -> ImportItemDiffView.Snapshot? {
        guard let s else { return nil }
        return .init(title: title,
                     exerciseName: s.exerciseName,
                     unitName: s.unitName,
                     amount: s.amount,
                     enjoyment: s.enjoyment,
                     intensity: s.intensity,
                     createdAt: s.createdAt,
                     modifiedAt: s.modifiedAt,
                     identity: s.id)
    }

    // Helper to extract fields for toggles from a snapshot
    private func mapTitle(_ s: DataImportService.ImportPlan.Snapshot?) -> (String, String?, Double, Int, Int, Date) {
        let ex = s?.exerciseName ?? ""
        let unit = s?.unitName
        let amount = s?.amount ?? 0
        let e = s?.enjoyment ?? 3
        let i = s?.intensity ?? 3
        let c = s?.createdAt ?? Date()
        return (ex, unit, amount, e, i, c)
    }
}

#if os(macOS)
private extension View {
    @ViewBuilder
    func applyMacFitted() -> some View {
        if #available(macOS 15.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
    }
}
#endif
