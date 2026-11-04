import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showSettings = false
    @State private var showCloset = ProcessInfo.processInfo.arguments.contains("-closet")
    @State private var showInbox = false
    @State private var showFeed = false
    @State private var showEvent = false
    @State private var showCoach = false
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var personalizing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PetScene(showCloset: $showCloset, showSettings: $showSettings,
                         showInbox: $showInbox, showFeed: $showFeed, showCoach: $showCoach)
                VStack(alignment: .leading, spacing: 14) {
                    stepsCard
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Today").font(.game(24, .black))
                            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month()))
                                .font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                        }
                        Spacer()
                        Button { personalize() } label: {
                            HStack(spacing: 5) {
                                if personalizing { ProgressView().controlSize(.small) } else { Image(systemName: "wand.and.stars") }
                                Text(state.aiQuestsDay == state.dayKey ? "AI quests" : "Personalize")
                            }
                        }
                        .buttonStyle(.chunky(.grape.opacity(0.18), text: .grapeDark, radius: 18, padH: 12, padV: 7))
                        .disabled(personalizing)
                    }
                    .padding(.top, 4)
                    if let a = state.activeEvent { eventCard(a) }
                    chestCard
                    ForEach(state.quests) { QuestRow(q: $0) }
                }
                .foregroundStyle(Color.ink)
                .padding(16)
                .padding(.bottom, 20)
                .background(Color.cream, in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
                .padding(.top, -30)
            }
        }
        .background(Color.cream)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await state.steps.load(); state.refresh() }
        .navigationDestination(isPresented: $showCloset) { ClosetView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showInbox) { InboxView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showFeed) { FeedSheet().presentationDetents([.height(420)]) }
        .sheet(isPresented: $showEvent) { EventView().presentationDetents([.large]) }
        .sheet(isPresented: $showCoach) { CoachView() }
        .sheet(isPresented: $showShare) { ShareCardsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func personalize() {
        guard state.isPlus else { showPaywall = true; return }
        guard let engine = Coach.engine(state) else { state.show(CoachError.unavailable.localizedDescription); return }
        personalizing = true
        let ctx = Coach.context(state)
        Task {
            do {
                let q = try await engine.quests(ctx)
                withAnimation(.spring) { state.setAIQuests(q) }
                state.show("\(state.petName) made today's quests", art: "token_petal")
            } catch {
                state.show(error.localizedDescription)
            }
            personalizing = false
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                GameIcon(symbol: "shoeprints.fill", tint: .tomato, size: 40)
                VStack(alignment: .leading, spacing: -2) {
                    Text(state.today.formatted())
                        .font(.game(38, .black))
                        .contentTransition(.numericText())
                    Text("of \(state.goal.formatted()) steps").font(.game(13, .bold)).foregroundStyle(Color.inkSoft)
                }
                Spacer()
                Button { withAnimation(.spring) { state.claimSteps() } } label: {
                    HStack(spacing: 6) {
                        ArtView(id: "coin", size: 24, line: 1.8)
                        VStack(alignment: .leading, spacing: -2) {
                            Text("+\(state.claimable)").font(.game(17, .black)).contentTransition(.numericText())
                            Text("CLAIM").font(.game(10, .black))
                        }
                    }
                }
                .buttonStyle(.chunky(.sun, padH: 12, padV: 7))
                .disabled(state.claimable == 0)
            }
            ProgressBar(value: state.progress, height: 12)
            HStack {
                Text(state.remaining == 0
                     ? "Goal reached — \(state.petName) is proud!"
                     : "\(state.remaining.formatted()) to go · about \(max(1, state.remaining / 100)) min")
                Spacer()
                Text("\(Int(state.progress * 100))%").font(.game(14, .black)).foregroundStyle(Color.grassDark)
                Button { showShare = true } label: { Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .bold)) }
                    .buttonStyle(.chunky(.grassLight, text: .grassDark, radius: 14, padH: 9, padV: 6))
            }
            .font(.game(13, .bold))
            .foregroundStyle(Color.inkSoft)
        }
        .card()
    }

    private func eventCard(_ a: ActiveEvent) -> some View {
        let tokens = state.tokens(a)
        let ready = a.event.milestones.filter { state.canClaim(a, $0) }.count
        let next = a.event.milestones.first { tokens < $0.tokens }
        let prev = a.event.milestones.last { tokens >= $0.tokens }?.tokens ?? 0
        return Button { showEvent = true } label: {
            HStack(spacing: 12) {
                GameIcon(symbol: a.event.icon, tint: Color(hexString: a.event.tint), size: 50)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(a.event.name).font(.game(18, .black))
                        Tag(text: "Event", color: .sun, textColor: .ink)
                    }
                    HStack(spacing: 4) {
                        ArtView(id: a.event.tokenArt, size: 18, line: 1.4)
                        Text("\(tokens) \(a.event.token)").font(.game(13, .bold))
                        if let next { Text("· next at \(next.tokens)").font(.game(12, .bold)).foregroundStyle(.white.opacity(0.6)) }
                    }
                    if let next {
                        ProgressBar(value: Double(tokens - prev) / Double(max(1, next.tokens - prev)), color: .sun, height: 10)
                    }
                }
                Spacer(minLength: 4)
                if ready > 0 {
                    Text("\(ready)").font(.game(16, .black)).foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.tomato)).overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                } else {
                    Image(systemName: "chevron.right").font(.game(16, .black)).foregroundStyle(.white.opacity(0.7))
                }
            }
            .foregroundStyle(.white)
            .card(padding: 14, color: .night)
        }
        .buttonStyle(SquishStyle())
    }

    private var chestCard: some View {
        HStack(spacing: 12) {
            ArtView(id: "chest", size: 56, line: 2.5)
                .rotationEffect(.degrees(state.chestReady ? -6 : 0))
                .animation(state.chestReady ? .easeInOut(duration: 0.25).repeatForever(autoreverses: true) : .default,
                           value: state.chestReady)
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily chest").font(.game(18, .black))
                Text(state.chestOpened ? "Opened · see you tomorrow"
                     : state.chestReady ? "Ready to open!" : "Finish all 3 quests")
                    .lineLimit(1)
                    .font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                HStack(spacing: 5) {
                    ForEach(state.quests) { q in
                        Capsule().fill(state.isClaimed(q) ? Color.grass : Color.paper)
                            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                            .frame(width: 28, height: 10)
                    }
                }
            }
            Spacer()
            Button { withAnimation { state.openChest() } } label: {
                Text(state.chestOpened ? "Done" : "Open")
            }
            .buttonStyle(.chunky(.tomato, text: .white))
            .disabled(!state.chestReady)
        }
        .card(color: .chestBg)
    }
}

struct QuestRow: View {
    @Environment(AppState.self) private var state
    let q: DailyQuest

    var body: some View {
        let done = state.isDone(q), claimed = state.isClaimed(q), missed = state.isMissed(q)
        HStack(spacing: 12) {
            GameIcon(symbol: q.t.icon, tint: Color(hexString: q.t.tint), size: 46, muted: missed)
            VStack(alignment: .leading, spacing: 5) {
                Text(q.t.title).font(.game(17, .black))
                if claimed {
                    Text("Claimed · +\(q.t.reward) coins").font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                } else if done {
                    Text("Done! Tap claim").font(.game(12, .black)).foregroundStyle(Color.grassDark)
                } else if missed {
                    Text("Missed · \(q.detail)").font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                } else {
                    Text(q.detail).font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                    HStack(spacing: 6) {
                        ProgressBar(value: Double(state.value(q)) / Double(max(1, q.target)),
                                    color: Color(hexString: q.t.tint), height: 10)
                        Text("\(shortSteps(state.value(q)))/\(shortSteps(q.target))").font(.game(11, .bold))
                            .foregroundStyle(Color.inkSoft).fixedSize()
                    }
                }
            }
            Spacer(minLength: 4)
            if claimed {
                Image(systemName: "checkmark").font(.game(16, .black)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.grass)).overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            } else {
                Button { withAnimation { state.claim(q) } } label: {
                    HStack(spacing: 4) {
                        ArtView(id: "coin", size: 18, line: 1.4)
                        Text(done ? "Claim" : "\(q.t.reward)")
                    }
                }
                .buttonStyle(.chunky(done ? .sun : .paper, padH: 10, padV: 7))
                .disabled(!done)
            }
        }
        .foregroundStyle(Color.ink)
        .opacity(missed ? 0.65 : 1)
        .card(padding: 14)
    }
}

// MARK: - Scene

private struct PetScene: View {
    @Environment(AppState.self) private var state
    @Binding var showCloset: Bool
    @Binding var showSettings: Bool
    @Binding var showInbox: Bool
    @Binding var showFeed: Bool
    @Binding var showCoach: Bool
    @State private var drift = false
    @State private var hop = 0
    @State private var hearts = 0

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
        case .morning: [Color(hex: 0xFFD9B8), Color(hex: 0xFFF0D6)]
        case .day: [Color(hex: 0x8FD3FF), Color(hex: 0xD8F1FF)]
        case .sunset: [Color(hex: 0xFF9E7A), Color(hex: 0xFFD59A)]
        case .night: [Color(hex: 0x1E1B4B), Color(hex: 0x4A3F8C)]
        }
    }

    private var decor: [String] {
        if let a = state.activeEvent { return a.event.decor }
        switch Calendar.current.component(.month, from: .now) {
        case 3...5: return ["tulip", "deco_bush", "butterfly"]
        case 6...8: return ["deco_sunflower", "deco_bush", "deco_sunflower"]
        case 9...11: return ["mushroom", "deco_bush", "deco_tree"]
        default: return ["deco_snowman", "deco_pine", "deco_pine"]
        }
    }

    var body: some View {
        let night = phase == .night
        let hill = night ? Color(hex: 0x3F7A4A) : Color.grass
        let farHill = night ? Color(hex: 0x2F5E45) : Color(hex: 0x9BD67A)
        ZStack {
            LinearGradient(colors: sky, startPoint: .top, endPoint: .bottom)

            if night {
                ForEach(0..<12, id: \.self) { i in
                    star(50, 50, 50).fill(Color.sun.opacity(0.9))
                        .frame(width: CGFloat(6 + i % 3 * 3), height: CGFloat(6 + i % 3 * 3))
                        .offset(x: CGFloat((i * 73) % 340) - 170, y: CGFloat((i * 47) % 150) - 170)
                }
                ZStack {
                    Circle().sticker(Color(hex: 0xFFF3C4), 3)
                    Circle().fill(Color(hex: 0xEAD9A0)).frame(width: 12).offset(x: -8, y: 6)
                    Circle().fill(Color(hex: 0xEAD9A0)).frame(width: 8).offset(x: 10, y: -8)
                }
                .frame(width: 54).offset(x: 130, y: -120)
            } else {
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Capsule().fill(Color.sun.opacity(0.6)).frame(width: 6, height: 18)
                            .offset(y: -44).rotationEffect(.degrees(Double(i) * 45))
                    }
                    Circle().sticker(phase == .sunset ? Color(hex: 0xFF8A5B) : .sun, 3).frame(width: 60)
                }
                .offset(x: 130, y: -118)
                .rotationEffect(.degrees(drift ? 8 : -8), anchor: .center)
            }

            ArtView(id: "deco_cloud", size: 90, line: 3).opacity(night ? 0.35 : 1)
                .offset(x: drift ? -60 : -140, y: -150)
            ArtView(id: "deco_cloud", size: 64, line: 3).opacity(night ? 0.3 : 0.9)
                .offset(x: drift ? 120 : 40, y: -70)

            oval(50, 50, 100, 100).sticker(farHill, 3)
                .frame(width: 360, height: 220).offset(x: -150, y: 120)
            oval(50, 50, 100, 100).sticker(farHill, 3)
                .frame(width: 380, height: 240).offset(x: 170, y: 110)

            ArtView(id: "deco_tree", size: 110, line: 3).offset(x: -140, y: 50)
            ArtView(id: "deco_lamp", size: 80, line: 3).offset(x: 150, y: 50)
                .shadow(color: night ? Color.sun.opacity(0.8) : .clear, radius: 18)

            UPath { p, pt in
                p.move(to: pt(-5, 30))
                p.addQuadCurve(to: pt(105, 26), control: pt(50, -4))
                p.addLine(to: pt(105, 105)); p.addLine(to: pt(-5, 105)); p.closeSubpath()
            }
            .sticker(hill, 3)
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .bottom)

            UPath { p, pt in
                p.move(to: pt(42, 18)); p.addQuadCurve(to: pt(58, 18), control: pt(50, 14))
                p.addQuadCurve(to: pt(80, 100), control: pt(78, 60))
                p.addLine(to: pt(20, 100))
                p.addQuadCurve(to: pt(42, 18), control: pt(22, 60))
            }
            .sticker(night ? Color(hex: 0xB8A98A) : Color(hex: 0xF5DFAE), 3)
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .bottom)

            ArtView(id: decor[0], size: 62, line: 3).offset(x: 130, y: 140)
            ArtView(id: decor[1 % decor.count], size: 54, line: 3).offset(x: -150, y: 150)
            ArtView(id: decor[2 % decor.count], size: 42, line: 3).offset(x: 160, y: 85)

            Ellipse().fill(Color.ink.opacity(0.18)).frame(width: 110, height: 18).offset(y: 168)
            Button {
                hop += 1
                hearts += 1
            } label: {
                CatView(outfit: state.outfit, size: 150, mood: CatMood(state.mood), hop: hop)
            }
            .buttonStyle(.plain)
            .offset(y: 86)
            .sensoryFeedback(.impact(weight: .light), trigger: hop)

            HeartBurst(trigger: hearts).offset(y: 10)

            SpeechBubble(text: state.bubble).offset(y: -52)

            topBar.frame(maxHeight: .infinity, alignment: .top)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(state.petName).font(.game(15, .black))
                    Text(state.mood).font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Color.paper)).overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                Text("Lv \(state.level)").font(.game(13, .black))
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .background(Capsule().fill(Color.sun)).overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                Spacer()
                Button { showFeed = true } label: {
                    HStack(spacing: 4) {
                        ArtView(id: "fish", size: 20, line: 1.5)
                        Text("\(Int(state.fullness))%").monospacedDigit()
                    }
                }
                .buttonStyle(.chunky(state.fullness < 20 ? .tomato : .paper, text: state.fullness < 20 ? .white : .ink,
                                     radius: 20, padH: 10, padV: 6))
                Button { showCoach = true } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.game(14, .black))
                }
                .buttonStyle(.chunky(.sun, text: .ink, radius: 20, padH: 10, padV: 7))
                Button { showCloset = true } label: {
                    Image(systemName: "tshirt.fill").font(.game(15, .black))
                }
                .buttonStyle(.chunky(.grape, text: .white, radius: 20, padH: 11, padV: 7))
            }
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 16).padding(.bottom, 44)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 440)
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button { showSettings = true } label: {
                Image(systemName: "line.3.horizontal").font(.game(16, .black))
            }
            .buttonStyle(.chunky(.paper, radius: 20, padH: 10, padV: 8))
            HStack(spacing: 4) {
                Image(systemName: "heart.fill").foregroundStyle(Color.tomato)
                Text("\(state.daysTogether)d")
            }
            .font(.game(13, .black))
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(Capsule().fill(Color.paper)).overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
            Spacer(minLength: 4)
            Pill(art: "coin", text: state.coins.formatted())
            Pill(art: "gem", text: "\(state.gems)")
            Button { showInbox = true } label: {
                Image(systemName: "bell.fill").font(.game(15, .black))
                    .overlay(alignment: .topTrailing) {
                        if state.inboxCount > 0 {
                            Text("\(state.inboxCount)").font(.game(10, .black)).foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Circle().fill(Color.tomato)).overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                                .offset(x: 14, y: -14)
                        }
                    }
            }
            .buttonStyle(.chunky(.sun, radius: 20, padH: 10, padV: 8))
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 14)
        .padding(.top, 60)
    }
}

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: -3) {
            Text(text)
                .font(.game(14, .heavy))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.paper))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 1))
            Triangle().fill(Color.paper)
                .overlay(UPath { p, pt in
                    p.move(to: pt(0, 0)); p.addLine(to: pt(50, 100)); p.addLine(to: pt(100, 0))
                }.line(2.5))
                .rotationEffect(.degrees(180))
                .frame(width: 18, height: 11)
        }
        .frame(maxWidth: 260)
        .id(text)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: text)
    }
}

private struct HeartBurst: View {
    let trigger: Int
    @State private var items: [Int] = []

    var body: some View {
        ZStack {
            ForEach(items, id: \.self) { i in Floater(seed: i) }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) {
            let base = trigger * 10
            items.append(contentsOf: base..<(base + 4))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                items.removeAll { $0 >= base && $0 < base + 4 }
            }
        }
    }

    private struct Floater: View {
        let seed: Int
        @State private var up = false

        var body: some View {
            Image(systemName: "heart.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Color.tomato)
                .shadow(color: .ink, radius: 0, x: 0, y: 2)
                .offset(x: CGFloat((seed % 4) * 26 - 39), y: up ? -90 : 0)
                .scaleEffect(up ? 1.2 : 0.3)
                .opacity(up ? 0 : 1)
                .onAppear {
                    withAnimation(.easeOut(duration: 1).delay(Double(seed % 4) * 0.06)) { up = true }
                }
        }
    }
}

// MARK: - Sheets

struct FeedSheet: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                CatView(outfit: state.outfit, size: 64, mood: CatMood(state.mood))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Feed \(state.petName)").font(.game(22, .black))
                    ProgressBar(value: state.fullness / 100, color: state.fullness < 20 ? .tomato : .grass, height: 14)
                    Text("Fullness \(Int(state.fullness))% · drops 3% an hour").font(.game(12, .bold))
                        .foregroundStyle(Color.inkSoft)
                }
            }
            ForEach(state.foods) { c in
                let have = state.owns(c)
                HStack(spacing: 12) {
                    ArtView(id: c.id, size: 44, line: 2.2)
                    VStack(alignment: .leading) {
                        Text(c.name).font(.game(16, .black))
                        Text("+\(c.food)% · you have \(have)").font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                    }
                    Spacer()
                    if have > 0 {
                        Button("Feed") { withAnimation { state.feed(c) } }
                            .buttonStyle(.chunky(.grass, text: .white))
                    } else {
                        Button { state.buy(c) } label: {
                            HStack(spacing: 4) {
                                ArtView(id: c.currency == .coin ? "coin" : "gem", size: 18, line: 1.4)
                                Text("\(c.price)")
                            }
                        }
                        .buttonStyle(.chunky(.sun))
                        .disabled(state.balance(c.currency) < c.price)
                    }
                }
                .card(padding: 10)
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
            ScrollView {
                VStack(spacing: 12) {
                    if state.claimable > 0 {
                        row(art: "coin", "Walking coins", "\(state.claimable * 10) unclaimed steps", "+\(state.claimable)") { state.claimSteps() }
                    }
                    ForEach(state.quests.filter { state.isDone($0) && !state.isClaimed($0) }) { q in
                        row(symbol: q.t.icon, tint: q.t.tint, q.t.title, "Daily quest", "+\(q.t.reward)") { state.claim(q) }
                    }
                    if state.chestReady {
                        row(art: "chest", "Daily chest", "All quests done", "+30 +1 gem") { state.openChest() }
                    }
                    if let a = state.activeEvent {
                        ForEach(a.event.milestones.filter { state.canClaim(a, $0) }) { m in
                            row(art: m.item ?? a.event.tokenArt, a.event.name, "\(m.tokens) \(a.event.token)", reward(m)) { state.claim(a, m) }
                        }
                    }
                    ForEach(state.content.landmarks.filter { state.isReached($0) && !state.isClaimed($0) }) { l in
                        row(symbol: l.icon, tint: l.tint, l.name, "Landmark reached", reward(l.coins, l.gems)) { state.claim(l) }
                    }
                    ForEach(state.content.achievements.filter { state.isUnlocked($0) && !state.isClaimed($0) }) { a in
                        row(symbol: a.icon, tint: a.tint, a.title, a.detail, reward(a.coins, a.gems)) { state.claim(a) }
                    }
                    if state.inboxCount == 0 {
                        VStack(spacing: 10) {
                            ArtView(id: "chest", size: 80, line: 3)
                            Text("All caught up!").font(.game(20, .black))
                            Text("Walk more to earn rewards.").font(.game(14, .bold)).foregroundStyle(Color.inkSoft)
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .foregroundStyle(Color.ink)
            .background(Color.cream)
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if state.inboxCount > 1 {
                    Button("Claim all") { withAnimation { state.claimAll() } }.font(.game(15, .black))
                }
            }
        }
    }

    private func reward(_ m: Milestone) -> String {
        m.item.flatMap { Catalog.item($0)?.name } ?? reward(m.coins, m.gems)
    }

    private func reward(_ c: Int, _ g: Int) -> String {
        [c > 0 ? "+\(c)" : nil, g > 0 ? "+\(g) gem" : nil].compactMap { $0 }.joined(separator: " ")
    }

    private func row(art: String? = nil, symbol: String? = nil, tint: String = "6CC24A",
                     _ title: String, _ detail: String, _ reward: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            if let art { ArtView(id: art, size: 44, line: 2.2) } else { GameIcon(symbol: symbol ?? "star.fill", tint: Color(hexString: tint), size: 44) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.game(16, .black))
                Text(detail).font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Button { withAnimation { action() } } label: { Text(reward) }
                .buttonStyle(.chunky(.sun, padH: 10, padV: 7))
        }
        .card(padding: 12)
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
                        VStack(spacing: 10) {
                            GameIcon(symbol: a.event.icon, tint: Color(hexString: a.event.tint), size: 76)
                            HStack(spacing: 8) {
                                ArtView(id: a.event.tokenArt, size: 36, line: 2.4)
                                Text("\(tokens)").font(.game(40, .black))
                            }
                            Text("1 \(a.event.token) per \(a.event.stepsPerToken) steps · \(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                                .font(.game(13, .bold)).foregroundStyle(.white.opacity(0.75))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .card(padding: 22, color: .night)

                        ForEach(a.event.milestones) { m in milestoneRow(a, m, tokens: tokens) }
                    }
                    .padding(16)
                }
                .background(Color.cream)
                .navigationTitle(a.event.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.font(.game(15, .black)) }
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
                if let item { ItemArt(item: item, size: 50) } else { ArtView(id: m.gems > 0 ? "gem" : "coin", size: 42, line: 2.4) }
            }
            .frame(width: 60, height: 60)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cream))
            .outlined(14, width: 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(item?.name ?? [m.coins > 0 ? "\(m.coins) coins" : nil, m.gems > 0 ? "\(m.gems) gems" : nil]
                    .compactMap { $0 }.joined(separator: " + "))
                    .font(.game(16, .black))
                HStack(spacing: 4) {
                    ArtView(id: a.event.tokenArt, size: 14, line: 1.2)
                    Text("\(m.tokens) \(a.event.token)").font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                }
                if !claimed && tokens < m.tokens {
                    ProgressBar(value: Double(tokens) / Double(m.tokens), color: .sun, height: 10)
                }
            }
            Spacer()
            if claimed {
                Image(systemName: "checkmark").font(.game(16, .black)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.grass)).overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            } else {
                Button("Claim") { withAnimation { state.claim(a, m) } }
                    .buttonStyle(.chunky(.sun))
                    .disabled(tokens < m.tokens)
            }
        }
        .foregroundStyle(Color.ink)
        .card(padding: 12)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var showPaywall = false

    var body: some View {
        @Bindable var s = state
        NavigationStack {
            Form {
                Section {
                    Button { showPaywall = true } label: {
                        HStack {
                            GameIcon(symbol: "crown.fill", tint: .sun, size: 34)
                            VStack(alignment: .leading) {
                                Text(state.isPlus ? "Meowtrek Plus" : "Get Meowtrek Plus").font(.game(16, .bold)).foregroundStyle(Color.ink)
                                Text(state.isPlus ? "Thanks for supporting us!" : "AI coach, insights, 1.5× coins").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                            }
                        }
                    }
                }
                Section {
                    Picker("AI engine", selection: $s.aiEngine) {
                        Text("Automatic").tag("auto")
                        Text("On this iPhone").tag("device")
                        Text("Cloud").tag("cloud")
                    }
                    LabeledContent("On-device AI", value: Coach.onDeviceAvailable ? "Available" : "Not available")
                    LabeledContent("Cloud AI", value: Coach.cloudAvailable ? "Configured" : "Not configured")
                } header: {
                    Text("AI coach")
                } footer: {
                    Text("Automatic uses Apple Intelligence on supported iPhones and falls back to the cloud coach.")
                }
                Section("Connected devices") {
                    DevicesSection()
                }
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
                    Text("Meowtrek nudges you if you're short of your goal, and before events end.")
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
                    LabeledContent("Streak freezes", value: "\(state.streakFreezes)")
                    Button("Reconnect Apple Health") { Task { await state.steps.load(); state.refresh() } }
                } header: {
                    Text("Data")
                } footer: {
                    Text("With no Health data or access, Meowtrek shows demo steps. Allow access in Settings › Health › Data Access.")
                }
                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }
            }
            .fontDesign(.rounded)
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() }.font(.game(15, .black)) }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .confirmationDialog("Reset everything?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { state.resetAll(); dismiss() }
            } message: {
                Text("Coins, items, looks, friends and rewards will be erased. Step history stays in Apple Health.")
            }
        }
        .tint(.grassDark)
        .onDisappear {
            state.save()
            Notifier.reschedule(state)
        }
    }
}
