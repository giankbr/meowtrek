import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showSettings = false
    @State private var showCloset = false
    @State private var showInbox = false
    @State private var showFeed = false
    @State private var showEvent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PetScene(showCloset: $showCloset, showSettings: $showSettings,
                         showInbox: $showInbox, showFeed: $showFeed)
                VStack(alignment: .leading, spacing: 12) {
                    stepsCard
                    Text("Today").font(.title3.weight(.bold)).padding(.top, 6)
                    if let a = state.activeEvent { eventCard(a) }
                    chestCard
                    ForEach(state.quests) { questRow($0) }
                }
                .padding(16)
                .background(Color.cream, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .padding(.top, -28)
            }
        }
        .background(Color.cream)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await state.steps.load(); state.refresh() }
        .navigationDestination(isPresented: $showCloset) { ClosetView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showInbox) { InboxView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showFeed) { FeedSheet().presentationDetents([.height(340)]) }
        .sheet(isPresented: $showEvent) { EventView().presentationDetents([.large]) }
    }

    // MARK: Cards

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "shoeprints.fill").foregroundStyle(Color.ink)
                Text(state.today.formatted())
                    .font(.system(size: 34, weight: .bold))
                    .contentTransition(.numericText())
                Text("/ \(state.goal.formatted()) steps")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSoft)
                Spacer()
                Button { withAnimation(.spring) { state.claimSteps() } } label: {
                    VStack(spacing: 0) {
                        Text("+\(state.claimable)").font(.headline.weight(.heavy)).contentTransition(.numericText())
                        Text("CLAIM").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Color(hex: 0x7A5200))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.honey, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(state.claimable == 0 ? 0.45 : 1)
                .disabled(state.claimable == 0)
            }
            ProgressBar(value: state.progress)
            HStack {
                Text(state.remaining == 0
                     ? "🐾 Goal reached — \(state.petName) is proud"
                     : "🐾 \(state.remaining.formatted()) to go · about \(max(1, state.remaining / 100)) min")
                Spacer()
                Text("\(Int(state.progress * 100))%").fontWeight(.bold).foregroundStyle(Color.leafDark)
            }
            .font(.caption)
            .foregroundStyle(Color.inkSoft)
        }
        .card()
    }

    private func eventCard(_ a: ActiveEvent) -> some View {
        let tokens = state.tokens(a)
        let ready = a.event.milestones.filter { state.canClaim(a, $0) }.count
        let next = a.event.milestones.first { tokens < $0.tokens }
        let subtitle = ready > 0 ? "\(ready) reward\(ready > 1 ? "s" : "") ready"
            : next.map { "\($0.tokens - tokens) more to next reward" } ?? "all rewards collected"
        return Button { showEvent = true } label: {
            HStack(spacing: 12) {
                Text(a.event.icon).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.event.name).font(.headline)
                    Text("\(tokens) \(a.event.token) · \(subtitle)").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text(ready > 0 ? "Open" : "View").font(.caption.weight(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(ready > 0 ? Color.honey : .white.opacity(0.15), in: Capsule())
                    .foregroundStyle(ready > 0 ? Color.night : .white)
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.night, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var chestCard: some View {
        HStack(spacing: 12) {
            Text("🧰").font(.system(size: 30))
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily chest").font(.headline)
                Text(state.chestOpened ? "Opened · see you tomorrow"
                     : state.chestReady ? "Ready to open!" : "Claim all three to open")
                    .font(.caption).foregroundStyle(Color.inkSoft)
                HStack(spacing: 4) {
                    ForEach(state.quests) { q in
                        Capsule().fill(state.isClaimed(q) ? Color.leaf : Color.leafLight.opacity(0.6))
                            .frame(width: 30, height: 6)
                    }
                }
            }
            Spacer()
            Button { withAnimation { state.openChest() } } label: {
                Text("🪙 +30 💎").font(.subheadline.weight(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(state.chestReady ? Color.honey : .clear, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!state.chestReady)
        }
        .foregroundStyle(Color.ink)
        .padding(16)
        .background(Color.chestBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func questRow(_ q: DailyQuest) -> some View {
        QuestRow(q: q)
    }
}

struct QuestRow: View {
    @Environment(AppState.self) private var state
    let q: DailyQuest

    var body: some View {
        let done = state.isDone(q), claimed = state.isClaimed(q), missed = state.isMissed(q)
        HStack(spacing: 12) {
            Text(q.t.icon).font(.system(size: 30)).grayscale(missed ? 1 : 0)
            VStack(alignment: .leading, spacing: 4) {
                Text(q.t.title).font(.headline)
                if claimed {
                    Text("Claimed · +\(q.t.reward) coins").font(.caption).foregroundStyle(Color.inkSoft)
                } else if done {
                    Text("Done · tap Claim").font(.caption.weight(.semibold)).foregroundStyle(Color.leafDark)
                } else if missed {
                    Text("Missed · \(q.detail)").font(.caption).foregroundStyle(Color.inkSoft)
                } else {
                    Text("\(q.detail) · \(state.value(q).formatted())/\(q.target.formatted())")
                        .font(.caption).foregroundStyle(Color.inkSoft)
                    ProgressBar(value: Double(state.value(q)) / Double(max(1, q.target)), height: 5).frame(width: 120)
                }
            }
            Spacer()
            if claimed {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Color.leaf)
            } else {
                Button { withAnimation { state.claim(q) } } label: {
                    Text(done ? "Claim" : "🪙 \(q.t.reward)")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(done ? Color.honey : Color.cream, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!done)
            }
        }
        .foregroundStyle(Color.ink)
        .opacity(missed ? 0.6 : 1)
        .card()
    }
}

// MARK: - Scene

private struct PetScene: View {
    @Environment(AppState.self) private var state
    @Binding var showCloset: Bool
    @Binding var showSettings: Bool
    @Binding var showInbox: Bool
    @Binding var showFeed: Bool

    private enum Phase { case morning, day, sunset, night }

    private var phase: Phase {
        switch state.hour {
        case 5..<10: .morning
        case 10..<16: .day
        case 16..<20: .sunset
        default: .night
        }
    }

    private var sky: [Color] {
        switch phase {
        case .morning: [Color(hex: 0xFCE3C4), Color(hex: 0xF1EBD3), Color(hex: 0xC5D9AE)]
        case .day: [Color(hex: 0xBFE0F2), Color(hex: 0xE6F0DA), Color(hex: 0xBFD3A6)]
        case .sunset: [Color(hex: 0xF9C99E), Color(hex: 0xEDDDC0), Color(hex: 0xBFD3A6)]
        case .night: [Color(hex: 0x1F2A44), Color(hex: 0x3B4A6B), Color(hex: 0x5F7462)]
        }
    }

    private var decor: [String] {
        if let a = state.activeEvent { return a.event.decor }
        switch Calendar.current.component(.month, from: .now) {
        case 3...5: return ["🌷", "🌼", "🐝"]
        case 6...8: return ["🌻", "🌼", "🦋"]
        case 9...11: return ["🍂", "🍁", "🍄"]
        default: return ["⛄", "🌲", "❄️"]
        }
    }

    var body: some View {
        let night = phase == .night
        ZStack {
            LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom)
            if night {
                Text("🌙").font(.system(size: 34)).offset(x: 130, y: -120)
                Text("✦     ✧        ✦\n   ✧       ✦    ✧").font(.caption).foregroundStyle(.white.opacity(0.7))
                    .offset(x: -40, y: -110)
            } else {
                Text(phase == .sunset ? "🌅" : "☀️").font(.system(size: 34)).offset(x: 130, y: -115)
                Text("☁️").font(.system(size: 30)).offset(x: -110, y: -105).opacity(0.8)
            }
            Ellipse().trim(from: 0.5, to: 1)
                .stroke(Color(hex: night ? 0x6F7A86 : 0xD9C6A5), lineWidth: 12)
                .frame(width: 320, height: 130)
                .offset(x: 90, y: 70)
            Rectangle().fill(Color(hex: night ? 0x3F5C70 : 0x9CC3C9))
                .frame(height: 95)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 40)
            Text("🦢").font(.system(size: 22)).offset(x: 110, y: 105)
            Rectangle().fill(Color(hex: night ? 0x8C8470 : 0xE6D6B6))
                .frame(height: 70)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Text("🏮").font(.system(size: 26)).offset(x: -150, y: -20)
                .shadow(color: night ? .orange : .clear, radius: 12)
            Text("🌳").font(.system(size: 70)).offset(x: -150, y: 50)
            Text(decor[0]).font(.system(size: 46)).offset(x: 125, y: 150)
            Text(decor[1 % decor.count]).font(.system(size: 28)).offset(x: 165, y: 160)
            Text(decor[2 % decor.count]).font(.system(size: 24)).offset(x: -130, y: 125)

            Button { showCloset = true } label: {
                CatView(outfit: state.outfit, size: 150)
                    .opacity(night ? 0.92 : 1)
            }
            .buttonStyle(.plain)
            .offset(y: 80)

            Text(state.bubble)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                .offset(y: -50)
                .contentTransition(.opacity)

            topBar.frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(state.petName).fontWeight(.bold)
                    Text("·")
                    Text(state.mood)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(Color.ink.opacity(0.2)))
                Text("Lv \(state.level)").fontWeight(.bold)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Color.honey, in: Capsule())
                Spacer()
                Button { showFeed = true } label: {
                    HStack(spacing: 4) {
                        Text("🍖")
                        Text("\(Int(state.fullness))%").fontWeight(.bold).monospacedDigit()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(state.fullness < 20 ? Color(hex: 0xF7C6C0) : .white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 16).padding(.bottom, 44)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 420)
        .clipped()
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { showSettings = true } label: { circleIcon("line.3.horizontal") }
            Label("\(state.daysTogether) days", systemImage: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(phase == .night ? Color.leafLight : Color.leafDark)
                .lineLimit(1)
            Spacer(minLength: 4)
            Pill(icon: "🪙", text: state.coins.formatted())
            Pill(icon: "💎", text: "\(state.gems)")
            Button { showInbox = true } label: {
                circleIcon("bell.fill")
                    .overlay(alignment: .topTrailing) {
                        if state.inboxCount > 0 {
                            Text("\(state.inboxCount)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color(hex: 0xE5707A), in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private func circleIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.ink)
            .frame(width: 34, height: 34)
            .background(.white, in: Circle())
    }
}

// MARK: - Sheets

struct FeedSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Feed \(state.petName)").font(.title3.weight(.bold))
                Spacer()
                Text("🍖 \(Int(state.fullness))%").font(.headline)
            }
            ProgressBar(value: state.fullness / 100, color: state.fullness < 20 ? Color(hex: 0xE5707A) : .leaf)
            Text("Fullness drops 3% an hour. A fed cat stays cheerful.")
                .font(.caption).foregroundStyle(Color.inkSoft)
            ForEach(state.foods) { c in
                let have = state.owns(c)
                HStack(spacing: 12) {
                    Text(c.emoji).font(.system(size: 30))
                    VStack(alignment: .leading) {
                        Text(c.name).font(.headline)
                        Text("+\(c.food)% · you have \(have)").font(.caption).foregroundStyle(Color.inkSoft)
                    }
                    Spacer()
                    if have > 0 {
                        Button("Feed") { withAnimation { state.feed(c) } }
                            .buttonStyle(.borderedProminent).tint(.leaf)
                    } else {
                        Button("\(c.currency.icon) \(c.price)") { state.buy(c) }
                            .buttonStyle(.bordered).tint(.ink)
                            .disabled(state.balance(c.currency) < c.price)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.ink)
        .padding(20)
        .background(Color.cream)
    }
}

struct InboxView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            List {
                if state.claimable > 0 {
                    row("👣", "Walking coins", "\(state.claimable * 10) unclaimed steps", "+\(state.claimable) 🪙") { state.claimSteps() }
                }
                ForEach(state.quests.filter { state.isDone($0) && !state.isClaimed($0) }) { q in
                    row(q.t.icon, q.t.title, "Daily quest", "+\(q.t.reward) 🪙") { state.claim(q) }
                }
                if state.chestReady {
                    row("🧰", "Daily chest", "All quests done", "+30 🪙 +1 💎") { state.openChest() }
                }
                if let a = state.activeEvent {
                    ForEach(a.event.milestones.filter { state.canClaim(a, $0) }) { m in
                        row(a.event.icon, a.event.name, "\(m.tokens) \(a.event.token)", reward(m)) { state.claim(a, m) }
                    }
                }
                ForEach(state.content.landmarks.filter { state.isReached($0) && !state.isClaimed($0) }) { l in
                    row(l.emoji, l.name, "Landmark reached", reward(l.coins, l.gems)) { state.claim(l) }
                }
                ForEach(state.content.achievements.filter { state.isUnlocked($0) && !state.isClaimed($0) }) { a in
                    row(a.icon, a.title, a.detail, reward(a.coins, a.gems)) { state.claim(a) }
                }
                if state.inboxCount == 0 {
                    ContentUnavailableView("All caught up", systemImage: "tray",
                                           description: Text("Walk more to earn rewards."))
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if state.inboxCount > 1 {
                    Button("Claim all") { withAnimation { state.claimAll() } }
                }
            }
        }
    }

    private func reward(_ m: Milestone) -> String {
        m.item.flatMap { Catalog.item($0)?.name } ?? reward(m.coins, m.gems)
    }

    private func reward(_ c: Int, _ g: Int) -> String {
        [c > 0 ? "+\(c) 🪙" : nil, g > 0 ? "+\(g) 💎" : nil].compactMap { $0 }.joined(separator: " ")
    }

    private func row(_ icon: String, _ title: String, _ detail: String, _ reward: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(icon).font(.system(size: 28))
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Button { withAnimation { action() } } label: {
                Text(reward).font(.caption.weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.honey, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.ink)
    }
}

struct EventView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let a = state.activeEvent {
                let tokens = state.tokens(a)
                let daysLeft = (Calendar.current.dateComponents([.day], from: state.startOfToday, to: a.end).day ?? 0) + 1
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            Text(a.event.icon).font(.system(size: 60))
                            Text("\(tokens) \(a.event.tokenIcon)").font(.system(size: 32, weight: .bold))
                            Text("1 \(a.event.token) per \(a.event.stepsPerToken) steps · \(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                                .font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.night, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        ForEach(a.event.milestones) { m in
                            milestoneRow(a, m, tokens: tokens)
                        }
                    }
                    .padding(16)
                }
                .background(Color.cream)
                .navigationTitle(a.event.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
            } else {
                ContentUnavailableView("No event right now", systemImage: "calendar")
            }
        }
    }

    private func milestoneRow(_ a: ActiveEvent, _ m: Milestone, tokens: Int) -> some View {
        let item = m.item.flatMap(Catalog.item)
        let claimed = state.isClaimed(a, m)
        return HStack(spacing: 12) {
            Group {
                if let item { ItemArt(item: item, size: 40) } else { Text(m.gems > 0 ? "💎" : "🪙").font(.system(size: 30)) }
            }
            .frame(width: 52, height: 52)
            .background(Color.cream, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(item?.name ?? [m.coins > 0 ? "\(m.coins) coins" : nil, m.gems > 0 ? "\(m.gems) gems" : nil]
                    .compactMap { $0 }.joined(separator: " + "))
                    .font(.headline)
                Text("\(m.tokens) \(a.event.token)").font(.caption).foregroundStyle(Color.inkSoft)
                if !claimed && tokens < m.tokens {
                    ProgressBar(value: Double(tokens) / Double(m.tokens), height: 5)
                }
            }
            Spacer()
            if claimed {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Color.leaf)
            } else {
                Button("Claim") { withAnimation { state.claim(a, m) } }
                    .buttonStyle(.borderedProminent).tint(.honey).foregroundStyle(Color.night)
                    .disabled(tokens < m.tokens)
            }
        }
        .foregroundStyle(Color.ink)
        .card()
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        @Bindable var s = state
        NavigationStack {
            Form {
                Section("Pet") {
                    TextField("Name", text: $s.petName)
                    LabeledContent("Level", value: "\(state.level) · \(Int(state.levelProgress * 100))% to next")
                    LabeledContent("Together since", value: state.firstDay.formatted(date: .abbreviated, time: .omitted))
                }
                Section("Daily goal") {
                    Stepper("\(state.goal.formatted()) steps", value: $s.goal, in: 2000...30000, step: 500)
                }
                Section {
                    Toggle("Walk reminders", isOn: Binding(get: { state.remindersOn }, set: { on in
                        Task {
                            let ok = on ? await Notifier.requestAuth() : true
                            state.remindersOn = on && ok
                            if on && !ok { state.show("Allow notifications in Settings") }
                            state.save()
                            Notifier.reschedule(state)
                        }
                    }))
                    if state.remindersOn {
                        Picker("Remind at", selection: $s.reminderHour) {
                            ForEach(6..<23) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Pawstep nudges you if you're short of your goal, and before events end.")
                }
                Section("Units") {
                    Picker("Distance", selection: $s.useMiles) {
                        Text("Kilometres").tag(false)
                        Text("Miles").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    LabeledContent("Step source", value: state.steps.source == .health ? "Apple Health" : "Demo data")
                    LabeledContent("Live pedometer", value: state.steps.live ? "On" : "Off")
                    LabeledContent("Streak freezes", value: "🧊 \(state.streakFreezes)")
                    Button("Reconnect Apple Health") { Task { await state.steps.load(); state.refresh() } }
                } header: {
                    Text("Data")
                } footer: {
                    Text("With no Health data or access, Pawstep shows demo steps. Allow access in Settings › Health › Data Access.")
                }
                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .confirmationDialog("Reset everything?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { state.resetAll(); dismiss() }
            } message: {
                Text("Coins, items, looks, friends and rewards will be erased. Step history stays in Apple Health.")
            }
        }
        .onDisappear {
            state.save()
            Notifier.reschedule(state)
        }
    }
}
