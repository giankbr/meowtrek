import WatchConnectivity

/// Pushes the pet's name, goal, outfit and today's steps to the Apple Watch app.
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ ctx: [String: Any]) {
        let s = WCSession.default
        guard WCSession.isSupported(), s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
        try? s.updateApplicationContext(ctx)
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
