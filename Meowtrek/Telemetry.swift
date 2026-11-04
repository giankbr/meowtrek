import Foundation
import MetricKit
import UIKit

/// Anonymous usage counts and MetricKit crash/hang reports sent to the Meowtrek server. No ids are attached.
final class Telemetry: NSObject, MXMetricManagerSubscriber {
    static let shared = Telemetry()

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "telemetry.enabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "telemetry.enabled") }
    }

    private var counts: [String: Int] = [:]
    private let lock = NSLock()
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func start() {
        MXMetricManager.shared.add(self)
        let key = "telemetry.lastOpen"
        let day = Calendar.current.startOfDay(for: .now)
        if (UserDefaults.standard.object(forKey: key) as? Date) != day {
            UserDefaults.standard.set(day, forKey: key)
            track("app_open")
        }
    }

    static func track(_ name: String) { shared.track(name) }

    func track(_ name: String) {
        guard Self.enabled else { return }
        lock.lock(); counts[name, default: 0] += 1; lock.unlock()
    }

    func flush() {
        lock.lock(); let batch = counts; counts = [:]; lock.unlock()
        guard Self.enabled, !batch.isEmpty else { return }
        struct Body: Encodable { let appVersion: String; let events: [Event] }
        struct Event: Encodable { let name: String; let count: Int }
        post("v1/telemetry/events", Body(appVersion: version, events: batch.prefix(50).map { Event(name: $0.key, count: min(500, $0.value)) }))
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard Self.enabled else { return }
        struct Body: Encodable { let appVersion: String; let osVersion: String; let model: String; let payload: String }
        var sys = utsname(); uname(&sys)
        let model = withUnsafeBytes(of: &sys.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        for p in payloads {
            guard let json = String(data: p.jsonRepresentation(), encoding: .utf8) else { continue }
            post("v1/telemetry/diagnostics", Body(appVersion: version, osVersion: UIDevice.current.systemVersion,
                                                 model: model, payload: String(json.prefix(240_000))))
        }
    }

    private func post(_ path: String, _ body: some Encodable) {
        guard let base = AppConfig.apiBase, let data = try? JSONEncoder().encode(body) else { return }
        var req = URLRequest(url: base.appending(path: path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        URLSession.shared.dataTask(with: req).resume()
    }
}
