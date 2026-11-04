import CoreMotion
import Observation

/// Knows whether the user is walking or running right now, using the low-power motion coprocessor.
/// Runs only while the app is in the foreground.
@Observable
final class MotionMonitor {
    enum Activity { case still, walking, running }

    var activity: Activity = .still
    var cadence: Double = 0

    @ObservationIgnored private let activityManager = CMMotionActivityManager()
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private var running = false
    @ObservationIgnored private let forced: Activity? = {
        switch UserDefaults.standard.string(forKey: "motion") {
        case "walking": .walking
        case "running": .running
        default: nil
        }
    }()

    /// 0 still, 1 walking, 2 running, for CatView.pace.
    var pace: Double {
        switch activity {
        case .still: 0
        case .walking: cadence > 2.4 ? 1.5 : 1
        case .running: 2
        }
    }

    func start() {
        if let forced { activity = forced; cadence = forced == .running ? 2.8 : 1.8; return }
        guard !running else { return }
        running = true
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] a in
                guard let self, let a else { return }
                self.activity = a.running ? .running : a.walking ? .walking : .still
            }
        }
        if CMPedometer.isCadenceAvailable() {
            pedometer.startUpdates(from: .now) { [weak self] data, _ in
                let c = data?.currentCadence?.doubleValue ?? 0
                DispatchQueue.main.async { self?.cadence = c }
            }
        }
    }

    func stop() {
        guard running else { return }
        running = false
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
        activity = .still
        cadence = 0
    }
}
