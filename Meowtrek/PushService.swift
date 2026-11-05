import SwiftUI

/// Registers this install's APNs token with the server so it can receive subscription-lifecycle pushes.
enum PushService {
    private static var installID: String?
    private static var token: String?

    /// Ask the system for an APNs token and remember who we are. Safe to call every foreground.
    @MainActor static func configure(_ state: AppState) {
        installID = state.profileID
        UIApplication.shared.registerForRemoteNotifications()
        if token != nil { Task { await post() } }
    }

    static func didRegister(_ deviceToken: Data) {
        token = deviceToken.map { String(format: "%02x", $0) }.joined()
        if installID != nil { Task { await post() } }
    }

    private static func post() async {
        guard let base = AppConfig.apiBase, let id = installID, let t = token else { return }
        var req = URLRequest(url: base.appending(path: "push/register"))
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(id, forHTTPHeaderField: "X-Meowtrek-Device")
        req.httpBody = try? JSONEncoder().encode(["token": t])
        _ = try? await URLSession.shared.data(for: req)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushService.didRegister(deviceToken)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("remote notifications unavailable: \(error.localizedDescription)")
        #endif
    }
}
