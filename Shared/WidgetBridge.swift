import Foundation

struct WidgetSnapshot: Codable {
    var petName: String
    var steps: Int
    var goal: Int
    var streak: Int
    var mood: String
    var equipped: [String: String]
    var updated: Date

    var stepsToday: Int { Calendar.current.isDateInToday(updated) ? steps : 0 }
    var progress: Double { min(1, Double(stepsToday) / Double(max(1, goal))) }
    var outfit: [Slot: Item] {
        Dictionary(uniqueKeysWithValues: equipped.compactMap { k, v in
            guard let s = Slot(rawValue: k), let it = Catalog.item(v) else { return nil }
            return (s, it)
        })
    }

    static let sample = WidgetSnapshot(petName: "Gohan", steps: 7240, goal: 8000, streak: 3, mood: "Restless",
                                       equipped: ["fur": "fur_ginger", "hat": "witch_hat", "body": "witch_cloak"],
                                       updated: .now)
}

enum WidgetBridge {
    static let group = "group.id.gian.pawstep"
    private static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }

    static func write(_ s: WidgetSnapshot) {
        defaults.set(try? JSONEncoder().encode(s), forKey: "widget")
    }

    static func read() -> WidgetSnapshot? {
        defaults.data(forKey: "widget").flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
    }
}
