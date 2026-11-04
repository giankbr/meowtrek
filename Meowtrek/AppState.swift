import SwiftUI
import Observation
import WidgetKit

struct DailyQuest: Identifiable {
    let t: QuestTemplate
    let target: Int
    var id: String { t.id }
    var unit: String { t.kind == .activeHours ? "active hours" : t.kind == .water ? "glasses" : "steps" }
    var detail: String {
        switch t.kind {
        case .steps: loc("Walk \(target.formatted()) steps")
        case .before: loc("\(target.formatted()) steps before \(t.hour):00")
        case .after: loc("\(target.formatted()) steps after \(t.hour):00")
        case .activeHours: loc("\(target) hours with \(t.steps)+ steps")
        case .water: loc("Drink \(target) glasses of water")
        }
    }
}

struct Toast: Equatable {
    let id = UUID()
    let text: String
    let art: String?
}

struct FX: Equatable {
    enum Kind { case coins, gems, confetti }
    var tick = 0
    var kind = Kind.coins
}

struct ActiveEvent {
    let event: GameEvent
    let start: Date
    let end: Date
}

@Observable
final class AppState {
    @ObservationIgnored let steps = StepStore()
    @ObservationIgnored let store = Store()
    @ObservationIgnored let treks = TrekStore()
    @ObservationIgnored let meals = MealStore()
    @ObservationIgnored let content = GameContent.shared
    @ObservationIgnored private let cal = Calendar.current
    static let demo = ProcessInfo.processInfo.arguments.contains("-demo")

    var coins = 0
    var gems = 0
    var petName = ""
    var goal = 8000
    var owned: Set<String> = []
    var equipped: [Slot: String] = [:]
    var claimedSteps = 0
    var claimedDay = ""
    var claimed: Set<String> = []
    var claimedForever: Set<String> = []
    var firstDay = Date()
    var inventory: [String: Int] = [:]
    var storedFullness: Double = 70
    var fullnessAt = Date()
    var looks: [Look] = []
    var friends: [Friend] = []
    var profileID = ""
    var rewardedLevel = 0
    var streakFreezes = 0
    var frozenDays: Set<String> = []
    var onboarded = false
    var remindersOn = false
    var reminderHour = 19
    var useMiles = false
    var creditedTx: Set<String> = []
    var freezeWeek = ""
    var aiQuestsDay = ""
    var aiQuests: [QuestTemplate] = []
    var chatDay = ""
    var chatCount = 0
    var aiEngine = "auto"
    var waterDay = ""
    var water = 0
    let waterGoal = 8

    var toast: Toast?
    var fx = FX()

    init() {
        apply(Self.loadSnapshot() ?? Self.fresh())
        store.creditGems = { [weak self] n, tx in self?.creditGems(n, tx) ?? false }
    }

    var isPlus: Bool { store.isPlus }

    private func creditGems(_ n: Int, _ tx: String) -> Bool {
        guard !creditedTx.contains(tx) else { return false }
        creditedTx.insert(tx)
        Telemetry.track("gem_pack_bought")
        gems += n
        show(loc("+\(n) gems"), art: "gem")
        celebrate(.gems)
        save()
        return true
    }

    static let freeChatsPerDay = 5

    var chatsLeft: Int {
        if isPlus { return .max }
        return max(0, Self.freeChatsPerDay - (chatDay == dayKey ? chatCount : 0))
    }

    func countChat() {
        if chatDay != dayKey { chatDay = dayKey; chatCount = 0 }
        chatCount += 1
        save()
    }

    func setAIQuests(_ list: [QuestTemplate]) {
        aiQuests = list
        aiQuestsDay = dayKey
        claimed = claimed.filter { $0 == "chest" }
        save()
    }

    // MARK: Basics

    func key(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    var dayKey: String { key(.now) }
    var startOfToday: Date { cal.startOfDay(for: .now) }
    var hour: Int { cal.component(.hour, from: .now) }
    var today: Int { steps.today }
    var outfit: [Slot: Item] { equipped.compactMapValues(Catalog.item) }
    var progress: Double { min(1, Double(today) / Double(goal)) }
    var remaining: Int { max(0, goal - today) }
    var claimable: Int { max(0, today - claimedSteps) / 10 }

    func show(_ message: String, art: String? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { toast = Toast(text: message, art: art) }
    }

    func celebrate(_ kind: FX.Kind) {
        fx.kind = kind
        fx.tick += 1
    }

    func balance(_ c: Currency) -> Int { c == .coin ? coins : gems }

    private func grant(coins c: Int = 0, gems g: Int = 0, item: String? = nil) {
        coins += c
        gems += g
        if let item { owned.insert(item) }
    }

    private func rewardText(coins c: Int, gems g: Int, item: String? = nil) -> String {
        var parts: [String] = []
        if c > 0 { parts.append(loc("+\(c) coins")) }
        if g > 0 { parts.append(g == 1 ? loc("+1 gem") : loc("+\(g) gems")) }
        if let item, let it = Catalog.item(item) { parts.append(loc("\(it.name) unlocked")) }
        return parts.joined(separator: " · ")
    }

    var daysTogether: Int {
        (cal.dateComponents([.day], from: cal.startOfDay(for: firstDay), to: startOfToday).day ?? 0) + 1
    }

    var journeySteps: Int {
        let start = cal.startOfDay(for: firstDay)
        return steps.daily.filter { $0.key >= start }.values.reduce(0, +)
    }

    var weekSteps: Int {
        (0..<7).reduce(0) { $0 + steps.steps(on: cal.date(byAdding: .day, value: -$1, to: .now)!) }
    }

    func distanceText(_ meters: Double) -> String {
        useMiles ? String(format: "%.1f mi", meters / 1609.34) : String(format: "%.1f km", meters / 1000)
    }

    // MARK: Streak

    func hitGoal(_ d: Date) -> Bool { steps.steps(on: d) >= goal || frozenDays.contains(key(d)) }

    var streak: Int {
        var d = startOfToday
        if !hitGoal(d) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while hitGoal(d) && n < 2000 {
            n += 1
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    var longestStreak: Int {
        var best = 0, run = 0
        for d in steps.daily.keys.sorted() where d <= startOfToday {
            run = hitGoal(d) ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }

    // MARK: Day lifecycle

    func refresh() {
        rollDay()
        checkLevel()
        pushWidget()
        Notifier.reschedule(self)
    }

    func rollDay() {
        guard claimedDay != dayKey else { return }
        if !claimedDay.isEmpty {
            let y = cal.date(byAdding: .day, value: -1, to: startOfToday)!
            let dayBefore = cal.date(byAdding: .day, value: -1, to: y)!
            if !hitGoal(y), hitGoal(dayBefore), streakFreezes > 0 {
                streakFreezes -= 1
                frozenDays.insert(key(y))
                show(loc("Streak freeze saved your streak"), art: "streak_freeze")
            }
        }
        claimedDay = dayKey
        claimedSteps = 0
        claimed = []
        grantWeeklyFreeze()
        save()
    }

    func grantWeeklyFreeze() {
        let c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        let week = "\(c.yearForWeekOfYear ?? 0)-\(c.weekOfYear ?? 0)"
        guard isPlus, freezeWeek != week else { return }
        freezeWeek = week
        streakFreezes += 1
        show(loc("Plus: +1 streak freeze"), art: "streak_freeze")
    }

    func claimSteps() {
        guard claimable > 0 else { return }
        let n = isPlus ? claimable * 3 / 2 : claimable
        coins += n
        claimedSteps += claimable * 10
        Telemetry.track("steps_claimed")
        show(loc("+\(n) coins"), art: "coin")
        celebrate(.coins)
        save()
    }

    // MARK: Level

    static func threshold(_ n: Int) -> Int { 5000 * n * (n - 1) }

    var level: Int {
        var n = 1
        while journeySteps >= Self.threshold(n + 1) { n += 1 }
        return n
    }

    var levelProgress: Double {
        let a = Self.threshold(level), b = Self.threshold(level + 1)
        return Double(journeySteps - a) / Double(b - a)
    }

    func checkLevel() {
        let lv = level
        if rewardedLevel == 0 { rewardedLevel = lv; save(); return }
        guard lv > rewardedLevel else { return }
        let g = lv - rewardedLevel
        gems += g
        rewardedLevel = lv
        Telemetry.track("level_up")
        show(loc("Level \(lv)! +\(g) gems"), art: "gem")
        celebrate(.confetti)
        save()
    }

    // MARK: Pet

    var fullness: Double {
        max(0, storedFullness - Date().timeIntervalSince(fullnessAt) / 3600 * 3)
    }

    var mood: String {
        if fullness < 20 { return "Hungry" }
        if progress >= 1 { return "Proud" }
        if hour >= 22 || hour < 6 { return "Sleepy" }
        return progress >= 0.5 ? "Restless" : "Cheerful"
    }

    var bubble: String {
        let left = remaining.formatted()
        switch mood {
        case "Hungry": return loc("My tummy's rumbling… a snack?")
        case "Proud": return loc("We did it! \(today.formatted()) steps!")
        case "Sleepy": return remaining > 0 ? loc("\(left) to go… or tomorrow?") : loc("Zzz…")
        default:
            if hour >= 16 { return loc("\(left) to go. The light won't wait.") }
            if hour < 11 { return loc("Morning! \(left) steps today?") }
            return loc("\(left) to go. Walk with me?")
        }
    }

    func feed(_ c: Consumable) {
        guard inventory[c.id, default: 0] > 0, c.food > 0 else { return }
        inventory[c.id, default: 0] -= 1
        storedFullness = min(100, fullness + Double(c.food))
        fullnessAt = .now
        Telemetry.track("cat_fed")
        show(loc("\(petName) loved the \(c.name)"), art: c.id)
        save()
    }

    var foods: [Consumable] { content.consumables.filter { $0.food > 0 } }

    // MARK: Shop

    func buy(_ item: Item) {
        guard balance(item.currency) >= item.price, !owned.contains(item.id) else { return }
        if item.currency == .coin { coins -= item.price } else { gems -= item.price }
        owned.insert(item.id)
        equipped[item.slot] = item.id
        Telemetry.track("item_bought")
        show(loc("\(item.name) is yours"), art: item.id)
        celebrate(.confetti)
        save()
    }

    func buy(_ c: Consumable) {
        guard balance(c.currency) >= c.price else { return }
        if c.currency == .coin { coins -= c.price } else { gems -= c.price }
        if c.id == "streak_freeze" { streakFreezes += 1 } else { inventory[c.id, default: 0] += 1 }
        Telemetry.track("treat_bought")
        show(loc("+1 \(c.name)"), art: c.id)
        save()
    }

    func owns(_ c: Consumable) -> Int { c.id == "streak_freeze" ? streakFreezes : inventory[c.id, default: 0] }

    func toggle(_ item: Item) {
        guard owned.contains(item.id) else { return }
        if equipped[item.slot] == item.id {
            equipped[item.slot] = item.slot == .fur ? "fur_ginger" : nil
        } else {
            equipped[item.slot] = item.id
        }
        save()
    }

    func undress() {
        equipped = [.fur: equipped[.fur] ?? "fur_ginger"]
        save()
    }

    // MARK: Looks

    func saveLook(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        Telemetry.track("look_saved")
        looks.append(Look(name: trimmed.isEmpty ? "Look \(looks.count + 1)" : trimmed,
                          equipped: Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value) })))
        save()
    }

    func apply(_ look: Look) {
        equipped = Dictionary(uniqueKeysWithValues: look.equipped.compactMap { k, v in
            Slot(rawValue: k).flatMap { owned.contains(v) ? ($0, v) : nil }
        })
        if equipped[.fur] == nil { equipped[.fur] = "fur_ginger" }
        save()
    }

    func outfit(of look: Look) -> [Slot: Item] {
        Dictionary(uniqueKeysWithValues: look.equipped.compactMap { k, v in
            guard let s = Slot(rawValue: k), let it = Catalog.item(v) else { return nil }
            return (s, it)
        })
    }

    func deleteLooks(at offsets: IndexSet) {
        looks.remove(atOffsets: offsets)
        save()
    }

    // MARK: Quests

    private var dayNumber: UInt64 { UInt64(max(0, startOfToday.timeIntervalSince1970 / 86400)) }

    var quests: [DailyQuest] {
        if aiQuestsDay == dayKey, !aiQuests.isEmpty {
            return aiQuests.prefix(3).map { t in
                DailyQuest(t: t, target: t.kind == .steps ? Int((Double(goal) * t.fraction / 100).rounded()) * 100
                           : t.kind == .activeHours || t.kind == .water ? t.count : t.steps)
            }
        }
        var rng = SeededRNG(state: dayNumber &* 2654435761 &+ 7)
        let isGoal: (QuestTemplate) -> Bool = { $0.kind == .steps && $0.fraction >= 1 }
        let picks = content.quests.filter { !isGoal($0) }.shuffled(using: &rng).prefix(2)
            + content.quests.filter(isGoal).prefix(1)
        return picks.map { t in
            let target: Int
            switch t.kind {
            case .steps: target = Int((Double(goal) * t.fraction / 100).rounded()) * 100
            case .activeHours, .water: target = t.count
            default: target = t.steps
            }
            return DailyQuest(t: t, target: target)
        }
    }

    func value(_ q: DailyQuest) -> Int {
        let h = steps.hourly
        switch q.t.kind {
        case .steps: return today
        case .before: return h.prefix(q.t.hour).reduce(0, +)
        case .after: return h.dropFirst(q.t.hour).reduce(0, +)
        case .activeHours: return h.filter { $0 >= q.t.steps }.count
        case .water: return waterToday
        }
    }

    func isDone(_ q: DailyQuest) -> Bool { value(q) >= q.target }
    func isMissed(_ q: DailyQuest) -> Bool { q.t.kind == .before && hour >= q.t.hour && !isDone(q) }
    func isClaimed(_ q: DailyQuest) -> Bool { claimed.contains(q.id) }

    func claim(_ q: DailyQuest) {
        guard isDone(q), !isClaimed(q) else { return }
        coins += q.t.reward
        claimed.insert(q.id)
        Telemetry.track("quest_claimed")
        show(loc("\(q.t.title) · +\(q.t.reward) coins"), art: "coin")
        celebrate(.coins)
        save()
    }

    var chestOpened: Bool { claimed.contains("chest") }
    var chestReady: Bool { !chestOpened && quests.allSatisfy(isClaimed) }

    func openChest() {
        guard chestReady else { return }
        grant(coins: 30, gems: 1)
        claimed.insert("chest")
        Telemetry.track("chest_opened")
        show(loc("Chest opened · +30 coins · +1 gem"), art: "chest")
        celebrate(.confetti)
        save()
    }

    // MARK: Events

    private func monthDay(_ s: String) -> Int {
        let p = s.split(separator: "-").compactMap { Int($0) }
        return p.count == 2 ? p[0] * 100 + p[1] : 0
    }

    var activeEvent: ActiveEvent? {
        let c = cal.dateComponents([.year, .month, .day], from: .now)
        let now = c.month! * 100 + c.day!
        for e in content.events {
            let s = monthDay(e.start), en = monthDay(e.end)
            let wraps = s > en
            guard wraps ? (now >= s || now <= en) : (now >= s && now <= en) else { continue }
            let startYear = wraps && now <= en ? c.year! - 1 : c.year!
            let start = cal.date(from: DateComponents(year: startYear, month: s / 100, day: s % 100))!
            let end = cal.date(from: DateComponents(year: wraps ? startYear + 1 : startYear, month: en / 100, day: en % 100))!
            return ActiveEvent(event: e, start: start, end: end)
        }
        return nil
    }

    func tokens(_ a: ActiveEvent) -> Int {
        var total = 0, d = a.start
        while d <= startOfToday {
            total += steps.steps(on: d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return total / a.event.stepsPerToken
    }

    private func key(_ a: ActiveEvent, _ m: Milestone) -> String {
        "ev:\(a.event.id):\(cal.component(.year, from: a.start)):\(m.tokens)"
    }

    func isClaimed(_ a: ActiveEvent, _ m: Milestone) -> Bool { claimedForever.contains(key(a, m)) }
    func canClaim(_ a: ActiveEvent, _ m: Milestone) -> Bool { tokens(a) >= m.tokens && !isClaimed(a, m) }

    func claim(_ a: ActiveEvent, _ m: Milestone) {
        guard canClaim(a, m) else { return }
        let dup = m.item.map { owned.contains($0) } ?? false
        grant(coins: m.coins + (dup ? 100 : 0), gems: m.gems, item: m.item)
        claimedForever.insert(key(a, m))
        Telemetry.track("event_reward")
        show(rewardText(coins: m.coins + (dup ? 100 : 0), gems: m.gems, item: dup ? nil : m.item),
             art: dup ? "coin" : m.item ?? (m.gems > 0 ? "gem" : "coin"))
        celebrate(m.item != nil ? .confetti : m.gems > 0 ? .gems : .coins)
        save()
    }

    // MARK: Journey & achievements

    func isReached(_ l: Landmark) -> Bool { journeySteps >= l.steps }
    func isClaimed(_ l: Landmark) -> Bool { claimedForever.contains("lm:\(l.id)") }

    func claim(_ l: Landmark) {
        guard isReached(l), !isClaimed(l) else { return }
        grant(coins: l.coins, gems: l.gems)
        claimedForever.insert("lm:\(l.id)")
        show("\(l.name) · " + rewardText(coins: l.coins, gems: l.gems), art: "coin")
        celebrate(.confetti)
        save()
    }

    func value(_ a: Achievement) -> Int {
        let past = steps.daily.filter { $0.key <= startOfToday }
        switch a.kind {
        case .bestDay: return past.values.max() ?? 0
        case .streak: return longestStreak
        case .lifetime: return past.values.reduce(0, +)
        case .goalDays: return past.values.filter { $0 >= goal }.count
        case .items: return owned.count
        case .level: return level
        case .longestRun: return Int(treks.longest(.run))
        case .treks: return treks.treks.count
        case .trekKm: return Int(treks.totalKm)
        }
    }

    func isUnlocked(_ a: Achievement) -> Bool { value(a) >= a.value }
    func isClaimed(_ a: Achievement) -> Bool { claimedForever.contains("ach:\(a.id)") }

    func claim(_ a: Achievement) {
        guard isUnlocked(a), !isClaimed(a) else { return }
        grant(coins: a.coins, gems: a.gems)
        claimedForever.insert("ach:\(a.id)")
        show("\(a.title) · " + rewardText(coins: a.coins, gems: a.gems), art: a.gems > 0 ? "gem" : "coin")
        celebrate(.confetti)
        save()
    }

    // MARK: Inbox

    var inboxCount: Int {
        var n = claimable > 0 ? 1 : 0
        n += quests.filter { isDone($0) && !isClaimed($0) }.count
        n += chestReady ? 1 : 0
        if let a = activeEvent { n += a.event.milestones.filter { canClaim(a, $0) }.count }
        n += content.landmarks.filter { isReached($0) && !isClaimed($0) }.count
        n += content.achievements.filter { isUnlocked($0) && !isClaimed($0) }.count
        return n
    }

    func claimAll() {
        let before = (coins, gems)
        let quiet = { self.toast = nil }
        claimSteps()
        quests.forEach(claim)
        openChest()
        if let a = activeEvent { a.event.milestones.forEach { claim(a, $0) } }
        content.landmarks.forEach(claim)
        content.achievements.forEach(claim)
        quiet()
        show(rewardText(coins: coins - before.0, gems: gems - before.1), art: "chest")
        celebrate(.confetti)
    }

    // MARK: Friends

    var myCard: Friend {
        Friend(id: profileID, name: petName, fur: equipped[.fur] ?? "fur_ginger", hat: equipped[.hat],
               week: weekSteps, today: today, streak: streak, updated: .now)
    }

    var inviteURL: URL {
        let data = (try? JSONEncoder().encode(myCard)) ?? Data()
        let code = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "meowtrek://friend?d=\(code)")!
    }

    @discardableResult
    func addFriend(from text: String) -> Bool {
        var code = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = code.range(of: "d=") { code = String(code[r.upperBound...]) }
        code = code.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        code += String(repeating: "=", count: (4 - code.count % 4) % 4)
        guard let data = Data(base64Encoded: code),
              let f = try? JSONDecoder().decode(Friend.self, from: data),
              f.id != profileID else { return false }
        if let i = friends.firstIndex(where: { $0.id == f.id }) {
            friends[i] = f
            show(loc("\(f.name) updated"), art: f.fur)
        } else {
            friends.append(f)
            Telemetry.track("friend_added")
            show(loc("\(f.name) joined your pack"), art: f.fur)
            celebrate(.confetti)
        }
        save()
        return true
    }

    func removeFriend(_ f: Friend) {
        friends.removeAll { $0.id == f.id }
        save()
    }

    // MARK: Treks & water

    func rewardTrek(_ t: Trek) {
        let c = isPlus ? t.coins * 3 / 2 : t.coins
        guard c > 0 else { return }
        Telemetry.track("trek_finished_\(t.kind.rawValue)")
        coins += c
        show(loc("\(t.kind.title) done · +\(c) coins"), art: "coin")
        celebrate(.confetti)
        save()
    }

    func shareMeal() {
        Telemetry.track("meal_snapped")
        storedFullness = min(100, fullness + 15)
        fullnessAt = .now
        show(loc("\(petName) shared your meal · +15% food"), art: "fish")
        save()
    }

    var waterToday: Int { waterDay == dayKey ? water : 0 }

    func addWater() {
        if waterDay != dayKey { waterDay = dayKey; water = 0 }
        water += 1
        Telemetry.track("water_logged")
        if water == waterGoal { show(loc("Water goal reached!"), art: "water"); celebrate(.confetti) }
        save()
        Task { await WaterHealth.log() }
    }

    func removeWater() {
        guard waterToday > 0 else { return }
        water -= 1
        save()
    }

    // MARK: Persistence

    private struct Snapshot: Codable {
        var coins, gems, goal, claimedSteps, rewardedLevel, streakFreezes, reminderHour: Int
        var petName, claimedDay, profileID: String
        var owned, claimed, claimedForever, frozenDays: [String]
        var equipped: [String: String]
        var inventory: [String: Int]
        var storedFullness: Double
        var firstDay, fullnessAt: Date
        var looks: [Look]
        var friends: [Friend]
        var onboarded, remindersOn, useMiles: Bool
        var creditedTx: [String]?
        var freezeWeek, aiQuestsDay, chatDay, aiEngine: String?
        var aiQuests: [QuestTemplate]?
        var chatCount: Int?
        var waterDay: String?
        var water: Int?
    }

    private static let storeKey = "meowtrek.v2"

    private static func fresh() -> Snapshot {
        let demo = Self.demo
        return Snapshot(
            coins: demo ? 1645 : 300, gems: 3, goal: 8000, claimedSteps: 0, rewardedLevel: 0, streakFreezes: 1,
            reminderHour: 19, petName: "Gohan", claimedDay: "", profileID: UUID().uuidString,
            owned: ["fur_ginger", "witch_hat", "witch_cloak", "bow", "scarf", "sneakers", "wand"],
            claimed: [], claimedForever: [], frozenDays: [],
            equipped: ["fur": "fur_ginger", "hat": "witch_hat", "body": "witch_cloak", "hand": "wand", "shoes": "sneakers"],
            inventory: ["fish": 2, "milk": 1], storedFullness: 70,
            firstDay: demo ? Calendar.current.date(byAdding: .day, value: -19, to: .now)! : .now, fullnessAt: .now,
            looks: [], friends: [], onboarded: demo, remindersOn: false, useMiles: false,
            creditedTx: nil, freezeWeek: nil, aiQuestsDay: nil, chatDay: nil, aiEngine: nil, aiQuests: nil, chatCount: nil,
            waterDay: nil, water: nil)
    }

    private static func loadSnapshot() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func apply(_ s: Snapshot) {
        coins = s.coins; gems = s.gems; goal = s.goal; claimedSteps = s.claimedSteps
        rewardedLevel = s.rewardedLevel; streakFreezes = s.streakFreezes; reminderHour = s.reminderHour
        petName = s.petName; claimedDay = s.claimedDay; profileID = s.profileID
        owned = Set(s.owned); claimed = Set(s.claimed); claimedForever = Set(s.claimedForever); frozenDays = Set(s.frozenDays)
        equipped = Dictionary(uniqueKeysWithValues: s.equipped.compactMap { k, v in Slot(rawValue: k).map { ($0, v) } })
        inventory = s.inventory; storedFullness = s.storedFullness
        firstDay = s.firstDay; fullnessAt = s.fullnessAt
        looks = s.looks; friends = s.friends
        onboarded = s.onboarded; remindersOn = s.remindersOn; useMiles = s.useMiles
        creditedTx = Set(s.creditedTx ?? []); freezeWeek = s.freezeWeek ?? ""
        aiQuestsDay = s.aiQuestsDay ?? ""; aiQuests = s.aiQuests ?? []
        chatDay = s.chatDay ?? ""; chatCount = s.chatCount ?? 0; aiEngine = s.aiEngine ?? "auto"
        waterDay = s.waterDay ?? ""; water = s.water ?? 0
    }

    func backupData() -> Data { (try? JSONEncoder().encode(snapshot())) ?? Data() }

    func restoreBackup(_ data: Data) throws {
        let s = try JSONDecoder().decode(Snapshot.self, from: data)
        apply(s)
        onboarded = true
        save()
        refresh()
    }

    private func snapshot() -> Snapshot {
        Snapshot(
            coins: coins, gems: gems, goal: goal, claimedSteps: claimedSteps, rewardedLevel: rewardedLevel,
            streakFreezes: streakFreezes, reminderHour: reminderHour, petName: petName, claimedDay: claimedDay,
            profileID: profileID, owned: Array(owned), claimed: Array(claimed), claimedForever: Array(claimedForever),
            frozenDays: Array(frozenDays),
            equipped: Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value) }),
            inventory: inventory, storedFullness: storedFullness, firstDay: firstDay, fullnessAt: fullnessAt,
            looks: looks, friends: friends, onboarded: onboarded, remindersOn: remindersOn, useMiles: useMiles,
            creditedTx: Array(creditedTx), freezeWeek: freezeWeek, aiQuestsDay: aiQuestsDay, chatDay: chatDay,
            aiEngine: aiEngine, aiQuests: aiQuests, chatCount: chatCount, waterDay: waterDay, water: water)
    }

    func save() {
        let s = snapshot()
        UserDefaults.standard.set(try? JSONEncoder().encode(s), forKey: Self.storeKey)
        pushWidget()
    }

    func pushWidget() {
        let wq = quests.map { q in
            WidgetQuest(id: q.id, title: q.t.title, icon: q.t.icon, tint: q.t.tint, value: value(q),
                        target: q.target, reward: q.t.reward, claimed: isClaimed(q))
        }
        WidgetBridge.write(WidgetSnapshot(
            petName: petName, steps: today, goal: goal, streak: streak, mood: mood,
            equipped: Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value) }),
            updated: .now, coins: coins, claimable: isPlus ? claimable * 3 / 2 : claimable,
            water: waterToday, waterGoal: waterGoal, fullness: Int(fullness),
            treats: foods.reduce(0) { $0 + owns($1) }, quests: wq, pettedAt: WidgetBridge.read()?.pettedAt))
        WidgetCenter.shared.reloadAllTimelines()
        WatchLink.shared.send([
            "petName": petName, "goal": goal, "streak": streak, "mood": mood, "steps": today,
            "equipped": Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value) }),
        ])
    }

    /// Applies taps made in the interactive widget since the app last ran.
    func applyWidgetActions() {
        let actions = WidgetBridge.drain()
        guard !actions.isEmpty else { return }
        for a in actions {
            switch a.kind {
            case "water" where a.day == dayKey: addWater()
            case "claim": claimSteps()
            case "feed":
                if let c = foods.sorted(by: { $0.food > $1.food }).first(where: { owns($0) > 0 }) { feed(c) }
            case "quest":
                if a.day == dayKey, let q = quests.first(where: { $0.id == a.arg }) { claim(q) }
            default: break
            }
        }
        Telemetry.track("widget_action")
        pushWidget()
    }

    func resetAll() {
        UserDefaults.standard.removeObject(forKey: Self.storeKey)
        var s = Self.fresh()
        s.onboarded = false
        apply(s)
        save()
    }

    func finishOnboarding(name: String, fur: String, goal: Int) {
        petName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Gohan" : name
        owned.insert(fur)
        equipped[.fur] = fur
        self.goal = goal
        firstDay = .now
        rewardedLevel = level
        claimedDay = dayKey
        onboarded = true
        Telemetry.track("onboarding_done")
        save()
    }
}
