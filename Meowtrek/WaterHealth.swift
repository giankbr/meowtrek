import HealthKit

enum WaterHealth {
    static func log(ml: Double = 250) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let type = HKQuantityType(.dietaryWater)
        guard (try? await store.requestAuthorization(toShare: [type], read: [])) != nil else { return }
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml),
                                      start: .now, end: .now)
        try? await store.save(sample)
    }
}
