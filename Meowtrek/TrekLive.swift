import ActivityKit
import Foundation

enum TrekLive {
    private static var activity: Activity<TrekActivityAttributes>?

    @MainActor
    static func update(_ rec: TrekRecorder) {
        let content = TrekActivityAttributes.ContentState(
            meters: rec.meters, elapsed: rec.elapsed,
            timerStart: rec.phase == .running ? Date().addingTimeInterval(-rec.elapsed) : nil,
            pace: rec.currentPace > 0 ? rec.currentPace : rec.avgPace)
        if let activity {
            Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, rec.phase == .running else { return }
        let snap = WidgetBridge.read() ?? .sample
        let attrs = TrekActivityAttributes(kind: rec.kind.title, symbol: rec.kind.symbol, petName: snap.petName, equipped: snap.equipped)
        activity = try? Activity.request(attributes: attrs, content: ActivityContent(state: content, staleDate: nil))
    }

    static func end() {
        guard let a = activity else { return }
        activity = nil
        Task { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
