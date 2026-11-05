import SwiftUI

// MARK: - Logic

struct DailyReward {
    let coins: Int
    let gems: Int
    let treat: String?
    let freeze: Bool

    var art: String { treat ?? (gems > 0 ? "gem" : "coin") }
    var label: String {
        if let treat { return Catalog.consumableName(treat) }
        if gems > 0 { return "\(gems)" }
        return "\(coins)"
    }
}

struct PassReward {
    let coins: Int
    let gems: Int
    let treat: String?
    let item: String?

    var art: String { item ?? treat ?? (gems > 0 ? "gem" : "coin") }
    var label: String {
        if let item { return Catalog.item(item)?.name ?? "" }
        if let treat { return Catalog.consumableName(treat) }
        return gems > 0 ? "\(gems)" : "\(coins)"
    }
}

extension Catalog {
    static func consumableName(_ id: String) -> String {
        GameContent.shared.consumables.first { $0.id == id }?.name ?? id
    }
}

extension AppState {
    // Daily calendar

    static let dailyRewards: [DailyReward] = [
        DailyReward(coins: 20, gems: 0, treat: nil, freeze: false),
        DailyReward(coins: 0, gems: 0, treat: "milk", freeze: false),
        DailyReward(coins: 40, gems: 0, treat: nil, freeze: false),
        DailyReward(coins: 0, gems: 1, treat: nil, freeze: false),
        DailyReward(coins: 0, gems: 0, treat: "fish", freeze: false),
        DailyReward(coins: 80, gems: 0, treat: nil, freeze: false),
        DailyReward(coins: 0, gems: 3, treat: nil, freeze: true),
    ]

    var loginClaimedToday: Bool { loginLast == dayKey }

    /// Day 1–7 that today's claim gives; missing a day starts the week again.
    var loginNextDay: Int {
        let yesterday = key(cal.date(byAdding: .day, value: -1, to: startOfToday)!)
        return loginLast == yesterday ? loginDay % 7 + 1 : 1
    }

    var loginShownDay: Int { loginClaimedToday ? loginDay : loginNextDay }

    func claimLogin() {
        guard !loginClaimedToday else { return }
        let day = loginNextDay
        let r = Self.dailyRewards[day - 1]
        coins += r.coins
        gems += r.gems
        if let t = r.treat { inventory[t, default: 0] += 1 }
        if r.freeze { streakFreezes += 1 }
        loginDay = day
        loginLast = dayKey
        Telemetry.track("login_claimed")
        show(loc("Day \(day) reward claimed"), art: r.art)
        celebrate(day == 7 ? .confetti : r.gems > 0 ? .gems : .coins)
        save()
    }

    // Foraging: snacks found while walking

    static let forageSteps = 2000
    static let forageMax = 5

    var forageFound: Int { min(Self.forageMax, today / Self.forageSteps) }
    var forageReady: Int { max(0, forageFound - (forageDay == dayKey ? forageClaimed : 0)) }
    var forageNextProgress: Double {
        forageFound >= Self.forageMax ? 1 : Double(today % Self.forageSteps) / Double(Self.forageSteps)
    }

    func collectForage() {
        let n = forageReady
        guard n > 0 else { return }
        if forageDay != dayKey { forageDay = dayKey; forageClaimed = 0 }
        var rng = SeededRNG(state: UInt64(max(0, Date().timeIntervalSince1970)))
        var found: [String: Int] = [:]
        for _ in 0..<n {
            let r = Double.random(in: 0..<1, using: &rng)
            let id = r < 0.5 ? "milk" : r < 0.85 ? "fish" : "sushi"
            found[id, default: 0] += 1
            inventory[id, default: 0] += 1
        }
        forageClaimed += n
        Telemetry.track("forage_collected")
        let best = ["sushi", "fish", "milk"].first { found[$0] != nil } ?? "fish"
        show(n == 1 ? loc("Found a snack on your walk") : loc("Found \(n) snacks on your walk"), art: best)
        celebrate(.coins)
        save()
    }

    // Expeditions

    var expeditionDef: ExpeditionDef? { expedition.flatMap { e in content.expeditions.first { $0.id == e.id } } }

    var expeditionSteps: Int {
        guard let e = expedition else { return 0 }
        let first = cal.startOfDay(for: e.start)
        var total = steps.steps(on: first) - e.baseline
        var d = cal.date(byAdding: .day, value: 1, to: first)!
        while d <= startOfToday {
            total += steps.steps(on: d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return max(0, total)
    }

    var expeditionDone: Bool { expeditionDef.map { expeditionSteps >= $0.steps } ?? false }

    func startExpedition(_ def: ExpeditionDef) {
        guard expedition == nil else { return }
        expedition = Expedition(id: def.id, start: .now, baseline: today)
        Telemetry.track("expedition_started")
        show(loc("\(petName) set off to \(def.name)"), art: "deco_tree")
        save()
    }

    func cancelExpedition() {
        expedition = nil
        save()
    }

    func finishExpedition() {
        guard let e = expedition, let def = expeditionDef, expeditionDone else { return }
        var rng = SeededRNG(state: UInt64(max(0, e.start.timeIntervalSince1970)))
        let found = def.items.filter { !owned.contains($0) }.randomElement(using: &rng)
        coins += def.coins + (found == nil ? 100 : 0)
        gems += def.gems
        if let found { owned.insert(found) }
        postcards.insert(Postcard(id: def.id, date: .now), at: 0)
        expedition = nil
        Telemetry.track("expedition_done")
        let name = found.flatMap { Catalog.item($0)?.name }
        show(name.map { loc("\(petName) brought back \($0)") } ?? loc("\(petName) brought back \(def.coins + 100) coins"),
             art: found ?? "coin")
        celebrate(.confetti)
        save()
    }

    // Trail Pass

    static let passTiers = 30
    static let passStepsPerTier = 6000

    var seasonID: String { String(dayKey.prefix(7)) }
    var seasonStart: Date { cal.dateInterval(of: .month, for: .now)!.start }
    var seasonEnd: Date { cal.dateInterval(of: .month, for: .now)!.end }

    // MARK: Monthly Plus drop — a premium item gifted free to Plus each month.
    static let plusDropIDs = ["crown", "halo", "pixel_shades", "medal", "pearls",
                              "suit_lamb", "star_pouch", "roller_skates", "fur_lilac", "fur_mint", "fur_sky"]
    var monthlyDrop: Item? {
        let m = cal.component(.month, from: .now)
        return Catalog.item(Self.plusDropIDs[(m - 1) % Self.plusDropIDs.count])
    }
    // MARK: Companion (Plus) — a second cat that keeps your cat company at home.
    var hasCompanion: Bool { isPlus && !companionName.isEmpty }
    var companionOutfit: [Slot: Item] { Catalog.item(companionFur).map { [.fur: $0] } ?? [:] }
    static let companionFurs = ["fur_snow", "fur_smoke", "fur_cocoa", "fur_peach", "fur_charcoal", "fur_honey", "fur_caramel"]
    func adoptCompanion(name: String, fur: String) {
        guard isPlus else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        companionName = n
        companionFur = fur
        Telemetry.track("companion_adopted")
        show(loc("\(n) joined \(petName)!"))
        celebrate(.confetti)
        save()
    }
    func releaseCompanion() { companionName = ""; save() }

    private var dropKey: String { "drop:\(seasonID)" }
    var dropClaimed: Bool { claimedForever.contains(dropKey) }
    func claimDrop() {
        guard isPlus, let d = monthlyDrop, !dropClaimed else { return }
        owned.insert(d.id)
        equipped[d.slot] = d.id
        claimedForever.insert(dropKey)
        Telemetry.track("plus_drop_claimed")
        show(loc("\(d.name) — this month's Plus gift!"), art: d.id)
        celebrate(.confetti)
        save()
    }

    var seasonSteps: Int {
        var total = 0, d = seasonStart
        while d <= startOfToday {
            total += steps.steps(on: d)
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return total
    }

    var passTier: Int { min(Self.passTiers, seasonSteps / Self.passStepsPerTier) }
    var passProgress: Double { passTier >= Self.passTiers ? 1 : Double(seasonSteps % Self.passStepsPerTier) / Double(Self.passStepsPerTier) }

    func passReward(_ tier: Int, plus: Bool) -> PassReward {
        if plus {
            let premium = ["crown", "medal", "fur_lilac"]
            if tier % 10 == 0 {
                let id = premium[(tier / 10 - 1) % premium.count]
                return owned.contains(id) ? PassReward(coins: 0, gems: 5, treat: nil, item: nil) : PassReward(coins: 0, gems: 0, treat: nil, item: id)
            }
            if tier % 4 == 0 { return PassReward(coins: 0, gems: 0, treat: "cake", item: nil) }
            return tier.isMultiple(of: 2) ? PassReward(coins: 0, gems: 1, treat: nil, item: nil) : PassReward(coins: 60 + tier * 10, gems: 0, treat: nil, item: nil)
        }
        if tier == 15 || tier == 30 {
            var rng = SeededRNG(state: UInt64(abs(seasonID.hashValue)) &+ UInt64(tier))
            let pool = content.items.filter { $0.forSale && $0.currency == .coin && $0.slot != .fur && !owned.contains($0.id) }
            if let pick = pool.randomElement(using: &rng) { return PassReward(coins: 0, gems: 0, treat: nil, item: pick.id) }
        }
        if tier % 5 == 0 { return PassReward(coins: 0, gems: 2, treat: nil, item: nil) }
        if tier % 3 == 0 { return PassReward(coins: 0, gems: 0, treat: tier.isMultiple(of: 2) ? "fish" : "milk", item: nil) }
        return PassReward(coins: 30 + tier * 5, gems: 0, treat: nil, item: nil)
    }

    private func passKey(_ tier: Int, plus: Bool) -> String { "tp:\(seasonID):\(tier):\(plus ? "p" : "f")" }
    func passClaimed(_ tier: Int, plus: Bool) -> Bool { claimedForever.contains(passKey(tier, plus: plus)) }
    func passCanClaim(_ tier: Int, plus: Bool) -> Bool { tier <= passTier && !passClaimed(tier, plus: plus) && (!plus || isPlus) }

    var passClaimable: Int {
        (1...Self.passTiers).reduce(0) { $0 + (passCanClaim($1, plus: false) ? 1 : 0) + (passCanClaim($1, plus: true) ? 1 : 0) }
    }

    func claimPass(_ tier: Int, plus: Bool, quiet: Bool = false) {
        guard passCanClaim(tier, plus: plus) else { return }
        let r = passReward(tier, plus: plus)
        coins += r.coins
        gems += r.gems
        if let t = r.treat { inventory[t, default: 0] += 1 }
        if let i = r.item { owned.insert(i) }
        claimedForever.insert(passKey(tier, plus: plus))
        Telemetry.track("pass_claimed")
        if !quiet {
            show(loc("Tier \(tier) · \(r.label)"), art: r.art)
            celebrate(r.item != nil ? .confetti : r.gems > 0 ? .gems : .coins)
        }
        save()
    }

    func claimAllPass() {
        let before = (coins, gems)
        for t in 1...Self.passTiers {
            claimPass(t, plus: false, quiet: true)
            claimPass(t, plus: true, quiet: true)
        }
        show(loc("Trail Pass · +\(coins - before.0) coins · +\(gems - before.1) gems"), art: "chest")
        celebrate(.confetti)
    }

    // Collection sets

    func setOwned(_ s: ItemSet) -> Int { s.items.filter { owned.contains($0) }.count }
    func setComplete(_ s: ItemSet) -> Bool { setOwned(s) == s.items.count }
    func setClaimed(_ s: ItemSet) -> Bool { claimedForever.contains("set:\(s.id)") }

    func claimSet(_ s: ItemSet) {
        guard setComplete(s), !setClaimed(s) else { return }
        coins += s.coins
        gems += s.gems
        claimedForever.insert("set:\(s.id)")
        if title == nil { title = s.id }
        Telemetry.track("set_completed")
        show(loc("\(s.name) set complete · title unlocked"), art: s.items.first ?? "chest")
        celebrate(.confetti)
        save()
    }

    var titleText: String? { title.flatMap { id in content.sets.first { $0.id == id }?.title } }

    // Duels

    func duelWindow(_ d: Duel) -> [String] {
        guard let s = Self.dayParser.date(from: d.start), let e = Self.dayParser.date(from: d.end) else { return [] }
        var out: [String] = [], x = s
        while x <= e { out.append(key(x)); x = cal.date(byAdding: .day, value: 1, to: x)! }
        return out
    }

    func myDuelSteps(_ d: Duel) -> Int {
        duelWindow(d).compactMap { Self.dayParser.date(from: $0) }.filter { $0 <= startOfToday }
            .reduce(0) { $0 + steps.steps(on: $1) }
    }

    func friendDuelSteps(_ d: Duel) -> Int? {
        guard let f = friends.first(where: { $0.id == d.friendID }), let days = f.days else { return nil }
        return duelWindow(d).reduce(0) { $0 + (days[$1] ?? 0) }
    }

    func duelEnded(_ d: Duel) -> Bool { d.end < dayKey }

    /// The friend's card must be newer than the last duel day for a fair result.
    func duelReady(_ d: Duel) -> Bool {
        guard duelEnded(d), let f = friends.first(where: { $0.id == d.friendID }) else { return false }
        return key(f.updated) > d.end
    }

    func createDuel(with f: Friend, days: Int) -> Duel {
        let start: Date
        if days == 2 {
            let weekday = cal.component(.weekday, from: .now)
            let toSaturday = (7 - weekday + 7) % 7
            start = cal.date(byAdding: .day, value: toSaturday, to: startOfToday)!
        } else {
            start = startOfToday
        }
        let end = cal.date(byAdding: .day, value: days - 1, to: start)!
        let duel = Duel(id: UUID().uuidString, friendID: f.id, friendName: f.name, start: key(start), end: key(end))
        duels.insert(duel, at: 0)
        Telemetry.track("duel_created")
        save()
        return duel
    }

    func duelInviteURL(_ d: Duel) -> URL {
        var c = URLComponents(url: inviteURL, resolvingAgainstBaseURL: false)!
        c.queryItems = (c.queryItems ?? []) + [URLQueryItem(name: "duel", value: "\(d.id)_\(d.start)_\(d.end)")]
        return c.url!
    }

    func acceptDuel(_ value: String, from f: Friend) {
        let parts = value.split(separator: "_").map(String.init)
        guard parts.count == 3, !duels.contains(where: { $0.id == parts[0] }) else { return }
        duels.insert(Duel(id: parts[0], friendID: f.id, friendName: f.name, start: parts[1], end: parts[2]), at: 0)
        show(loc("\(f.name) challenged you to a duel"), art: f.fur)
    }

    func claimDuel(_ d: Duel) {
        guard duelReady(d), let i = duels.firstIndex(where: { $0.id == d.id }), !duels[i].claimed,
              let theirs = friendDuelSteps(d) else { return }
        let mine = myDuelSteps(d)
        let reward = mine > theirs ? 120 : mine == theirs ? 60 : 25
        coins += reward
        duels[i].claimed = true
        Telemetry.track("duel_claimed")
        show(mine > theirs ? loc("You beat \(d.friendName)! +\(reward) coins") : loc("Good duel · +\(reward) coins"), art: "coin")
        celebrate(mine > theirs ? .confetti : .coins)
        save()
    }

    func removeDuel(_ d: Duel) {
        duels.removeAll { $0.id == d.id }
        save()
    }

    static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var gameInboxCount: Int {
        (loginClaimedToday ? 0 : 1) + (forageReady > 0 ? 1 : 0) + (expeditionDone ? 1 : 0) + (passClaimable > 0 ? 1 : 0)
            + content.sets.filter { setComplete($0) && !setClaimed($0) }.count
            + duels.filter { duelReady($0) && !$0.claimed }.count
    }
}

// MARK: - Daily calendar

struct DailyRewardCard: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let shown = state.loginShownDay
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                StoryHeading(text: loc("Stamp card"), size: 18, color: .tomato)
                Spacer()
                Text(state.loginClaimedToday ? loc("Next stamp tomorrow") : loc("Day \(shown) of 7"))
                    .font(.story(12, .regular)).italic().foregroundStyle(Color.inkSoft)
            }
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let r = AppState.dailyRewards[day - 1]
                    let done = day < shown || (day == shown && state.loginClaimedToday)
                    let today = day == shown && !state.loginClaimedToday
                    VStack(spacing: 4) {
                        ZStack {
                            SketchSquare(on: today)
                            ArtView(id: r.art, size: day == 7 ? 26 : 21, line: 1.5).opacity(done ? 0.3 : 1)
                            if done {
                                Stamp(text: "\(day)", color: .tomato, size: 30, angle: Double(day * 7 % 20) - 10)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 42)
                        Text(r.label).font(.game(10, .semibold)).foregroundStyle(Color.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            if !state.loginClaimedToday {
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { state.claimLogin() } } label: {
                    Text(loc("Stamp day \(shown)")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.chunky(.sun, radius: 14, padV: 10))
            }
        }
        .card()
    }
}

// MARK: - Expeditions

struct ExpeditionCard: View {
    @Environment(AppState.self) private var state
    @State private var picking = false

    var body: some View {
        Group {
            if let def = state.expeditionDef {
                let done = state.expeditionDone
                HStack(spacing: 12) {
                    GameIcon(symbol: def.icon, tint: Color(hexString: def.tint), size: 48)
                        .overlay(alignment: .bottomTrailing) {
                            CatView(outfit: state.outfit, size: 26, animated: false).offset(x: 8, y: 6)
                        }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(done ? loc("\(state.petName) is home from \(def.name)") : loc("\(state.petName) is off exploring \(def.name)"))
                            .font(.story(16, .bold)).lineLimit(2)
                        ProgressBar(value: Double(state.expeditionSteps) / Double(def.steps), color: Color(hexString: def.tint), height: 8)
                        Text("\(shortSteps(min(state.expeditionSteps, def.steps))) / \(shortSteps(def.steps)) steps")
                            .font(.game(11, .semibold)).foregroundStyle(Color.inkSoft)
                    }
                    Spacer(minLength: 4)
                    if done {
                        Button("Unpack") { withAnimation(.spring) { state.finishExpedition() } }
                            .buttonStyle(.chunky(.sun, padH: 12, padV: 8))
                    }
                }
            } else {
                Button { picking = true } label: {
                    HStack(spacing: 12) {
                        GameIcon(symbol: "map.fill", tint: .grassDark, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pack \(state.petName)'s bag for a trip").font(.story(16, .bold))
                            Text("Your steps carry them there. Something rare waits at the end.").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").foregroundStyle(Color.inkSoft)
                    }
                }
                .buttonStyle(SquishStyle())
            }
        }
        .card(padding: 14)
        .overlay(alignment: .topTrailing) {
            if state.expeditionDef != nil { PaperLabel(text: loc("Expedition"), color: .sky, angle: 4, size: 10).offset(x: -10, y: -8) }
        }
        .sheet(isPresented: $picking) { ExpeditionPicker() }
    }
}

struct ExpeditionPicker: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    StorySection(loc("Where to?"), subtitle: loc("Pick a place. Your everyday steps get \(state.petName) there."), color: .sky)
                    ForEach(state.content.expeditions) { def in
                        Button {
                            state.startExpedition(def)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    InkRing(color: Color(hexString: def.tint), seed: def.steps % 50).frame(width: 60, height: 60)
                                    GameIcon(symbol: def.icon, tint: Color(hexString: def.tint), size: 48)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(def.name).font(.story(18, .bold))
                                    Text("\(def.steps.formatted()) steps away").font(.game(12, .semibold)).foregroundStyle(Color.inkSoft)
                                    HStack(spacing: 4) {
                                        ArtView(id: "coin", size: 14, line: 1.2)
                                        Text("\(def.coins)").font(.game(12, .bold))
                                        if def.gems > 0 { ArtView(id: "gem", size: 14, line: 1.2); Text("\(def.gems)").font(.game(12, .bold)) }
                                        Text("+").font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                                        ForEach(def.items.prefix(3), id: \.self) { id in
                                            if let it = Catalog.item(id) {
                                                ItemArt(item: it, size: 20).opacity(state.owned.contains(id) ? 0.35 : 1)
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Color.inkSoft)
                            }
                            .card(padding: 12)
                        }
                        .buttonStyle(SquishStyle())
                    }
                    if !state.postcards.isEmpty {
                        StorySection(loc("Postcards"), subtitle: loc("Sent home from every trip"), color: .tomato).padding(.top, 8)
                        ForEach(state.postcards.prefix(10)) { p in
                            if let def = state.content.expeditions.first(where: { $0.id == p.id }) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(def.postcard).font(.story(14, .regular)).italic()
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(loc("love, \(state.petName)")).font(.story(13, .semibold)).foregroundStyle(Color.inkSoft)
                                    }
                                    Spacer(minLength: 0)
                                    Rectangle().fill(Color.inkSoft.opacity(0.25)).frame(width: 1).padding(.vertical, 2)
                                    VStack(spacing: 6) {
                                        PostageStamp(color: Color(hexString: def.tint)) {
                                            Image(systemName: def.icon).font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(Color(hexString: def.tint).darker(0.2))
                                                .frame(width: 34, height: 34)
                                        }
                                        .rotationEffect(.degrees(4))
                                        Text(def.name).font(.game(11, .bold)).lineLimit(1)
                                        Text(p.date.formatted(date: .abbreviated, time: .omitted)).font(.game(10, .medium)).foregroundStyle(Color.inkSoft)
                                    }
                                    .frame(width: 84)
                                }
                                .card(padding: 14)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .navigationTitle("Expeditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Close") { dismiss() } }
        }
        .presentationBackground(Color.cream)
    }
}

// MARK: - Trail Pass

struct TrailPassCard: View {
    @Environment(AppState.self) private var state
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    PaperShape(radius: 100, wobble: 1.2, seed: 13).fill(Color.grape.opacity(0.16))
                    InkRing(color: .grapeDark, seed: 13)
                    Text("\(state.passTier)").font(.story(21, .bold)).foregroundStyle(Color.grapeDark)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("Trail Pass").font(.story(17, .bold))
                        Text(loc("Tier \(state.passTier)/\(AppState.passTiers)")).font(.game(11, .semibold)).foregroundStyle(Color.inkSoft)
                    }
                    ProgressBar(value: state.passProgress, color: .grape, height: 8)
                    Text(loc("This page closes \(state.seasonEnd.formatted(.relative(presentation: .named)))")).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
                }
                Spacer(minLength: 4)
                if state.passClaimable > 0 {
                    Text("\(state.passClaimable)").font(.game(13, .bold)).foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 24).background(Circle().fill(Color.tomato))
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(Color.inkSoft)
                }
            }
            .card(padding: 14)
        }
        .buttonStyle(SquishStyle())
        .sheet(isPresented: $open) { TrailPassView() }
    }
}

struct TrailPassView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var paywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        StoryHeading(text: state.seasonStart.formatted(.dateTime.month(.wide)) + " · " + loc("Trail Pass"), size: 24, color: .grape)
                        Text(loc("Every \(AppState.passStepsPerTier.formatted()) steps this month turns a page and unlocks a tier.")).font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft)
                            .padding(.top, 6)
                        ProgressBar(value: state.passProgress, color: .grape, height: 12)
                        Text(loc("Tier \(state.passTier) · \(state.seasonSteps.formatted()) steps")).font(.game(12, .semibold)).foregroundStyle(Color.inkSoft)
                    }
                    .card()
                    .taped(.topTrailing, angle: 5, color: .grape, x: -30)

                    HStack {
                        Label("Free", systemImage: "leaf.fill").foregroundStyle(Color.grassDark)
                        Spacer()
                        Label("Plus", systemImage: "crown.fill").foregroundStyle(Color.sunDark)
                    }
                    .font(.game(13, .bold))
                    .padding(.horizontal, 4)

                    ForEach(1...AppState.passTiers, id: \.self) { tier in row(tier) }
                }
                .padding(16)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .navigationTitle("Trail Pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                if state.passClaimable > 0 {
                    ToolbarItem(placement: .topBarTrailing) { Button("Claim all") { withAnimation { state.claimAllPass() } } }
                }
            }
            .sheet(isPresented: $paywall) { PaywallView() }
        }
        .presentationBackground(Color.cream)
    }

    private func row(_ tier: Int) -> some View {
        let reached = tier <= state.passTier
        return HStack(spacing: 10) {
            cell(tier, plus: false)
            Text("\(tier)").font(.story(14, .bold))
                .frame(width: 30, height: 30)
                .background(PaperShape(radius: 100, wobble: 1, seed: tier).fill(reached ? Color.grape : Color.black.opacity(0.05)))
                .foregroundStyle(reached ? .white : Color.inkSoft)
            cell(tier, plus: true)
        }
    }

    private func cell(_ tier: Int, plus: Bool) -> some View {
        let r = state.passReward(tier, plus: plus)
        let claimed = state.passClaimed(tier, plus: plus)
        let can = state.passCanClaim(tier, plus: plus)
        let locked = plus && !state.isPlus
        return Button {
            if locked { paywall = true } else if can { withAnimation(.spring) { state.claimPass(tier, plus: plus) } }
        } label: {
            HStack(spacing: 8) {
                ArtView(id: r.art, size: 28, line: 1.6).opacity(claimed ? 0.35 : 1)
                Text(r.label).font(.game(13, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if claimed {
                    Stamp(text: loc("Got"), color: .grassDark, size: 30, angle: Double(tier * 11 % 24) - 12)
                } else if locked {
                    Image(systemName: "lock.fill").foregroundStyle(Color.sunDark)
                } else if can {
                    Text("Claim").font(.game(11, .bold)).lineLimit(1).fixedSize().padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Color.sun))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(PaperShape(radius: 12, wobble: 0.9, seed: tier * (plus ? 3 : 2))
                .fill(plus ? Color.sun.opacity(can ? 0.24 : 0.12) : (can ? Color.grassLight : Color.paper)))
        }
        .buttonStyle(SquishStyle())
        .opacity(tier > state.passTier + 2 ? 0.55 : 1)
    }
}

// MARK: - Collection sets

struct SetsSection: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(state.content.sets) { set in
                let have = state.setOwned(set), done = state.setComplete(set), claimed = state.setClaimed(set)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        GameIcon(symbol: set.icon, tint: Color(hexString: set.tint), size: 38)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(set.name).font(.story(17, .bold))
                            Text(loc("Earns the title “\(state.petName) \(set.title)”")).font(.story(12, .regular)).italic().foregroundStyle(Color.inkSoft)
                        }
                        Spacer()
                        if claimed {
                            Button(state.title == set.id ? loc("Shown") : loc("Show title")) {
                                withAnimation(.snappy) { state.title = state.title == set.id ? nil : set.id; state.save() }
                            }
                            .buttonStyle(.chunky(state.title == set.id ? .grass : .paper, text: state.title == set.id ? .white : .ink, radius: 14, padH: 10, padV: 6))
                        } else if done {
                            Button("Claim") { withAnimation(.spring) { state.claimSet(set) } }
                                .buttonStyle(.chunky(.sun, radius: 14, padH: 12, padV: 6))
                        } else {
                            Text("\(have)/\(set.items.count)").font(.game(13, .bold)).foregroundStyle(Color.inkSoft)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(set.items, id: \.self) { id in
                            if let it = Catalog.item(id) {
                                ItemArt(item: it, size: 34)
                                    .opacity(state.owned.contains(id) ? 1 : 0.35)
                                    .frame(maxWidth: .infinity).frame(height: 48)
                                    .background(SketchSquare(on: state.owned.contains(id)))
                            }
                        }
                    }
                    if !claimed {
                        HStack(spacing: 4) {
                            Text("Reward").font(.game(11, .semibold)).foregroundStyle(Color.inkSoft)
                            ArtView(id: "coin", size: 14, line: 1.2); Text("\(set.coins)").font(.game(11, .bold))
                            ArtView(id: "gem", size: 14, line: 1.2); Text("\(set.gems)").font(.game(11, .bold))
                        }
                    }
                }
                .card(padding: 12)
                .overlay(alignment: .topTrailing) {
                    if claimed { Stamp(text: loc("Complete"), color: .grassDark, size: 52, angle: 14).offset(x: 6, y: -10).allowsHitTesting(false) }
                }
            }
        }
    }
}

// MARK: - Duels

struct DuelsSection: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if !state.duels.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                StorySection(loc("Step duels"), subtitle: loc("Friendly races, settled in steps"), color: .tomato)
                ForEach(state.duels) { d in DuelRow(duel: d) }
            }
        }
    }
}

private struct DuelRow: View {
    @Environment(AppState.self) private var state
    let duel: Duel

    var body: some View {
        let mine = state.myDuelSteps(duel)
        let theirs = state.friendDuelSteps(duel)
        let top = max(1, mine, theirs ?? 0)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flag.2.crossed.fill").foregroundStyle(Color.tomato)
                Text(loc("You vs \(duel.friendName)")).font(.story(16, .bold))
                Spacer()
                Text(range).font(.game(11, .semibold)).foregroundStyle(Color.inkSoft)
            }
            bar(loc("You"), mine, top, .grass)
            bar(duel.friendName, theirs ?? 0, top, .grape)
            if duel.claimed {
                HStack {
                    Text(mine > (theirs ?? 0) ? loc("We won this one.") : loc("A good race either way."))
                        .font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft)
                    Spacer()
                    Stamp(text: loc("Settled"), color: .grassDark, size: 46, angle: -12)
                }
                .padding(.top, -4)
            } else if state.duelReady(duel) {
                Button((theirs ?? 0) < mine ? loc("Claim win") : loc("Claim reward")) { withAnimation(.spring) { state.claimDuel(duel) } }
                    .buttonStyle(.chunky(.sun, radius: 14, padH: 12, padV: 7))
            } else if state.duelEnded(duel) {
                Text(loc("Waiting for \(duel.friendName) to share their card")).font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
            } else {
                ShareLink(item: state.duelInviteURL(duel), message: Text(loc("Duel me on Meowtrek! Tap to accept."))) {
                    Label("Send challenge", systemImage: "paperplane.fill").font(.game(12, .bold))
                }
                .buttonStyle(.chunky(.paper, radius: 14, padH: 10, padV: 6))
            }
        }
        .card(padding: 12)
        .contextMenu { Button("Remove", role: .destructive) { state.removeDuel(duel) } }
    }

    private var range: String {
        guard let s = AppState.dayParser.date(from: duel.start), let e = AppState.dayParser.date(from: duel.end) else { return "" }
        return s.formatted(.dateTime.day().month()) + " – " + e.formatted(.dateTime.day().month())
    }

    private func bar(_ name: String, _ value: Int, _ top: Int, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.game(12, .semibold)).lineLimit(1).frame(width: 70, alignment: .leading)
            ProgressBar(value: Double(value) / Double(top), color: tint, height: 8)
            Text(shortSteps(value)).font(.game(12, .bold)).monospacedDigit().frame(width: 44, alignment: .trailing)
        }
    }
}

struct ChallengeSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let friend: Friend
    @State private var created: Duel?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.2.crossed.fill").font(.system(size: 34)).foregroundStyle(Color.tomato)
            StoryHeading(text: loc("Challenge \(friend.name)"), size: 24, color: .tomato)
            Text("Whoever walks more takes 120 coins. Nobody goes home empty-pawed.")
                .font(.story(14, .regular)).italic().foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                .padding(.top, 4)
            if let created {
                ShareLink(item: state.duelInviteURL(created), message: Text(loc("Duel me on Meowtrek! Tap to accept."))) {
                    Label("Send challenge", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.chunky(.grass, text: .white, radius: 18, padV: 14))
            } else {
                Button { created = state.createDuel(with: friend, days: 2) } label: { Text("This weekend").frame(maxWidth: .infinity) }
                    .buttonStyle(.chunky(.sun, radius: 18, padV: 14))
                Button { created = state.createDuel(with: friend, days: 3) } label: { Text("Next 3 days").frame(maxWidth: .infinity) }
                    .buttonStyle(.chunky(.paper, radius: 18, padV: 14))
            }
        }
        .foregroundStyle(Color.ink)
        .padding(24)
        .presentationDetents([.height(370)])
        .presentationBackground { ZStack { Color.cream; PaperGrain() } }
    }
}
