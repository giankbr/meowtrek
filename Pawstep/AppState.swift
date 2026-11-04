import SwiftUI
import Observation
import WidgetKit

struct DailyQuest: Identifiable {
    let t: QuestTemplate
    let target: Int
    var id: String { t.id }
    var unit: String { t.kind == .activeHours ? "active hours" : "steps" }
    var detail: String {
        switch t.kind {
        case .steps: "Walk \(target.formatted()) steps"
        case .before: "\(target.formatted()) steps before \(t.hour):00"
        case .after: "\(target.formatted()) steps after \(t.hour):00"
        case .activeHours: "\(target) hours with \(t.steps)+ steps"
        }
    }
}

struct ActiveEvent {
    let event: GameEvent
    let start: Date
    let end: Date
}

@Observable
final class AppState {
    @ObservationIgnored let steps = StepStore()
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

    var toast: String?

    init() {
        apply(Self.loadSnapshot() ?? Self.fresh())
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

    func show(_ message: String) { withAnimation(.spring) { toast = message } }

    func balance(_ c: Currency) -> Int { c == .coin ? coins : gems }

    private func grant(coins c: Int = 0, gems g: Int = 0, item: String? = nil) {
        coins += c
        gems += g
        if let item { owned.insert(item) }
    }

    private func rewardText(coins c: Int, gems g: Int, item: String? = nil) -> String {
        var parts: [String] = []
        if c > 0 { parts.append("+\(c) 🪙") }
        if g > 0 { parts.append("+\(g) 💎") }
        if let item, let it = Catalog.item(item) { parts.append("\(it.name) unlocked") }
        return parts.joined(separator: "  ")
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
                show("🧊 Streak freeze saved your streak")
            }
        }
        claimedDay = dayKey
        claimedSteps = 0
        claimed = []
        save()
    }

    func claimSteps() {
        guard claimable > 0 else { return }
        let n = claimable
        coins += n
        claimedSteps += n * 10
        show("+\(n) 🪙")
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
        show("🎉 Level \(lv)!  +\(g) 💎")
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
        case "Hungry": return "My tummy's rumbling… a snack?"
        case "Proud": return "We did it! \(today.formatted()) steps!"
        case "Sleepy": return remaining > 0 ? "\(left) to go… or tomorrow?" : "Zzz…"
        default:
            if hour >= 16 { return "\(left) to go. The light won't wait." }
            if hour < 11 { return "Morning! \(left) steps today?" }
            return "\(left) to go. Walk with me?"
        }
    }

    func feed(_ c: Consumable) {
        guard inventory[c.id, default: 0] > 0, c.food > 0 else { return }
        inventory[c.id, default: 0] -= 1
        storedFullness = min(100, fullness + Double(c.food))
        fullnessAt = .now
        show("😋 \(petName) loved the \(c.name)")
        save()
    }

    var foods: [Consumable] { content.consumables.filter { $0.food > 0 } }

    // MARK: Shop

    func buy(_ item: Item) {
        guard balance(item.currency) >= item.price, !owned.contains(item.id) else { return }
        if item.currency == .coin { coins -= item.price } else { gems -= item.price }
        owned.insert(item.id)
        equipped[item.slot] = item.id
        show("🛍️ \(item.name) is yours")
        save()
    }

    func buy(_ c: Consumable) {
        guard balance(c.currency) >= c.price else { return }
        if c.currency == .coin { coins -= c.price } else { gems -= c.price }
        if c.id == "streak_freeze" { streakFreezes += 1 } else { inventory[c.id, default: 0] += 1 }
        show("\(c.emoji) +1 \(c.name)")
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
        var rng = SeededRNG(state: dayNumber &* 2654435761 &+ 7)
        let isGoal: (QuestTemplate) -> Bool = { $0.kind == .steps && $0.fraction >= 1 }
        let picks = content.quests.filter { !isGoal($0) }.shuffled(using: &rng).prefix(2)
            + content.quests.filter(isGoal).prefix(1)
        return picks.map { t in
            let target: Int
            switch t.kind {
            case .steps: target = Int((Double(goal) * t.fraction / 100).rounded()) * 100
            case .activeHours: target = t.count
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
        }
    }

    func isDone(_ q: DailyQuest) -> Bool { value(q) >= q.target }
    func isMissed(_ q: DailyQuest) -> Bool { q.t.kind == .before && hour >= q.t.hour && !isDone(q) }
    func isClaimed(_ q: DailyQuest) -> Bool { claimed.contains(q.id) }

    func claim(_ q: DailyQuest) {
        guard isDone(q), !isClaimed(q) else { return }
        coins += q.t.reward
        claimed.insert(q.id)
        show("\(q.t.icon) +\(q.t.reward) 🪙")
        save()
    }

    var chestOpened: Bool { claimed.contains("chest") }
    var chestReady: Bool { !chestOpened && quests.allSatisfy(isClaimed) }

    func openChest() {
        guard chestReady else { return }
        grant(coins: 30, gems: 1)
        claimed.insert("chest")
        show("🧰 +30 🪙  +1 💎")
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
        show("\(a.event.icon) " + rewardText(coins: m.coins + (dup ? 100 : 0), gems: m.gems, item: dup ? nil : m.item))
        save()
    }

    // MARK: Journey & achievements

    func isReached(_ l: Landmark) -> Bool { journeySteps >= l.steps }
    func isClaimed(_ l: Landmark) -> Bool { claimedForever.contains("lm:\(l.id)") }

    func claim(_ l: Landmark) {
        guard isReached(l), !isClaimed(l) else { return }
        grant(coins: l.coins, gems: l.gems)
        claimedForever.insert("lm:\(l.id)")
        show("\(l.emoji) " + rewardText(coins: l.coins, gems: l.gems))
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
        }
    }

    func isUnlocked(_ a: Achievement) -> Bool { value(a) >= a.value }
    func isClaimed(_ a: Achievement) -> Bool { claimedForever.contains("ach:\(a.id)") }

    func claim(_ a: Achievement) {
        guard isUnlocked(a), !isClaimed(a) else { return }
        grant(coins: a.coins, gems: a.gems)
        claimedForever.insert("ach:\(a.id)")
        show("\(a.icon) " + rewardText(coins: a.coins, gems: a.gems))
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
        show(rewardText(coins: coins - before.0, gems: gems - before.1))
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
        return URL(string: "pawstep://friend?d=\(code)")!
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
            show("🔄 \(f.name) updated")
        } else {
            friends.append(f)
            show("🐾 \(f.name) joined your pack")
        }
        save()
        return true
    }

    func removeFriend(_ f: Friend) {
        friends.removeAll { $0.id == f.id }
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
    }

    private static let storeKey = "pawstep.v2"

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
            looks: [], friends: [], onboarded: demo, remindersOn: false, useMiles: false)
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
    }

    func save() {
        let s = Snapshot(
            coins: coins, gems: gems, goal: goal, claimedSteps: claimedSteps, rewardedLevel: rewardedLevel,
            streakFreezes: streakFreezes, reminderHour: reminderHour, petName: petName, claimedDay: claimedDay,
            profileID: profileID, owned: Array(owned), claimed: Array(claimed), claimedForever: Array(claimedForever),
            frozenDays: Array(frozenDays),
            equipped: Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value) }),
            inventory: inventory, storedFullness: storedFullness, firstDay: firstDay, fullnessAt: fullnessAt,
            looks: looks, friends: friends, onboarded: onboarded, remindersOn: remindersOn, useMiles: useMiles)
        UserDefaults.standard.set(try? JSONEncoder().encode(s), forKey: Self.storeKey)
        pushWidget()
    }

    func pushWidget() {
        WidgetBridge.write(WidgetSnapshot(
            petName: petName, steps: today, goal: goal, streak: streak, mood: mood,
            equipped: Dictionary(uniqueKeysWithValues: equipped.map { ($0.key.rawValue, $0.value) }),
            updated: .now))
        WidgetCenter.shared.reloadAllTimelines()
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
        save()
    }
}
