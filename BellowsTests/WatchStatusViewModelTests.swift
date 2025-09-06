import Testing
import Foundation
@testable import Bellows

final class FakeWCClientForVM: WatchConnectivityClient {
    weak var delegate: WatchConnectivityClientDelegate?
    var isReachable: Bool = false {
        didSet { delegate?.wcClientReachabilityDidChange(self, reachable: isReachable) }
    }
    var sentMessages: [[String: Any]] = []

    func activate() { /* no-op */ }

    func sendMessage(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
        sentMessages.append(message)
    }

    func updateApplicationContext(_ context: [String : Any]) throws {
        // For VM tests, just deliver as if received
        delegate?.wcClient(self, didReceiveApplicationContext: context)
    }
}

struct WatchStatusViewModelTests {
    @Test @MainActor
    func manualTriggerSendsWhenReachable() {
        let wc = FakeWCClientForVM()
        wc.isReachable = true
        let vm = WatchStatusViewModel(client: wc)
        let ok = vm.manualTriggerImport()
        #expect(ok)
        #expect(wc.sentMessages.count == 1)
        let msg = wc.sentMessages.first!
        #expect((msg[WatchConnectivitySchemaV1.typeKey] as? String) == "nudge")
        #expect((msg[WatchConnectivitySchemaV1.reasonKey] as? String) == "manual_trigger")
        #expect((msg[WatchConnectivitySchemaV1.versionKey] as? Int) == WatchConnectivitySchemaV1.version)
    }

    @Test @MainActor
    func manualTriggerFailsWhenUnreachable() {
        let wc = FakeWCClientForVM()
        wc.isReachable = false
        let vm = WatchStatusViewModel(client: wc)
        let ok = vm.manualTriggerImport()
        #expect(!ok)
        #expect(wc.sentMessages.isEmpty)
    }

    @Test @MainActor
    func applicationContextUpdatesState() {
        let wc = FakeWCClientForVM()
        let vm = WatchStatusViewModel(client: wc)
        let now = Date()
        let iso = ISO8601DateFormatter().string(from: now)
        try? wc.updateApplicationContext([
            WatchConnectivitySchemaV1.versionKey: WatchConnectivitySchemaV1.version,
            WatchConnectivitySchemaV1.appCtxLastSyncKey: iso,
            WatchConnectivitySchemaV1.appCtxSyncEnabledKey: false
        ])
        #expect(vm.syncEnabled == false)
        #expect(vm.lastSyncDate != nil)
    }
}

