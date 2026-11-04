#if os(iOS)
import AppIntents
import WidgetKit

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a glass of water"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.update { s in
            s.water = s.waterToday + 1
            if let i = s.quests?.firstIndex(where: { $0.id.hasPrefix("hydrate") }) { s.quests?[i].value += 1 }
        }
        WidgetBridge.enqueue("water")
        return .result()
    }
}

struct ClaimCoinsIntent: AppIntent {
    static var title: LocalizedStringResource = "Claim walking coins"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.update { s in
            s.coins = (s.coins ?? 0) + s.claimableNow
            s.claimable = 0
        }
        WidgetBridge.enqueue("claim")
        return .result()
    }
}

struct FeedCatIntent: AppIntent {
    static var title: LocalizedStringResource = "Feed your cat"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        guard (WidgetBridge.read()?.treats ?? 0) > 0 else { return .result() }
        WidgetBridge.update { s in
            s.fullness = min(100, (s.fullness ?? 0) + 30)
            s.treats = max(0, (s.treats ?? 0) - 1)
            s.pettedAt = .now
        }
        WidgetBridge.enqueue("feed")
        return .result()
    }
}

struct PetCatIntent: AppIntent {
    static var title: LocalizedStringResource = "Pet your cat"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.update { $0.pettedAt = .now }
        return .result()
    }
}

struct ClaimQuestIntent: AppIntent {
    static var title: LocalizedStringResource = "Claim quest reward"
    static var isDiscoverable = false

    @Parameter(title: "Quest") var questID: String

    init() {}
    init(questID: String) { self.questID = questID }

    func perform() async throws -> some IntentResult {
        WidgetBridge.update { s in
            guard let i = s.quests?.firstIndex(where: { $0.id == questID }), let q = s.quests?[i], q.done, !q.claimed else { return }
            s.quests?[i].claimed = true
            s.coins = (s.coins ?? 0) + q.reward
        }
        WidgetBridge.enqueue("quest", questID)
        return .result()
    }
}
#endif
