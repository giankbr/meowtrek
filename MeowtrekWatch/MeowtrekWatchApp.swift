import HealthKit
import Observation
import SwiftUI
import WatchConnectivity
import WidgetKit

@main
struct MeowtrekWatchApp: App {
    @State private var model = WatchModel()
    @State private var workout = WatchWorkout()

    var body: some Scene {
        WindowGroup {
            WatchHome().environment(model).environment(workout)
        }
    }
}

@Observable
final class WatchModel: NSObject, WCSessionDelegate {
    var steps = 0
    var meters = 0.0
    var petName = "Gohan"
    var goal = 8000
    var streak = 0
    var mood = "Cheerful"
    var equipped: [String: String] = ["fur": "fur_ginger"]

    @ObservationIgnored private let health = HKHealthStore()

    var progress: Double { min(1, Double(steps) / Double(max(1, goal))) }
    var outfit: [Slot: Item] {
        Dictionary(uniqueKeysWithValues: equipped.compactMap { k, v in
            guard let s = Slot(rawValue: k), let it = Catalog.item(v) else { return nil }
            return (s, it)
        })
    }

    override init() {
        super.init()
        if let saved = UserDefaults.standard.dictionary(forKey: "context") { apply(saved) }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// Shares today's numbers with the watch complications.
    func pushComplication() {
        WidgetBridge.write(WidgetSnapshot(petName: petName, steps: steps, goal: goal, streak: streak, mood: mood,
                                          equipped: equipped, updated: .now))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func apply(_ ctx: [String: Any]) {
        if let v = ctx["petName"] as? String { petName = v }
        if let v = ctx["goal"] as? Int { goal = v }
        if let v = ctx["streak"] as? Int { streak = v }
        if let v = ctx["mood"] as? String { mood = v }
        if let v = ctx["equipped"] as? [String: String] { equipped = v }
        if let v = ctx["steps"] as? Int, v > steps { steps = v }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let ctx = session.receivedApplicationContext
        DispatchQueue.main.async { self.receive(ctx) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        DispatchQueue.main.async { self.receive(ctx) }
    }

    private func receive(_ ctx: [String: Any]) {
        guard !ctx.isEmpty else { return }
        UserDefaults.standard.set(ctx, forKey: "context")
        apply(ctx)
        pushComplication()
    }

    @MainActor
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let stepType = HKQuantityType(.stepCount), distType = HKQuantityType(.distanceWalkingRunning)
        try? await health.requestAuthorization(toShare: [], read: [stepType, distType])
        let today = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: .now), end: nil)
        if let s = try? await HKStatisticsQueryDescriptor(predicate: .quantitySample(type: stepType, predicate: today),
                                                          options: .cumulativeSum).result(for: health) {
            let n = Int(s.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            if n > 0 { steps = n }
        }
        if let d = try? await HKStatisticsQueryDescriptor(predicate: .quantitySample(type: distType, predicate: today),
                                                          options: .cumulativeSum).result(for: health) {
            meters = d.sumQuantity()?.doubleValue(for: .meter()) ?? meters
        }
        pushComplication()
    }
}

struct WatchHome: View {
    @Environment(WatchModel.self) private var m

    var body: some View {
        TabView {
            VStack(spacing: 2) {
                CatView(outfit: m.outfit, size: 74, mood: CatMood(m.progress >= 1 ? "Proud" : m.mood))
                Text(m.steps.formatted())
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                ProgressView(value: m.progress).tint(.grass)
                Text(m.steps >= m.goal ? "Goal reached!" : "\((m.goal - m.steps).formatted()) to go")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 10) {
                Text(m.petName).font(.system(size: 20, weight: .bold, design: .rounded))
                Label("\(m.streak) day streak", systemImage: "flame.fill").foregroundStyle(Color.pumpkin)
                Label(String(format: "%.1f km", m.meters / 1000), systemImage: "map.fill").foregroundStyle(Color.sky)
                Label("Goal \(m.goal.formatted())", systemImage: "flag.checkered").foregroundStyle(Color.grass)
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)

            WatchWorkoutView()
        }
        .tabViewStyle(.verticalPage)
        .task { await m.refresh() }
    }
}
