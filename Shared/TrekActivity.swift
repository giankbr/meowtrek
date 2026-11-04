#if os(iOS)
import ActivityKit
import Foundation

struct TrekActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var meters: Double
        var elapsed: TimeInterval
        /// When running, the moment the timer would read zero; nil while paused.
        var timerStart: Date?
        var pace: TimeInterval
    }

    var kind: String
    var symbol: String
    var petName: String
    var equipped: [String: String]
}
#endif
