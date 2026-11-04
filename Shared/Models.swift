import Foundation

enum Slot: String, CaseIterable, Codable, Identifiable {
    case fur, hat, eyes, neck, body, hand, bag, shoes

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .fur: "pawprint.fill"
        case .hat: "crown.fill"
        case .eyes: "eyeglasses"
        case .neck: "bell.fill"
        case .body: "tshirt.fill"
        case .hand: "hand.raised.fill"
        case .bag: "bag.fill"
        case .shoes: "figure.walk"
        }
    }
}

enum Suit: String, Codable, Hashable { case frog, bear, cloak }

enum Currency: String, Codable {
    case coin, gem
    var icon: String { self == .coin ? "🪙" : "💎" }
}

struct Item: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let slot: Slot
    let emoji: String
    let price: Int
    let currency: Currency
    let color: String?
    let suit: Suit?
    let event: String?

    var hex: UInt32? { color.flatMap { UInt32($0, radix: 16) } }
    var forSale: Bool { event == nil }
}

struct Consumable: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let price: Int
    let currency: Currency
    let food: Int
}

struct Milestone: Codable, Identifiable, Hashable {
    let tokens: Int
    let coins: Int
    let gems: Int
    let item: String?
    var id: Int { tokens }
}

struct GameEvent: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: String
    let token: String
    let tokenArt: String
    let stepsPerToken: Int
    let start: String
    let end: String
    let decor: [String]
    let milestones: [Milestone]
}

struct QuestTemplate: Codable, Identifiable {
    enum Kind: String, Codable { case steps, before, after, activeHours, water }
    let id: String
    let title: String
    let icon: String
    let tint: String
    let kind: Kind
    let reward: Int
    let fraction: Double
    let hour: Int
    let steps: Int
    let count: Int
}

struct Landmark: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: String
    let steps: Int
    let coins: Int
    let gems: Int
}

struct Achievement: Codable, Identifiable {
    enum Kind: String, Codable { case bestDay, streak, lifetime, goalDays, items, level, longestRun, treks, trekKm }
    let id: String
    let title: String
    let icon: String
    let tint: String
    let detail: String
    let kind: Kind
    let value: Int
    let coins: Int
    let gems: Int
}

struct Look: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var equipped: [String: String]
}

struct Friend: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var fur: String
    var hat: String?
    var week: Int
    var today: Int
    var streak: Int
    var updated: Date
}

struct GameContent: Codable {
    let items: [Item]
    let consumables: [Consumable]
    let events: [GameEvent]
    let quests: [QuestTemplate]
    let landmarks: [Landmark]
    let achievements: [Achievement]

    static let shared: GameContent = {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { fatalError("content.json missing from bundle") }
        do { return try JSONDecoder().decode(GameContent.self, from: data) } catch { fatalError("content.json: \(error)") }
    }()
}

enum Catalog {
    static var items: [Item] { GameContent.shared.items }
    private static let byID = Dictionary(uniqueKeysWithValues: GameContent.shared.items.map { ($0.id, $0) })
    static func item(_ id: String) -> Item? { byID[id] }
    static func items(for slot: Slot) -> [Item] { items.filter { $0.slot == slot } }
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
