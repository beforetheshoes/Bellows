import Foundation
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(ClockKit)
import ClockKit
#endif

#if os(watchOS)
import WatchConnectivity

@MainActor
final class WatchWCSessionClient: NSObject, WatchConnectivityClient {
    weak var delegate: WatchConnectivityClientDelegate?

    var isReachable: Bool { WCSession.default.isReachable }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil { session.delegate = self }
        if session.activationState != .activated { session.activate() }
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

extension WatchWCSessionClient: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { }
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.delegate?.wcClientReachabilityDidChange(self, reachable: session.isReachable)
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.delegate?.wcClient(self, didReceiveApplicationContext: applicationContext)
        }
    }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.delegate?.wcClient(self, didReceiveMessage: message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            // Handle both regular and complication user info transfers
            if let v = userInfo["v"] as? Int, v == 1 {
                // Update shared storage directly for complication data
                if let streak = userInfo["streak"] as? Int,
                   let intensity = userInfo["emberIntensity"] as? Double {
                    self.updateComplicationSharedStore(streak: streak, intensity: intensity)
                }
            }
            // Also notify delegate if needed
            self.delegate?.wcClient(self, didReceiveComplicationUserInfo: userInfo)
        }
    }
    
    @MainActor
    private func updateComplicationSharedStore(streak: Int, intensity: Double) {
        let groupID = "group.com.ryanleewilliams.Bellows"
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil else { return }
        
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
#endif

