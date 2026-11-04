import HealthKit
import Observation
import SwiftUI

@Observable
final class WatchWorkout: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    enum Kind: String, CaseIterable, Identifiable {
        case walk, run, hike
        var id: String { rawValue }
        var symbol: String { self == .walk ? "figure.walk" : self == .run ? "figure.run" : "figure.hiking" }
        var activity: HKWorkoutActivityType { self == .walk ? .walking : self == .run ? .running : .hiking }
    }

    var active = false
    var paused = false
    var kind: Kind = .walk
    var meters = 0.0
    var heartRate = 0.0
    var kcal = 0.0

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?

    var elapsed: TimeInterval { builder?.elapsedTime ?? 0 }

    @MainActor
    func start(_ kind: Kind) async {
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned)]
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned)]
        try? await store.requestAuthorization(toShare: share, read: read)
        let config = HKWorkoutConfiguration()
        config.activityType = kind.activity
        config.locationType = .outdoor
        guard let s = try? HKWorkoutSession(healthStore: store, configuration: config) else { return }
        let b = s.associatedWorkoutBuilder()
        b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
        s.delegate = self
        b.delegate = self
        session = s
        builder = b
        self.kind = kind
        meters = 0; heartRate = 0; kcal = 0
        let now = Date()
        s.startActivity(with: now)
        try? await b.beginCollection(at: now)
        active = true
        paused = false
    }

    func togglePause() {
        guard let session else { return }
        paused ? session.resume() : session.pause()
        paused.toggle()
    }

    @MainActor
    func end() async {
        guard let session, let builder else { return }
        session.end()
        try? await builder.endCollection(at: .now)
        _ = try? await builder.finishWorkout()
        active = false
        self.session = nil
        self.builder = nil
    }

    func workoutSession(_ s: HKWorkoutSession, didChangeTo to: HKWorkoutSessionState, from: HKWorkoutSessionState, date: Date) {}
    func workoutSession(_ s: HKWorkoutSession, didFailWithError error: Error) {}
    func workoutBuilderDidCollectEvent(_ b: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ b: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        let dist = b.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter())
        let hr = b.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        let e = b.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        DispatchQueue.main.async {
            if let dist { self.meters = dist }
            if let hr { self.heartRate = hr }
            if let e { self.kcal = e }
        }
    }
}

struct WatchWorkoutView: View {
    @Environment(WatchWorkout.self) private var w

    var body: some View {
        if w.active {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                VStack(alignment: .leading, spacing: 4) {
                    Label(w.kind.rawValue.capitalized, systemImage: w.kind.symbol).foregroundStyle(Color.grass)
                    Text(Duration.seconds(w.elapsed).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(String(format: "%.2f km", w.meters / 1000)).font(.system(size: 22, weight: .semibold, design: .rounded))
                    HStack {
                        Label("\(Int(w.heartRate))", systemImage: "heart.fill").foregroundStyle(Color.tomato)
                        Label("\(Int(w.kcal))", systemImage: "flame.fill").foregroundStyle(Color.pumpkin)
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    HStack {
                        Button(w.paused ? "Resume" : "Pause") { w.togglePause() }
                        Button("End") { Task { await w.end() } }.tint(.tomato)
                    }
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    Text("Start a trek").font(.system(size: 17, weight: .bold, design: .rounded))
                    ForEach(WatchWorkout.Kind.allCases) { k in
                        Button { Task { await w.start(k) } } label: {
                            Label(k.rawValue.capitalized, systemImage: k.symbol).frame(maxWidth: .infinity)
                        }
                        .tint(.grass)
                    }
                }
            }
        }
    }
}
