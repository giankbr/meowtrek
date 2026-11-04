import Foundation

struct WidgetQuest: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: String
    var value: Int
    let target: Int
    let reward: Int
    var claimed: Bool

    var done: Bool { value >= target }
}

struct WidgetSnapshot: Codable {
    var petName: String
    var steps: Int
    var goal: Int
    var streak: Int
    var mood: String
    var equipped: [String: String]
    var updated: Date
    var coins: Int?
    var claimable: Int?
    var water: Int?
    var waterGoal: Int?
    var fullness: Int?
    var treats: Int?
    var quests: [WidgetQuest]?
    var pettedAt: Date?

    private var isToday: Bool { Calendar.current.isDateInToday(updated) }
    var stepsToday: Int { isToday ? steps : 0 }
    var waterToday: Int { isToday ? water ?? 0 : 0 }
    var claimableNow: Int { isToday ? claimable ?? 0 : 0 }
    var questsToday: [WidgetQuest] { isToday ? quests ?? [] : [] }
    var progress: Double { min(1, Double(stepsToday) / Double(max(1, goal))) }
    var recentlyPetted: Bool { pettedAt.map { Date.now.timeIntervalSince($0) < 120 } ?? false }
    var outfit: [Slot: Item] {
        Dictionary(uniqueKeysWithValues: equipped.compactMap { k, v in
            guard let s = Slot(rawValue: k), let it = Catalog.item(v) else { return nil }
            return (s, it)
        })
    }

    static let sample = WidgetSnapshot(
        petName: "Miso", steps: 7240, goal: 8000, streak: 3, mood: "Restless",
        equipped: ["fur": "fur_ginger", "hat": "witch_hat", "body": "witch_cloak"], updated: .now,
        coins: 1645, claimable: 72, water: 3, waterGoal: 8, fullness: 64, treats: 2,
        quests: [
            WidgetQuest(id: "early", title: "Early paws", icon: "sunrise.fill", tint: "FFC93C", value: 1000, target: 1000, reward: 30, claimed: false),
            WidgetQuest(id: "hydrate", title: "Hydrate", icon: "drop.fill", tint: "4F93B8", value: 3, target: 6, reward: 20, claimed: false),
            WidgetQuest(id: "goal", title: "Goal getter", icon: "flag.checkered", tint: "FF6B5B", value: 7240, target: 8000, reward: 50, claimed: false),
        ])
}

/// A tap in the widget, queued for the app to apply properly (coins, Health, quests) next time it runs.
struct WidgetAction: Codable {
    let kind: String
    let arg: String?
    let day: String
}

enum WidgetBridge {
    static let group = "group.id.gian.meowtrek"
    private static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static func write(_ s: WidgetSnapshot) {
        defaults.set(try? JSONEncoder().encode(s), forKey: "widget")
    }

    static func read() -> WidgetSnapshot? {
        defaults.data(forKey: "widget").flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
    }

    /// Optimistic edit so the widget shows the result of a tap immediately.
    static func update(_ change: (inout WidgetSnapshot) -> Void) {
        var s = read() ?? .sample
        change(&s)
        write(s)
    }

    static func dayKey(_ d: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func enqueue(_ kind: String, _ arg: String? = nil) {
        var list = pending()
        list.append(WidgetAction(kind: kind, arg: arg, day: dayKey()))
        defaults.set(try? JSONEncoder().encode(Array(list.suffix(100))), forKey: "widget.pending")
    }

    static func pending() -> [WidgetAction] {
        defaults.data(forKey: "widget.pending").flatMap { try? JSONDecoder().decode([WidgetAction].self, from: $0) } ?? []
    }

    static func drain() -> [WidgetAction] {
        let list = pending()
        defaults.removeObject(forKey: "widget.pending")
        return list
    }
}
