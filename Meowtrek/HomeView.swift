import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var state
    @State private var showSettings = false
    @State private var showCloset = ProcessInfo.processInfo.arguments.contains("-closet")
    @State private var showInbox = false
    @State private var showFeed = false
    @State private var showEvent = false
    @State private var showCoach = false
    @State private var showShare = ProcessInfo.processInfo.arguments.contains("-share")
    @State private var showPaywall = false
    @State private var personalizing = false
    @State private var showTrek = false
    @State private var showMeal = false
    @State private var waterPulse = false
    @State private var devWallpapers = ProcessInfo.processInfo.arguments.contains("-wallpapers")

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                PetScene(showCloset: $showCloset, showSettings: $showSettings,
                         showInbox: $showInbox, showFeed: $showFeed, showCoach: $showCoach)
                    .overlay(alignment: .bottom) {
                        TornEdge().fill(Color.cream)
                            .shadow(color: .black.opacity(0.08), radius: 1.5, y: -1)
                            .frame(height: 30)
                    }
                VStack(alignment: .leading, spacing: 16) {
                    stepsCard.padding(.top, 14)
                    Button { showTrek = true } label: {
                        Label("Head out for a walk, run or hike", systemImage: "location.north.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chunky(.grass, text: .white, radius: 14, padV: 13))
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            StoryHeading(text: loc("\(state.petName)'s diary"), size: 24)
                            Text("Little errands for today").font(.game(12, .semibold)).foregroundStyle(Color.inkSoft)
                        }
                        Spacer()
                        Button { personalize() } label: {
                            HStack(spacing: 5) {
                                if personalizing { ProgressView().controlSize(.small) } else { Image(systemName: "wand.and.stars") }
                                Text(state.aiQuestsDay == state.dayKey ? "AI errands" : "Personalize")
                            }
                        }
                        .buttonStyle(.chunky(.grape.opacity(0.18), text: .grapeDark, radius: 14, padH: 12, padV: 7))
                        .disabled(personalizing)
                    }
                    .padding(.top, 6)
                    diary.appearIn(0)
                    StorySection(loc("More for today"), subtitle: loc("Treats, water and this season's event"), color: .pumpkin)
                        .padding(.top, 10)
                        .appearIn(1)
                    DailyRewardCard().appearIn(1)
                    if let a = state.activeEvent { eventCard(a).appearIn(2) }
                    waterCard.appearIn(3)
                    Button { showMeal = true } label: {
                        HStack(spacing: 12) {
                            GameIcon(symbol: "camera.fill", tint: .pumpkin, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Snap your meal").font(.story(17, .bold))
                                Text("\(state.petName) reacts · no calorie counting").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                            }
                            Spacer()
                            if !state.isPlus { Tag(text: loc("Plus"), color: .sun, textColor: .ink) }
                        }
                        .card()
                    }
                    .buttonStyle(SquishStyle())
                    .appearIn(4)
                }
                .foregroundStyle(Color.ink)
                .padding(16)
                .padding(.bottom, 20)
            }
        }
        .paperBackground()
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await state.steps.load(); state.refresh() }
        .navigationDestination(isPresented: $showCloset) { ClosetView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showInbox) { InboxView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showFeed) { FeedSheet().presentationDetents([.height(510), .large]) }
        .sheet(isPresented: $showEvent) { EventView().presentationDetents([.large]) }
        .sheet(isPresented: $showCoach) { CoachView() }
        .sheet(isPresented: $showShare) { ShareCardsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .fullScreenCover(isPresented: $showTrek) { TrekRecordView() }
        .sheet(isPresented: $showMeal) { MealView() }
        .sheet(isPresented: $devWallpapers) { WallpapersView() }
    }

    private var waterCard: some View {
        let n = state.waterToday, goal = state.waterGoal
        return HStack(spacing: 12) {
            ArtView(id: "water", size: 44)
                .scaleEffect(waterPulse ? 1.12 : 1, anchor: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text("Water").font(.story(17, .bold))
                HStack(spacing: 4) {
                    ForEach(0..<goal, id: \.self) { i in
                        Capsule().fill(i < n ? Color.sky : Color.sky.opacity(0.18))
                            .frame(width: 10, height: 16)
                            .scaleEffect(waterPulse && i == min(n, goal) - 1 ? 1.3 : 1)
                    }
                }
                Text(n >= goal ? loc("Goal reached · \(n) glasses") : loc("\(n) of \(goal) glasses"))
                    .font(.game(12, .medium)).foregroundStyle(n >= goal ? Color.skyDark : Color.inkSoft)
                    .lineLimit(1).fixedSize()
                    .contentTransition(.numericText(value: Double(n)))
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                RoundIconButton(symbol: "minus") { withAnimation(.snappy) { state.removeWater() } }
                    .disabled(n == 0)
                RoundIconButton(symbol: "plus", fill: .sky, tint: .white) {
                    withAnimation(.snappy) { state.addWater() }
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { waterPulse = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { waterPulse = false }
                    }
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: n)
        }
        .card()
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
                Telemetry.track("ai_quests")
                state.show(loc("\(state.petName) made today's quests"), art: "token_petal")
            } catch {
                state.show(error.localizedDescription)
            }
            personalizing = false
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's page").font(.story(15, .semibold)).italic().foregroundStyle(Color.inkSoft)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month()))
                    .font(.game(12, .semibold)).foregroundStyle(Color.inkSoft)
            }
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: -4) {
                    Text(state.today.formatted())
                        .font(.story(46, .bold))
                        .contentTransition(.numericText())
                    Text("steps · goal \(state.goal.formatted())").font(.game(13, .semibold)).foregroundStyle(Color.inkSoft)
                }
                Spacer()
                Button { withAnimation(.spring) { state.claimSteps() } } label: {
                    VStack(spacing: 1) {
                        HStack(spacing: 4) {
                            ArtView(id: "coin", size: 22, line: 1.6)
                            Text("+\(state.claimable)").font(.game(17, .bold)).contentTransition(.numericText())
                        }
                        Text("Collect").font(.game(11, .semibold))
                    }
                }
                .buttonStyle(.chunky(.sun, radius: 14, padH: 12, padV: 7))
                .disabled(state.claimable == 0)
            }
            ProgressBar(value: state.progress, height: 14)
            HStack(spacing: 8) {
                Text(state.remaining == 0
                     ? "Goal reached — \(state.petName) is proud!"
                     : "\(state.remaining.formatted()) steps left · a \(max(1, state.remaining / 100))-minute stroll")
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer()
                Text("\(Int(state.progress * 100))%").font(.story(15, .bold)).foregroundStyle(Color.grassDark)
                Button { showShare = true } label: { Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .bold)) }
                    .buttonStyle(.chunky(.grassLight, text: .grassDark, radius: 12, padH: 9, padV: 6))
            }
            .font(.game(13, .semibold))
            .foregroundStyle(Color.inkSoft)
        }
        .card(padding: 18)
        .taped(.top, angle: -3)
    }

    /// Today's quests on a ruled diary page, with the treasure box at the foot.
    private var diary: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.quests.enumerated()), id: \.element.id) { i, q in
                QuestRow(q: q).padding(.vertical, 12)
                Rectangle().fill(Color.sky.opacity(0.35)).frame(height: 1)
            }
            chestRow.padding(.top, 12)
        }
        .padding(.leading, 6)
        .card(padding: 14)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.tomato.opacity(0.3)).frame(width: 1.2).padding(.vertical, 8).padding(.leading, 56)
        }
        .taped(.topTrailing, angle: 6, color: .bubble, x: -24, width: 48)
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
                        Text("Event").font(.game(11, .bold)).foregroundStyle(Color.night)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.sun))
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

    private var chestRow: some View {
        HStack(spacing: 12) {
            ArtView(id: "chest", size: 44, line: 2.2)
                .frame(width: 40)
                .rotationEffect(.degrees(state.chestReady ? -6 : 0))
                .animation(state.chestReady ? .easeInOut(duration: 0.25).repeatForever(autoreverses: true) : .default,
                           value: state.chestReady)
            VStack(alignment: .leading, spacing: 2) {
                Text("Treasure box").font(.story(16, .bold))
                Text(state.chestOpened ? "Opened · a new one tomorrow"
                     : state.chestReady ? "All ticked off. Open it!" : "Tick off all three to open it")
                    .lineLimit(1)
                    .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            if state.chestOpened {
                Stamp(text: loc("Opened"), color: .grassDark, size: 44, angle: -10)
            } else {
                Button { withAnimation { state.openChest() } } label: { Text("Open") }
                    .buttonStyle(.chunky(.tomato, text: .white, radius: 14))
                    .disabled(!state.chestReady)
            }
        }
    }
}

struct QuestRow: View {
    @Environment(AppState.self) private var state
    let q: DailyQuest

    var body: some View {
        let done = state.isDone(q), claimed = state.isClaimed(q), missed = state.isMissed(q)
        let tint = Color(hexString: q.t.tint)
        HStack(spacing: 12) {
            ZStack {
                PaperShape(radius: 5, wobble: 0.8, seed: q.id.count)
                    .fill(done && !claimed ? Color.sun.opacity(0.35) : Color.clear)
                PaperShape(radius: 5, wobble: 0.8, seed: q.id.count)
                    .stroke(Color.ink.opacity(missed ? 0.25 : 0.55), lineWidth: 1.5)
                if claimed || done {
                    Image(systemName: "checkmark").font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(claimed ? Color.grassDark : Color.sunDark)
                        .rotationEffect(.degrees(-8)).offset(x: 2, y: -2)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(width: 26, height: 26)
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: q.t.icon).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
                    Text(q.t.title).font(.story(16, .semibold))
                        .strikethrough(claimed, color: Color.inkSoft.opacity(0.6))
                }
                if claimed {
                    Text("Collected · +\(q.t.reward) coins").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                } else if done {
                    Text("Done! Collect your coins").font(.game(12, .semibold)).foregroundStyle(Color.grassDark)
                } else if missed {
                    Text("Missed · \(q.detail)").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                } else {
                    Text(q.detail).font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                    HStack(spacing: 6) {
                        ProgressBar(value: Double(state.value(q)) / Double(max(1, q.target)), color: tint, height: 7)
                            .frame(maxWidth: 120)
                        Text("\(shortSteps(state.value(q)))/\(shortSteps(q.target))").font(.game(11, .semibold))
                            .foregroundStyle(Color.inkSoft).fixedSize()
                    }
                }
            }
            Spacer(minLength: 4)
            if claimed {
                Stamp(text: "+\(q.t.reward)", color: .tomato, size: 42)
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
            } else if done {
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { state.claim(q) } } label: {
                    HStack(spacing: 4) {
                        ArtView(id: "coin", size: 18, line: 1.4)
                        Text("Collect")
                    }
                }
                .buttonStyle(.chunky(.sun, radius: 12, padH: 10, padV: 7))
            } else {
                HStack(spacing: 3) {
                    ArtView(id: "coin", size: 16, line: 1.3)
                    Text("\(q.t.reward)").font(.game(13, .semibold))
                }
                .foregroundStyle(Color.inkSoft)
                .opacity(0.8)
            }
        }
        .foregroundStyle(Color.ink)
        .opacity(missed ? 0.6 : 1)
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
    /// Plus members can lock the sky; "auto" follows the time of day.
    @AppStorage("scenePhase") private var scenePhase = "auto"

    private enum Phase { case morning, day, sunset, night }

    private var pace: Double { state.motion.pace }

    private var movingLine: String? {
        switch state.motion.activity {
        case .walking: loc("Walking together! Keep going")
        case .running: loc("Run run run! I can keep up!")
        case .still: nil
        }
    }

    private var phase: Phase {
        if state.isPlus {
            switch scenePhase {
            case "morning": return .morning
            case "day": return .day
            case "sunset": return .sunset
            case "night": return .night
            default: break
            }
        }
        return switch state.hour {
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

    private func bird(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: s * 0.5))
            p.addQuadCurve(to: CGPoint(x: s, y: 0), control: CGPoint(x: s * 0.5, y: s * 0.55))
            p.addQuadCurve(to: CGPoint(x: s * 2, y: s * 0.5), control: CGPoint(x: s * 1.5, y: 0))
        }
        .stroke(Color.ink.opacity(0.28), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        .frame(width: s * 2, height: s * 0.6).offset(x: x, y: y)
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
                .frame(width: 54).offset(x: 135, y: -88)
            } else {
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Capsule().fill(Color.sun.opacity(0.6)).frame(width: 6, height: 18)
                            .offset(y: -44).rotationEffect(.degrees(Double(i) * 45))
                    }
                    Circle().sticker(phase == .sunset ? Color(hex: 0xFF8A5B) : .sun, 3).frame(width: 60)
                }
                .offset(x: 135, y: -86)
                .rotationEffect(.degrees(drift ? 8 : -8), anchor: .center)
            }

            ArtView(id: "deco_cloud", size: 90, line: 3).opacity(night ? 0.35 : 1)
                .offset(x: drift ? -60 : -140, y: -150)
            ArtView(id: "deco_cloud", size: 64, line: 3).opacity(night ? 0.3 : 0.9)
                .offset(x: drift ? 120 : 40, y: -70)
            if !night { bird(-120, -150, 9) }
            // A pale, hazy ridge far back for atmospheric depth.
            oval(50, 50, 100, 100).fill(farHill.lighter(0.16))
                .frame(width: 560, height: 200).offset(x: 10, y: 150)
            oval(50, 50, 100, 100).sticker(farHill.lighter(0.12), farHill.darker(0.05), 3)
                .frame(width: 360, height: 220).offset(x: -150, y: 120)
            oval(50, 50, 100, 100).sticker(farHill.lighter(0.12), farHill.darker(0.05), 3)
                .frame(width: 380, height: 240).offset(x: 170, y: 110)

            ArtView(id: "deco_tree", size: 110, line: 3).modifier(Drift(x: -140, y: 50, pace: pace, speed: 18))
            ArtView(id: "deco_lamp", size: 80, line: 3).modifier(Drift(x: 150, y: 50, pace: pace, speed: 18))
                .shadow(color: night ? Color.sun.opacity(0.8) : .clear, radius: 18)

            UPath { p, pt in
                p.move(to: pt(-5, 30))
                p.addQuadCurve(to: pt(105, 26), control: pt(50, -4))
                p.addLine(to: pt(105, 105)); p.addLine(to: pt(-5, 105)); p.closeSubpath()
            }
            .sticker(hill.lighter(0.08), hill.darker(0.04), 3)
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .bottom)

            UPath { p, pt in
                p.move(to: pt(42, 18)); p.addQuadCurve(to: pt(58, 18), control: pt(50, 14))
                p.addQuadCurve(to: pt(80, 100), control: pt(78, 60))
                p.addLine(to: pt(20, 100))
                p.addQuadCurve(to: pt(42, 18), control: pt(22, 60))
            }
            .sticker(night ? Color(hex: 0xC6B795) : Color(hex: 0xFBEBC6), night ? Color(hex: 0xB0A082) : Color(hex: 0xEFD3A0), 3)
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .bottom)

            ArtView(id: decor[0], size: 60, line: 3).modifier(Drift(x: 136, y: 150, pace: pace, speed: 34))
            ArtView(id: decor[1 % decor.count], size: 52, line: 3).modifier(Drift(x: -150, y: 152, pace: pace, speed: 34))

            TrailWalk(pace: pace) { d in
                ZStack {
                    ZStack {
                        Ellipse().fill(Color.ink.opacity(0.18)).frame(width: 110, height: 18).offset(y: 168)
                        if state.hasCompanion {
                            Ellipse().fill(Color.ink.opacity(0.14)).frame(width: 72, height: 12).offset(x: -82, y: 172)
                            CatView(outfit: state.companionOutfit, size: 96, mood: .happy, pace: pace)
                                .offset(x: -82, y: 118)
                        }
                        Button {
                            hop += 1
                            hearts += 1
                        } label: {
                            CatView(outfit: state.outfit, size: 150, mood: pace > 0 ? .happy : CatMood(state.mood), hop: hop, pace: pace)
                        }
                        .buttonStyle(.plain)
                        .offset(y: 86)
                        .sensoryFeedback(.impact(weight: .light), trigger: hop)
                    }
                    .scaleEffect(1 - 0.38 * d, anchor: UnitPoint(x: 0.5, y: 0.5 + 177 / 340))
                    .offset(y: -62 * d)

                    HeartBurst(trigger: hearts).offset(y: 10 - 70 * d)

                    SpeechBubble(text: movingLine ?? state.bubble).offset(x: 46 * d, y: -16 - 14 * d)
                }
            }

            topBar.frame(maxHeight: .infinity, alignment: .top)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(state.titleText.map { "\(state.petName) \(L($0))" } ?? state.petName).font(.story(18, .bold)).lineLimit(1)
                    Text("Lv \(state.level)").font(.game(11, .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.sun.opacity(0.7)))
                }
                Text("\(L(state.mood)) · day \(state.daysTogether) of our trek")
                    .font(.game(12, .medium)).foregroundStyle(Color.inkSoft).lineLimit(1)
            }
            .fixedSize()
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 9)
            .background(PaperShape(radius: 4, seed: 19).fill(Color.paper))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            .taped(.top, angle: 4, color: .bubble, width: 46)
            .rotationEffect(.degrees(-2.5))
            .foregroundStyle(Color.ink)
            .padding(.leading, 18).padding(.top, 104)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(spacing: 10) {
                SceneButton(symbol: "tshirt.fill", tint: .grape) { showCloset = true }
                SceneButton(symbol: "bubble.left.and.bubble.right.fill", tint: .sunDark) { showCoach = true }
                SceneButton(art: "fish", tint: state.fullness < 20 ? .tomato : .sky,
                            badge: "\(Int(state.fullness))%") { showFeed = true }
                    .overlay(alignment: .topTrailing) {
                        if state.forageReady > 0 {
                            Circle().fill(Color.tomato).frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.paper, lineWidth: 2)).offset(x: 2, y: -2)
                        }
                    }
            }
            .padding(.trailing, 16).padding(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: 440)
        .clipped()
        .onChange(of: state.coins) { old, new in if new > old { hop += 1 } }
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
                .font(.story(15, .semibold))
                .italic()
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(PaperShape(radius: 14, wobble: 1, seed: 23).fill(Color.paper))
                .overlay(PaperShape(radius: 14, wobble: 1, seed: 23).stroke(Color.ink.opacity(0.35), lineWidth: 1.2))
            Triangle().fill(Color.paper)
                .rotationEffect(.degrees(180))
                .frame(width: 16, height: 9)
        }
        .frame(maxWidth: 260)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    CatView(outfit: state.outfit, size: 72, mood: CatMood(state.mood))
                    VStack(alignment: .leading, spacing: 8) {
                        StoryHeading(text: loc("Snack time for \(state.petName)"), size: 22, color: .pumpkin)
                        ProgressBar(value: state.fullness / 100, color: state.fullness < 20 ? .tomato : .grass, height: 14)
                        Text("Tummy \(Int(state.fullness))% full · empties a little every hour").font(.game(12, .medium))
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                .padding(.top, 8)
                forageCard
                VStack(spacing: 0) {
                    ForEach(Array(state.foods.enumerated()), id: \.element.id) { i, c in
                        let have = state.owns(c)
                        if i > 0 { PencilRule() }
                        HStack(spacing: 12) {
                            ArtView(id: c.id, size: 44, line: 2.2)
                                .frame(width: 54, height: 54).background(SketchSquare())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.story(17, .bold))
                                Text(have > 0 ? loc("+\(c.food)% · \(have) in the cupboard") : loc("+\(c.food)% · none left"))
                                    .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                            }
                            Spacer()
                            if have > 0 {
                                Button(state.isFull ? loc("Full") : loc("Feed")) { withAnimation { state.feed(c) } }
                                    .buttonStyle(.chunky(.grass, text: .white, radius: 12))
                                    .disabled(state.isFull)
                            } else {
                                Button { state.buy(c) } label: {
                                    PriceTag(art: c.currency == .coin ? "coin" : "gem", text: "\(c.price)", color: Color.sun.opacity(0.35), angle: -5, string: false)
                                }
                                .buttonStyle(SquishStyle())
                                .disabled(state.balance(c.currency) < c.price)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                }
                .card(padding: 12, radius: 10)
            }
            .foregroundStyle(Color.ink)
            .padding(20)
        }
        .paperBackground()
        .presentationBackground(Color.cream)
    }

    private var forageCard: some View {
        let ready = state.forageReady
        let maxed = state.forageFound >= AppState.forageMax
        return HStack(spacing: 12) {
            ArtView(id: "basket", size: 44, line: 2.2)
                .rotationEffect(.degrees(ready > 0 ? -6 : 0))
                .animation(ready > 0 ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true) : .default, value: ready)
            VStack(alignment: .leading, spacing: 5) {
                Text("Snacks found on the trail").font(.story(16, .bold))
                if maxed && ready == 0 {
                    Text("All five found today. The bushes refill tomorrow.").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                } else {
                    ProgressBar(value: state.forageNextProgress, color: .sunDark, height: 8)
                    Text(loc("1 snack every \(AppState.forageSteps.formatted()) steps · \(state.forageFound)/\(AppState.forageMax) today"))
                        .font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
                }
            }
            Spacer(minLength: 4)
            Button { withAnimation(.spring) { state.collectForage() } } label: {
                Text(ready > 0 ? loc("Collect \(ready)") : loc("Collect"))
            }
            .buttonStyle(.chunky(.sun, padH: 12, padV: 8))
            .disabled(ready == 0)
        }
        .card(padding: 12, color: Color.chestBg)
        .taped(.top, angle: -3, color: .sky, width: 50)
    }
}

struct InboxView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if state.claimable > 0 {
                        row(art: "coin", loc("Walking coins"), loc("\(state.claimable * 10) unclaimed steps"), loc("+\(state.claimable)")) { state.claimSteps() }
                    }
                    ForEach(state.quests.filter { state.isDone($0) && !state.isClaimed($0) }) { q in
                        row(symbol: q.t.icon, tint: q.t.tint, q.t.title, loc("Daily quest"), loc("+\(q.t.reward)")) { state.claim(q) }
                    }
                    if state.forageReady > 0 {
                        row(art: "basket", loc("Snacks found on the trail"), loc("\(state.forageReady) waiting in the basket"), loc("Collect")) { state.collectForage() }
                    }
                    if !state.loginClaimedToday {
                        row(art: AppState.dailyRewards[state.loginNextDay - 1].art, loc("Daily rewards"), loc("Day \(state.loginNextDay) of 7"), loc("Claim")) { state.claimLogin() }
                    }
                    if state.expeditionDone, let def = state.expeditionDef {
                        row(symbol: def.icon, tint: def.tint, loc("Expedition"), def.name, loc("Open")) { state.finishExpedition() }
                    }
                    if state.passClaimable > 0 {
                        row(symbol: "flag.fill", tint: "8B7BC8", loc("Trail Pass"), loc("\(state.passClaimable) rewards ready"), loc("Claim all")) { state.claimAllPass() }
                    }
                    ForEach(state.content.sets.filter { state.setComplete($0) && !state.setClaimed($0) }) { s in
                        row(symbol: s.icon, tint: s.tint, s.name, loc("Set complete"), loc("Claim")) { state.claimSet(s) }
                    }
                    ForEach(state.duels.filter { state.duelReady($0) && !$0.claimed }) { d in
                        row(symbol: "flag.2.crossed.fill", tint: "E5707A", loc("Duel with \(d.friendName)"), loc("Results are in"), loc("Claim")) { state.claimDuel(d) }
                    }
                    if state.chestReady {
                        row(art: "chest", loc("Treasure box"), loc("All errands ticked off"), loc("+30 +1 gem")) { state.openChest() }
                    }
                    if let a = state.activeEvent {
                        ForEach(a.event.milestones.filter { state.canClaim(a, $0) }) { m in
                            row(art: m.item ?? a.event.tokenArt, a.event.name, loc("\(m.tokens) \(a.event.token)"), reward(m)) { state.claim(a, m) }
                        }
                    }
                    ForEach(state.content.landmarks.filter { state.isReached($0) && !state.isClaimed($0) }) { l in
                        row(symbol: l.icon, tint: l.tint, l.name, loc("Landmark reached"), reward(l.coins, l.gems)) { state.claim(l) }
                    }
                    ForEach(state.content.achievements.filter { state.isUnlocked($0) && !state.isClaimed($0) }) { a in
                        row(symbol: a.icon, tint: a.tint, a.title, a.detail, reward(a.coins, a.gems)) { state.claim(a) }
                    }
                    if state.inboxCount == 0 {
                        VStack(spacing: 10) {
                            ArtView(id: "chest", size: 80, line: 3)
                            Text("The mailbox is empty").font(.story(21, .bold))
                            Text("Go for a stroll. Post tends to arrive while you walk.").font(.game(14, .medium))
                                .foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .storyNavTitle(loc("Mailbox"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if state.inboxCount > 1 {
                    Button("Open all") { withAnimation { state.claimAll() } }.font(.story(15, .bold))
                }
            }
        }
        .presentationBackground(Color.cream)
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
                Text(title).font(.story(16, .bold))
                Text(detail).font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Button { withAnimation { action() } } label: { Text(reward) }
                .buttonStyle(PostageButtonStyle(color: Color(hexString: tint).opacity(0.45)))
        }
        .padding(.vertical, 4)
        .card(padding: 12, radius: 6)
        .overlay(alignment: .leading) {
            // Airmail stripes along the edge of each envelope.
            VStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    Rectangle().fill(i.isMultiple(of: 2) ? Color.tomato.opacity(0.55) : Color.sky.opacity(0.65))
                        .frame(width: 4, height: 7)
                }
            }
            .padding(.leading, 3)
            .accessibilityHidden(true)
        }
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
        .presentationBackground(Color.cream)
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
    @State private var showWallpapers = false
    @State private var showAdopt = false
    @AppStorage("scenePhase") private var scenePhase = "auto"
    @AppStorage("adaptiveGoal") private var adaptiveGoal = false

    private static let skies: [(String, String)] = [("auto", "Follow the day"), ("morning", "Morning"), ("day", "Daytime"), ("sunset", "Sunset"), ("night", "Night")]

    var body: some View {
        @Bindable var s = state
        NavigationStack {
            Form {
                Section {
                    Button { showPaywall = true } label: {
                        HStack {
                            WaxSeal(symbol: "crown.fill", color: .tomato, size: 36)
                            VStack(alignment: .leading) {
                                Text(state.isPlus ? "Meowtrek Plus" : "Join Meowtrek Plus").font(.story(17, .bold)).foregroundStyle(Color.ink)
                                Text(state.isPlus ? "Thank you for keeping the lights on" : "A cat coach, weekly letters, 1.5× coins").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
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
                    StorySectionHeader(text: loc("Your cat coach"), symbol: "sparkles")
                } footer: {
                    Text("Automatic uses Apple Intelligence on supported iPhones and falls back to the cloud coach.")
                }
                Section {
                    BackupSection()
                } header: {
                    StorySectionHeader(text: loc("iCloud copy"), symbol: "icloud")
                } footer: {
                    Text("Plus backs up your progress and treks to your private iCloud once a day. Meal photos stay on this iPhone.")
                }
                Section {
                    DevicesSection()
                } header: {
                    StorySectionHeader(text: loc("Where your steps come from"), symbol: "applewatch")
                }
                Section {
                    TextField("Name", text: $s.petName)
                    LabeledContent("Level", value: "\(state.level) · \(Int(state.levelProgress * 100))% to next")
                    LabeledContent("Together since", value: state.firstDay.formatted(date: .abbreviated, time: .omitted))
                    if state.hasCompanion {
                        HStack {
                            Text("Companion")
                            Spacer()
                            Text(state.companionName).foregroundStyle(Color.inkSoft)
                            Button(role: .destructive) { state.releaseCompanion() } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.inkSoft) }
                                .buttonStyle(.plain)
                        }
                    } else {
                        Button { if state.isPlus { showAdopt = true } else { showPaywall = true } } label: {
                            HStack {
                                Text("Adopt a friend").foregroundStyle(Color.ink)
                                Spacer()
                                if !state.isPlus { Tag(text: loc("Plus"), color: .sun, textColor: .ink) }
                                else { Image(systemName: "plus.circle.fill").foregroundStyle(Color.grass) }
                            }
                        }
                    }
                } header: {
                    StorySectionHeader(text: loc("About your cat"), symbol: "pawprint")
                } footer: {
                    Text("Plus lets a second cat move in and keep \(state.petName) company at home.")
                }
                Section {
                    if state.isPlus {
                        Picker("Home sky", selection: $scenePhase) {
                            ForEach(Self.skies, id: \.0) { Text(L($0.1)).tag($0.0) }
                        }
                    } else {
                        Button { showPaywall = true } label: {
                            HStack {
                                Text("Pick your sky").foregroundStyle(Color.ink)
                                Spacer()
                                Tag(text: loc("Plus"), color: .sun, textColor: .ink)
                            }
                        }
                    }
                } header: {
                    StorySectionHeader(text: loc("Home scene"), symbol: "sun.max")
                } footer: {
                    Text("Plus lets you lock your home scene to any time of day. Free follows the real time.")
                }
                Section {
                    GoalEditor()
                    if state.isPlus {
                        Toggle("Adaptive goal", isOn: $adaptiveGoal)
                            .onChange(of: adaptiveGoal) { state.applyAdaptiveGoal(force: true) }
                    } else {
                        Button { showPaywall = true } label: {
                            HStack {
                                Text("Adaptive goal").foregroundStyle(Color.ink)
                                Spacer()
                                Tag(text: loc("Plus"), color: .sun, textColor: .ink)
                            }
                        }
                    }
                } header: {
                    StorySectionHeader(text: loc("Daily goal"), symbol: "flag")
                } footer: {
                    Text("Adaptive goal retunes your target each week to match your recent pace.")
                }
                Section {
                    Toggle("Walk reminders", isOn: Binding(get: { state.remindersOn }, set: { on in
                        Task {
                            let ok = on ? await Notifier.requestAuth() : true
                            state.remindersOn = on && ok
                            if on && !ok { state.show(loc("Allow notifications in Settings")) }
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
                    StorySectionHeader(text: loc("Gentle nudges"), symbol: "bell")
                } footer: {
                    Text("A soft meow when you're short of your goal, and before an event wraps up.")
                }
                Section {
                    AppIconPicker()
                    Button { showWallpapers = true } label: {
                        Label("Wallpapers for Apple Watch & iPhone", systemImage: "photo.on.rectangle.angled")
                    }
                } header: {
                    StorySectionHeader(text: loc("Icon & wallpapers"), symbol: "paintbrush")
                }
                Section {
                    Toggle("Share anonymous usage and crash reports", isOn: Binding(get: { Telemetry.enabled }, set: { Telemetry.enabled = $0 }))
                    Picker("Distance", selection: $s.useMiles) {
                        Text("Kilometres").tag(false)
                        Text("Miles").tag(true)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    StorySectionHeader(text: loc("Units & privacy"), symbol: "ruler")
                }
                Section {
                    LabeledContent("Step source", value: state.steps.source == .health ? "Apple Health" : "Demo data")
                    LabeledContent("Live pedometer", value: state.steps.live ? "On" : "Off")
                    LabeledContent("Streak freezes", value: "\(state.streakFreezes)")
                    Button("Reconnect Apple Health") { Task { await state.steps.load(); state.refresh() } }
                } header: {
                    StorySectionHeader(text: loc("Step data"), symbol: "heart.text.square")
                } footer: {
                    Text("With no Health data or access, Meowtrek shows demo steps. Allow access in Settings › Health › Data Access.")
                }
                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                }
            }
            .fontDesign(.rounded)
            .scrollContentBackground(.hidden)
            .paperBackground()
            .storyNavTitle(loc("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.font(.story(15, .bold)) } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showWallpapers) { WallpapersView() }
            .sheet(isPresented: $showAdopt) { AdoptCompanionView().presentationDetents([.medium, .large]) }
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
        .presentationBackground(Color.cream)
    }
}

private struct SceneButton: View {
    var symbol: String? = nil
    var art: String? = nil
    let tint: Color
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Group {
                    if let art { ArtView(id: art, size: 24, line: 1.6) } else {
                        Image(systemName: symbol ?? "circle").font(.system(size: 18, weight: .bold)).foregroundStyle(tint)
                    }
                }
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.paper))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                if let badge {
                    Text(badge).font(.game(11, .bold)).monospacedDigit().foregroundStyle(tint == .tomato ? Color.tomato : Color.ink)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(Color.paper))
                }
            }
        }
        .buttonStyle(SquishStyle())
    }
}

struct GoalEditor: View {
    @Environment(AppState.self) private var state

    private var suggested: Int {
        let cal = Calendar.current
        let week = (1...7).map { state.steps.steps(on: cal.date(byAdding: .day, value: -$0, to: .now)!) }
        let avg = week.reduce(0, +) / 7
        return min(30000, max(1000, Int((Double(avg) * 1.05 / 250).rounded()) * 250))
    }

    var body: some View {
        @Bindable var s = state
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.goal.formatted()).font(.story(30, .bold)).contentTransition(.numericText(value: Double(state.goal)))
                Text("steps a day").font(.story(14, .regular)).italic().foregroundStyle(Color.inkSoft)
                Spacer()
                HStack(spacing: 6) {
                    RoundIconButton(symbol: "minus", size: 34) { set(state.goal - 250) }.disabled(state.goal <= AppState.goalMin)
                    RoundIconButton(symbol: "plus", size: 34) { set(state.goal + 250) }.disabled(state.goal >= AppState.goalMax)
                }
            }
            Slider(value: Binding(get: { Double(state.goal) }, set: { set(Int(($0 / 250).rounded()) * 250) }),
                   in: Double(AppState.goalMin)...Double(AppState.goalMax))
                .tint(.grass)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(loc("Suggested \(suggested.formatted())"), suggested)
                    ForEach([5000, 7500, 10000, 15000, 20000], id: \.self) { g in chip(g.formatted(), g) }
                }
                .padding(.vertical, 2)
            }
            Text("The suggestion is your usual day this week, plus a small stretch.")
                .font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: state.goal)
    }

    private func chip(_ title: String, _ g: Int) -> some View {
        Button(title) { set(g) }
            .buttonStyle(StoryChipStyle(on: state.goal == g))
            .lineLimit(1)
    }

    private func set(_ g: Int) {
        withAnimation(.snappy) { state.goal = min(AppState.goalMax, max(AppState.goalMin, g)) }
    }
}

/// Slides a scene prop backwards while the user is moving, wrapping around the scene width.
private struct Drift: ViewModifier {
    let x: CGFloat
    let y: CGFloat
    let pace: Double
    let speed: CGFloat

    func body(content: Content) -> some View {
        if pace > 0 {
            TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                let span: CGFloat = 560
                let dx = CGFloat(ctx.date.timeIntervalSinceReferenceDate) * speed * CGFloat(pace)
                let raw = (x + span / 2 - dx).truncatingRemainder(dividingBy: span)
                content.offset(x: (raw < 0 ? raw + span : raw) - span / 2, y: y)
            }
        } else {
            content.offset(x: x, y: y)
        }
    }
}

/// While moving, the cat trots up the path and back; d is 0 at the front of the scene and 1 at the far end.
private struct TrailWalk<C: View>: View {
    let pace: Double
    @ViewBuilder let content: (CGFloat) -> C

    var body: some View {
        if pace > 0 {
            TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate * (pace > 1.5 ? 0.55 : 0.32)
                content(CGFloat((1 - cos(t)) / 2) * 0.85)
            }
        } else {
            content(0)
        }
    }
}

/// Name and pick the fur for a Plus companion cat.
struct AdoptCompanionView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fur = AppState.companionFurs.first ?? "fur_snow"

    private let cols = [GridItem(.adaptive(minimum: 72), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    CatView(outfit: Catalog.item(fur).map { [.fur: $0] } ?? [:], size: 130, mood: .happy)
                        .frame(height: 150)
                    TextField(loc("Name your new friend"), text: $name)
                        .font(.story(18, .bold)).multilineTextAlignment(.center)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cream))
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(AppState.companionFurs, id: \.self) { f in
                            Button { fur = f } label: {
                                ArtView(id: f, size: 52)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(fur == f ? Color.grass.opacity(0.22) : Color.cream))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.grass, lineWidth: fur == f ? 2 : 0))
                            }
                            .buttonStyle(SquishStyle())
                        }
                    }
                    Button {
                        state.adoptCompanion(name: name, fur: fur)
                        dismiss()
                    } label: { Text("Welcome them home").frame(maxWidth: .infinity) }
                        .buttonStyle(.chunky(.grass, text: .white, radius: 16, padV: 14))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .navigationTitle(loc("Adopt a friend"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(loc("Close")) { dismiss() } } }
        }
    }
}
