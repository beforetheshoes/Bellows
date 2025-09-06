import Foundation

#if os(iOS)
import WatchConnectivity

@MainActor
final class IOSWCSessionClient: NSObject, WatchConnectivityClient {
    weak var delegate: WatchConnectivityClientDelegate?

    var isReachable: Bool { WCSession.default.isReachable }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil { session.delegate = self }
        if session.activationState != .activated {
            session.activate()
        }
    }

    func sendMessage(_ message: [String : Any], replyHandler: (([String : Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
        guard WCSession.isSupported() else { return }
        WCSession.default.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }

    func updateApplicationContext(_ context: [String : Any]) throws {
        guard WCSession.isSupported() else { return }
        try WCSession.default.updateApplicationContext(context)
    }
}

extension IOSWCSessionClient: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // no-op
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }
    nonisolated func sessionDidDeactivate(_ session: WCSession) { }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.delegate?.wcClientReachabilityDidChange(self, reachable: session.isReachable)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.delegate?.wcClient(self, didReceiveMessage: message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.delegate?.wcClient(self, didReceiveApplicationContext: applicationContext)
        }
    }
}
#endif

