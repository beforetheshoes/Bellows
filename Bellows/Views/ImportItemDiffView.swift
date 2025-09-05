import SwiftUI

struct ImportItemDiffView: View {
    struct Snapshot: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let exerciseName: String
        let unitName: String?
        let amount: Double?
        let enjoyment: Int?
        let intensity: Int?
        let createdAt: Date?
        let modifiedAt: Date?
        let identity: String?
    }

    let local: Snapshot?
    let incoming: Snapshot?
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isStacked {
                        VStack(alignment: .leading, spacing: 12) {
                            column(title: "Local", s: local)
                            Divider()
                            column(title: "Import", s: incoming)
                        }
                        .padding()
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            column(title: "Local", s: local)
                            Divider()
                            column(title: "Import", s: incoming)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Compare Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            // Toolbar intentionally omitted; parent provides Cancel/Action buttons
        }
    }

    @ViewBuilder
    private func column(title: String, s: Snapshot?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let s {
                row(label: "Exercise", value: s.exerciseName)
                if let unit = s.unitName { row(label: "Unit", value: unit) }
                if let amt = s.amount { row(label: "Amount", value: String(format: amt.rounded() == amt ? "%.0f" : "%.2f", amt)) }
                if let e = s.enjoyment { row(label: "Enjoyment", value: "\(e)") }
                if let i = s.intensity { row(label: "Intensity", value: "\(i)") }
                if let c = s.createdAt { row(label: "Created", value: dateString(c)) }
                if let m = s.modifiedAt { row(label: "Modified", value: dateString(m)) }
                if let id = s.identity, !id.isEmpty { row(label: "ID", value: id).font(.caption) }
            } else {
                Text("No matching local item").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.body)
        }
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: d)
    }

    private var isStacked: Bool {
        #if os(iOS)
        return hSizeClass == .compact
        #else
        return false
        #endif
    }
}
