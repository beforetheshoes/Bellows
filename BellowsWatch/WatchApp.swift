import SwiftUI

#if os(watchOS)
@main
struct BellowsWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

@MainActor
struct WatchRootView: View {
    @State private var vm: WatchStatusViewModel

    init() {
        // Bridge to shared VM via WatchWCSessionClient
        let client = WatchWCSessionClient()
        _vm = State(initialValue: WatchStatusViewModel(client: client))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(vm.isReachable ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(vm.isReachable ? "Connected" : "Waiting for iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let d = vm.lastSyncDate {
                Text("Last Sync: \(d.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
            } else {
                Text("Last Sync: —").font(.caption)
            }

            Text(vm.syncEnabled ? "Sync Workouts: On" : "Sync Workouts: Off")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Import Now") {
                _ = vm.manualTriggerImport()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!vm.isReachable || !vm.syncEnabled)
        }
        .padding()
    }
}
#endif

