import CoreMotion
import HealthKit
import Observation

@Observable
final class StepStore {
    enum Source { case demo, health }

    var daily: [Date: Int] = [:]
    var flights: [Date: Int] = [:]
    var distance: [Date: Double] = [:]
    var energy: [Date: Double] = [:]
    var hourly: [Int] = Array(repeating: 0, count: 24)
    var source: Source = .demo
    var live = false

    @ObservationIgnored private let health = HKHealthStore()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private let cal = Calendar.current
    @ObservationIgnored private var demoMode = ProcessInfo.processInfo.arguments.contains("-demo")

    init() { loadDemo() }

    var today: Int { steps(on: .now) }
    func steps(on day: Date) -> Int { daily[cal.startOfDay(for: day)] ?? 0 }

    func meters(on day: Date) -> Double {
        let d = cal.startOfDay(for: day)
        return source == .health ? distance[d] ?? 0 : Double(steps(on: d)) * 0.762
    }

    func kcal(on day: Date) -> Double {
        let d = cal.startOfDay(for: day)
        return source == .health ? energy[d] ?? 0 : Double(steps(on: d)) * 0.045
    }

    @MainActor
    func load() async {
        guard HKHealthStore.isHealthDataAvailable(), !demoMode else { return }
        let types: [HKQuantityTypeIdentifier] = [.stepCount, .flightsClimbed, .distanceWalkingRunning, .activeEnergyBurned]
        do {
            try await health.requestAuthorization(toShare: [], read: Set(types.map { HKQuantityType($0) }))
            let start = cal.date(byAdding: .day, value: -400, to: cal.startOfDay(for: .now))!
            let steps = try await sums(.stepCount, .count(), from: start, every: DateComponents(day: 1))
            // Read permission is opaque in HealthKit: empty results mean denied or no data, so keep demo.
            guard steps.values.contains(where: { $0 > 0 }) else { return }
            daily = steps.mapValues { Int($0) }
            flights = ((try? await sums(.flightsClimbed, .count(), from: start, every: DateComponents(day: 1))) ?? [:]).mapValues { Int($0) }
            distance = (try? await sums(.distanceWalkingRunning, .meter(), from: start, every: DateComponents(day: 1))) ?? [:]
            energy = (try? await sums(.activeEnergyBurned, .kilocalorie(), from: start, every: DateComponents(day: 1))) ?? [:]
            let dayStart = cal.startOfDay(for: .now)
            let hours = (try? await sums(.stepCount, .count(), from: dayStart, every: DateComponents(hour: 1))) ?? [:]
            hourly = (0..<24).map { h in Int(hours[cal.date(byAdding: .hour, value: h, to: dayStart)!] ?? 0) }
            source = .health
            startLive()
        } catch {}
    }

    private func startLive() {
        guard !live, CMPedometer.isStepCountingAvailable() else { return }
        live = true
        let start = cal.startOfDay(for: .now)
        pedometer.startUpdates(from: start) { [weak self] data, _ in
            guard let self, let n = data?.numberOfSteps.intValue else { return }
            DispatchQueue.main.async {
                guard self.cal.isDate(start, inSameDayAs: .now) else { return }
                if n > self.steps(on: start) {
                    let h = self.cal.component(.hour, from: .now)
                    self.hourly[h] += n - self.steps(on: start)
                    self.daily[start] = n
                }
            }
        }
    }

    private func sums(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, from start: Date, every interval: DateComponents) async throws -> [Date: Double] {
        let type = HKQuantityType(id)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: nil)),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: interval
        )
        let result = try await query.result(for: health)
        var out: [Date: Double] = [:]
        result.enumerateStatistics(from: start, to: .now) { stat, _ in
            out[stat.startDate] = stat.sumQuantity()?.doubleValue(for: unit) ?? 0
        }
        return out
    }

    private func loadDemo() {
        let today = cal.startOfDay(for: .now)
        var rng = SeededRNG(state: 42)
        for i in 0..<400 {
            let r = Double.random(in: 0..<1, using: &rng)
            daily[cal.date(byAdding: .day, value: -i, to: today)!] = i == 0 ? 7240 : Int(1500 + r * 11000)
        }
        let now = cal.component(.hour, from: .now)
        let weights = (0..<24).map { h -> Double in
            guard h <= now else { return 0 }
            return [8, 12, 13, 18].contains(h) ? 3 : (7...21).contains(h) ? 1 : 0.05
        }
        let total = max(weights.reduce(0, +), 0.01)
        hourly = weights.map { Int($0 / total * 7240) }
    }
}
