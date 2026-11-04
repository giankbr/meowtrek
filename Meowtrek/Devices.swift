import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

enum Keychain {
    static func set(_ value: String, for key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecAttrService as String: "id.gian.meowtrek"]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecAttrService as String: "id.gian.meowtrek", kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecAttrService as String: "id.gian.meowtrek"]
        SecItemDelete(q as CFDictionary)
    }
}

enum LinkError: LocalizedError {
    case notConfigured(String), cancelled, failed(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured(let what): "\(what) isn't set up yet."
        case .cancelled: "Cancelled."
        case .failed(let m): m
        }
    }
}

@MainActor
private final class WebAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuth()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }

    func start(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "meowtrek") { url, error in
                if let url { cont.resume(returning: url) } else {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    cont.resume(throwing: cancelled ? LinkError.cancelled : LinkError.failed(error?.localizedDescription ?? "Login failed"))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }
}

private let dayFormat: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

// MARK: - Fitbit (Web API, OAuth 2.0 + PKCE, "Client" app type)

enum Fitbit {
    private static let redirect = "meowtrek://fitbit"
    static var linked: Bool { Keychain.get("fitbit.refresh") != nil }

    @MainActor
    static func connect() async throws {
        let client = AppConfig.fitbitClientID
        guard !client.isEmpty else { throw LinkError.notConfigured("Fitbit") }
        let verifier = (0..<64).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".randomElement()! }
            .map(String.init).joined()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        var c = URLComponents(string: "https://www.fitbit.com/oauth2/authorize")!
        c.queryItems = [
            .init(name: "response_type", value: "code"), .init(name: "client_id", value: client),
            .init(name: "scope", value: "activity"), .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "redirect_uri", value: redirect),
        ]
        let callback = try await WebAuth.shared.start(c.url!)
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value
        else { throw LinkError.failed("Fitbit didn't return a login code") }
        try await token(["grant_type": "authorization_code", "code": code, "code_verifier": verifier, "redirect_uri": redirect])
    }

    static func disconnect() {
        Keychain.delete("fitbit.access")
        Keychain.delete("fitbit.refresh")
    }

    private static func token(_ form: [String: String]) async throws {
        var req = URLRequest(url: URL(string: "https://api.fitbit.com/oauth2/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var all = form
        all["client_id"] = AppConfig.fitbitClientID
        req.httpBody = all.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&").data(using: .utf8)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String, let refresh = json["refresh_token"] as? String
        else { throw LinkError.failed("Fitbit login failed") }
        Keychain.set(access, for: "fitbit.access")
        Keychain.set(refresh, for: "fitbit.refresh")
    }

    /// Last 3 months of daily steps.
    static func steps(retry: Bool = true) async throws -> [Date: Int] {
        guard let access = Keychain.get("fitbit.access") else { throw LinkError.notConfigured("Fitbit") }
        var req = URLRequest(url: URL(string: "https://api.fitbit.com/1/user/-/activities/steps/date/today/3m.json")!)
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if (resp as? HTTPURLResponse)?.statusCode == 401, retry, let refresh = Keychain.get("fitbit.refresh") {
            try await token(["grant_type": "refresh_token", "refresh_token": refresh])
            return try await steps(retry: false)
        }
        struct Row: Decodable { let dateTime: String; let value: String }
        struct Body: Decodable {
            let rows: [Row]
            enum CodingKeys: String, CodingKey { case rows = "activities-steps" }
        }
        let body = try JSONDecoder().decode(Body.self, from: data)
        var out: [Date: Int] = [:]
        for r in body.rows { if let d = dayFormat.date(from: r.dateTime) { out[d] = Int(r.value) ?? 0 } }
        return out
    }
}

// MARK: - Garmin (through the Meowtrek server, which receives Garmin Health API pushes)

enum Garmin {
    static var linked: Bool { UserDefaults.standard.bool(forKey: "garmin.linked") }

    @MainActor
    static func connect(device: String) async throws {
        guard let base = AppConfig.apiBase else { throw LinkError.notConfigured("Garmin sync") }
        var c = URLComponents(url: base.appending(path: "v1/garmin/connect"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "device", value: device)]
        let callback = try await WebAuth.shared.start(c.url!)
        let status = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "status" }?.value
        guard status == "linked" else { throw LinkError.failed("Garmin wasn't linked") }
        UserDefaults.standard.set(true, forKey: "garmin.linked")
    }

    static func disconnect() { UserDefaults.standard.set(false, forKey: "garmin.linked") }

    static func steps(device: String) async throws -> [Date: Int] {
        guard let base = AppConfig.apiBase else { throw LinkError.notConfigured("Garmin sync") }
        var c = URLComponents(url: base.appending(path: "v1/garmin/steps"), resolvingAgainstBaseURL: false)!
        c.queryItems = [.init(name: "days", value: "30")]
        var req = URLRequest(url: c.url!)
        req.setValue(device, forHTTPHeaderField: "X-Meowtrek-Device")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw LinkError.failed("Garmin sync failed") }
        struct Day: Decodable { let date: String; let steps: Int }
        struct Body: Decodable { let days: [Day] }
        var out: [Date: Int] = [:]
        for d in try JSONDecoder().decode(Body.self, from: data).days {
            if let date = dayFormat.date(from: d.date) { out[date] = d.steps }
        }
        return out
    }
}

enum Devices {
    @MainActor
    static func refreshAll(_ state: AppState) async {
        if Fitbit.linked, let s = try? await Fitbit.steps() { state.steps.setExternal("fitbit", s) }
        if Garmin.linked, let s = try? await Garmin.steps(device: state.profileID) { state.steps.setExternal("garmin", s) }
    }
}

struct DevicesSection: View {
    @Environment(AppState.self) private var state
    @State private var busy: String?
    @State private var fitbit = Fitbit.linked
    @State private var garmin = Garmin.linked

    var body: some View {
        row("heart.fill", .tomato, "Apple Health", state.steps.source == .health ? "Connected" : "Not connected", connected: state.steps.source == .health) {
            Task { await state.steps.load(); state.refresh() }
        }
        row("applewatch", .ink, "Apple Watch", "Syncs through Apple Health · open Meowtrek on your watch", connected: state.steps.source == .health, action: nil)
        row("figure.walk.motion", .sky, "Fitbit", fitbit ? "Connected" : "Sign in to sync steps", connected: fitbit) {
            if fitbit {
                Fitbit.disconnect(); state.steps.removeExternal("fitbit"); fitbit = false
            } else {
                link("fitbit") {
                    try await Fitbit.connect()
                    state.steps.setExternal("fitbit", try await Fitbit.steps())
                    fitbit = true
                }
            }
        }
        row("location.north.circle.fill", .grassDark, "Garmin", garmin ? "Connected" : "Sign in to sync steps", connected: garmin) {
            if garmin {
                Garmin.disconnect(); state.steps.removeExternal("garmin"); garmin = false
            } else {
                link("garmin") {
                    try await Garmin.connect(device: state.profileID)
                    state.steps.setExternal("garmin", try await Garmin.steps(device: state.profileID))
                    garmin = true
                }
            }
        }
        Text("Mi Band, Zepp, Huawei, Oura, Withings and others: turn on Apple Health sync in their app and Meowtrek reads it automatically.")
            .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
    }

    private func link(_ name: String, _ work: @escaping () async throws -> Void) {
        busy = name
        Task {
            do {
                try await work()
                state.refresh()
                state.show("\(name.capitalized) connected", art: "coin")
            } catch LinkError.cancelled {
            } catch {
                state.show(error.localizedDescription)
            }
            busy = nil
        }
    }

    private func row(_ icon: String, _ tint: Color, _ title: String, _ detail: String, connected: Bool, action: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            GameIcon(symbol: icon, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.game(15, .bold))
                Text(detail).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            if busy == title.lowercased() {
                ProgressView()
            } else if let action {
                Button(connected && title != "Apple Health" ? "Disconnect" : connected ? "Refresh" : "Connect", action: action)
                    .font(.game(13, .bold))
                    .buttonStyle(.borderless)
                    .tint(connected && title != "Apple Health" ? .tomato : .grassDark)
            } else if connected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.grass)
            }
        }
    }
}
