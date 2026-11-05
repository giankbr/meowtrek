import SwiftUI
import UIKit

struct JourneyView: View {
    @Environment(AppState.self) private var state
    @State private var recording = false
    @State private var opened: Trek?

    var body: some View {
        let walked = state.journeySteps
        let landmarks = state.content.landmarks
        let nextIndex = landmarks.firstIndex { $0.steps > walked }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: loc("Journey")) {
                    PaperLabel(text: loc("Level \(state.level)"), color: .sun, angle: 3, size: 15).padding(.trailing, 4)
                }

                HStack(spacing: 14) {
                    CatView(outfit: state.outfit, size: 74, mood: .happy)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Our trail so far").font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft)
                        Text("\(walked.formatted()) steps").font(.story(28, .bold)).contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(state.daysTogether) days on the road together").font(.game(12, .semibold)).foregroundStyle(Color.inkSoft)
                        ProgressBar(value: state.levelProgress, color: .sun, height: 12).padding(.top, 2)
                        HStack(spacing: 4) {
                            Text("\((AppState.threshold(state.level + 1) - walked).formatted()) more to level \(state.level + 1), then a")
                            ArtView(id: "gem", size: 13, line: 1.2)
                        }
                        .font(.game(11, .semibold)).foregroundStyle(Color.inkSoft)
                    }
                }
                .card()
                .taped(.topLeading, angle: -8, color: .grape, x: 18)

                StorySection(loc("Right now"), subtitle: loc("What we're walking toward"), color: .grape)
                    .padding(.top, 6)
                ExpeditionCard()
                TrailPassCard()

                StorySection(title: loc("Trek log"), subtitle: loc("Walks, runs and hikes we traced together"), color: .grass) {
                    Button { recording = true } label: { Label("Record", systemImage: "location.north.circle.fill") }
                        .buttonStyle(.chunky(.grass, text: .white, radius: 18, padH: 12, padV: 7))
                }
                if state.treks.treks.isEmpty {
                    PencilNote(text: loc("Tap Record before your next walk and I'll sketch the route right here."))
                } else {
                    HStack(spacing: 10) {
                        statPill("\(state.treks.treks.count)", loc("treks"))
                        statPill(state.distanceText(state.treks.totalKm * 1000), loc("all told"))
                        statPill(String(format: "%.1f km", state.treks.longest(.run)), loc("longest run"))
                    }
                    ForEach(state.treks.treks.prefix(5)) { t in
                        Button { opened = t } label: { TrekRow(trek: t) }.buttonStyle(SquishStyle())
                    }
                }

                StorySection(loc("Trail map"), subtitle: loc("Every landmark is a stop on our walk"), color: .sky)
                    .padding(.top, 6)
                VStack(spacing: 0) {
                    ForEach(Array(landmarks.enumerated()), id: \.element.id) { i, l in
                        landmarkRow(l, index: i, walked: walked, prev: i == 0 ? 0 : landmarks[i - 1].steps,
                                    isNext: i == nextIndex)
                        if i < landmarks.count - 1 {
                            trail(from: i, reached: state.isReached(landmarks[i + 1]))
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis").foregroundStyle(Color.inkSoft)
                        Text("More of the map appears as we walk").font(.story(12, .regular)).italic().foregroundStyle(Color.inkSoft)
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 12).padding(.vertical, 18)
                .background(MapPaper().clipShape(PaperShape(radius: 18, wobble: 1.6, seed: 31)))
                .overlay(PaperShape(radius: 18, wobble: 1.6, seed: 31).stroke(Color.choco.opacity(0.18), lineWidth: 1.2))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                .taped(.top, angle: 3, color: .sky, x: -90)
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $recording) { TrekRecordView() }
        .sheet(item: $opened) { TrekSummaryView(trek: $0) }
    }

    private func statPill(_ v: String, _ l: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(.story(17, .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 10, radius: 16)
    }

    private func trail(from i: Int, reached: Bool) -> some View {
        let flip = i.isMultiple(of: 2)
        return UPath { p, pt in
            p.move(to: pt(flip ? 16 : 84, 0))
            p.addCurve(to: pt(flip ? 84 : 16, 100), control1: pt(flip ? 22 : 78, 75), control2: pt(flip ? 70 : 30, 20))
        }
        .stroke(reached ? Color.tomato.opacity(0.75) : Color.choco.opacity(0.3),
                style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [7, 6]))
        .frame(height: 44)
    }

    private func landmarkRow(_ l: Landmark, index: Int, walked: Int, prev: Int, isNext: Bool) -> some View {
        let reached = state.isReached(l)
        let claimed = state.isClaimed(l)
        let left = index.isMultiple(of: 2)
        let node = ZStack {
            InkRing(color: reached ? .tomato : .choco, seed: index + 2).frame(width: 74, height: 74)
            GameIcon(symbol: l.icon, tint: Color(hexString: l.tint), size: 58, muted: !reached)
            if isNext {
                CatView(outfit: state.outfit, size: 34, mood: .happy).offset(x: 26, y: -30)
            }
        }
        let info = VStack(alignment: left ? .leading : .trailing, spacing: 4) {
            if isNext { PaperLabel(text: loc("Next stop"), color: .sun, angle: left ? -3 : 3, size: 11) }
            Text(l.name).font(.story(18, .bold))
            HStack(spacing: 4) {
                Text(shortSteps(l.steps)).font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                ArtView(id: "coin", size: 14, line: 1.2)
                Text("\(l.coins)").font(.game(12, .bold))
                if l.gems > 0 {
                    ArtView(id: "gem", size: 14, line: 1.2)
                    Text("\(l.gems)").font(.game(12, .bold))
                }
            }
            if !reached && walked > prev {
                ProgressBar(value: Double(walked - prev) / Double(l.steps - prev), color: Color(hexString: l.tint), height: 9)
                    .frame(width: 130)
            }
            if reached && !claimed {
                Button("Collect") { withAnimation { state.claim(l) } }.buttonStyle(.chunky(.sun, padH: 12, padV: 5))
            }
        }
        .card(padding: 12, color: reached ? .paper : Color.paper.opacity(0.6))
        .overlay(alignment: left ? .topTrailing : .topLeading) {
            if claimed { Stamp(text: loc("Visited"), color: .tomato, size: 50, angle: left ? 12 : -12).offset(x: left ? 14 : -14, y: -14) }
        }
        return HStack(spacing: 12) {
            if left { node; info; Spacer(minLength: 0) } else { Spacer(minLength: 0); info; node }
        }
    }
}

struct SocialView: View {
    @Environment(AppState.self) private var state
    @State private var adding = false
    @State private var code = ""
    @State private var challenging: Friend?

    var body: some View {
        let me = state.myCard
        let board = (state.friends + [me]).sorted { $0.week > $1.week }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenHeader(title: loc("Walking pals")) { EmptyView() }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your pal card").font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft)
                    HStack(spacing: 12) {
                        CatView(outfit: state.outfit, size: 66, mood: .happy)
                            .padding(6)
                            .background(Color.cream)
                            .padding(.bottom, 10)
                            .background(Color.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                            .rotationEffect(.degrees(-4))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(state.petName).font(.story(24, .bold))
                            HStack(spacing: 6) {
                                PaperLabel(text: loc("\(shortSteps(me.week)) this week"), color: .sky, angle: -2, size: 11)
                                PaperLabel(text: loc("\(me.streak)-day streak"), color: .pumpkin, angle: 2, size: 11)
                            }
                        }
                    }
                    InkRule()
                    HStack(spacing: 10) {
                        ShareLink(item: state.inviteURL,
                                  message: Text("Come walk with \(state.petName) on Meowtrek. Tap to add me.")) {
                            Label("Send my card", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(.chunky(.grass, text: .white))
                        Button { adding = true } label: { Label("Add a pal", systemImage: "person.badge.plus") }
                            .buttonStyle(.chunky(.paper))
                    }
                    Text("Pals swap card links. Open theirs to add them or catch up on their steps.")
                        .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
                .taped(.topTrailing, angle: 6, color: .grape, x: -24)

                DuelsSection()

                StorySection(loc("This week's ribbons"), subtitle: loc("Steps over the last seven days"), color: .tomato)
                if state.friends.isEmpty {
                    PencilNote(text: loc("No pals here yet. Send your card and the first one gets a ribbon spot next to \(state.petName)."),
                               symbol: "person.2")
                }
                VStack(spacing: 0) {
                    ForEach(Array(board.enumerated()), id: \.element.id) { i, f in
                        friendRow(f, rank: i + 1, isMe: f.id == me.id)
                            .contextMenu {
                                if f.id != me.id {
                                    Button("Remove", role: .destructive) { state.removeFriend(f) }
                                }
                            }
                        if i < board.count - 1 { InkRule().padding(.horizontal, 8) }
                    }
                }
                .card(padding: 8)
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $challenging) { ChallengeSheet(friend: $0) }
        .alert("Add a pal", isPresented: $adding) {
            TextField("Paste their card link", text: $code)
            Button("Paste from clipboard") {
                if let s = UIPasteboard.general.string, !state.addFriend(from: s) { state.show(loc("No pal card on the clipboard")) }
            }
            Button("Add") {
                if !state.addFriend(from: code) { state.show(loc("That link didn't work")) }
                code = ""
            }
            Button("Cancel", role: .cancel) { code = "" }
        } message: {
            Text("Ask your pal to send their Meowtrek card, then paste the link here.")
        }
    }

    private func friendRow(_ f: Friend, rank: Int, isMe: Bool) -> some View {
        var outfit: [Slot: Item] = [:]
        outfit[.fur] = Catalog.item(f.fur)
        if let h = f.hat { outfit[.hat] = Catalog.item(h) }
        return HStack(spacing: 10) {
            Rosette(rank: rank)
            CatView(outfit: outfit, size: 44, animated: false)
                .frame(width: 50, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "\(f.name) (you)" : f.title.map { "\(f.name) \(L($0))" } ?? f.name).font(.story(16, .bold)).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.pumpkin)
                    Text("\(f.streak)")
                    if !isMe { Text("· \(f.updated.formatted(.relative(presentation: .named)))") }
                }
                .font(.game(12, .semibold)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Text(shortSteps(f.week)).font(.story(19, .bold))
            if !isMe {
                RoundIconButton(symbol: "flag.2.crossed.fill", tint: .tomato, size: 34) { challenging = f }
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 8)
        .background {
            if isMe { PaperShape(radius: 10, wobble: 0.8, seed: 5).fill(Color.grassLight.opacity(0.55)) }
        }
    }
}

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var page = 0
    @State private var name = "Miso"
    @State private var fur = "fur_ginger"
    @State private var goal = 8000
    @State private var hop = 0
    @State private var backup: CloudBackup.Info?
    @State private var restoring = false

    private let starters = ["fur_ginger", "fur_snow", "fur_smoke", "fur_cocoa"]
    private let presets = [5000, 8000, 10000, 12000]
    private let chapters = [loc("A cat at the door"), loc("A name and a coat"), loc("How far we'll go")]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                PaperLabel(text: String(format: loc("Chapter %lld"), page + 1), color: .sun)
                Spacer()
                Text(chapters[page]).font(.story(14, .medium)).italic().foregroundStyle(Color.inkSoft)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            stage

            Group {
                switch page {
                case 0: welcome
                case 1: makeItYours
                default: dailyGoal
                }
            }
            .padding(.horizontal, 26)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(page)

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                ForEach(0..<3) { i in
                    Text("\(i + 1)")
                        .font(.story(i == page ? 17 : 14, i == page ? .bold : .regular))
                        .foregroundStyle(i == page ? Color.ink : Color.inkSoft.opacity(0.6))
                        .background(alignment: .bottom) {
                            if i == page { Squiggle().stroke(Color.sun, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).frame(width: 18, height: 4).offset(y: 5) }
                        }
                }
            }
            Button {
                if page < 2 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { page += 1 }
                    hop += 1
                } else {
                    state.finishOnboarding(name: name, fur: fur, goal: goal)
                    Task { await state.steps.load(); state.refresh() }
                }
            } label: {
                Text(page < 2 ? "Turn the page" : "Let's go for a walk").font(.story(19, .bold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.chunky(.grass, text: .white, radius: 18, padH: 20, padV: 15))
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .task { backup = await CloudBackup.latest() }
    }

    private var stage: some View {
        ZStack {
            Circle().fill(Color.sun.opacity(0.28)).frame(width: 150).offset(x: 70, y: -40)
            Circle().fill(Color.grassLight.opacity(0.6)).frame(width: 190).offset(x: -60, y: 30)
            Ellipse().fill(Color.ink.opacity(0.12)).frame(width: 130, height: 20).offset(y: 92)
            CatView(outfit: [.fur: Catalog.item(fur)!], size: 165, mood: page == 2 ? .happy : .normal, hop: hop)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .clipped()
        .background(PaperShape(radius: 18, seed: 5).fill(Color.paper))
        .overlay(alignment: .bottom) { TornEdge(seed: 9).fill(Color.cream).frame(height: 12) }
        .clipShape(PaperShape(radius: 18, seed: 5))
        .taped(.top, angle: -5, color: .bubble)
        .padding(.horizontal, 22)
        .contentShape(Rectangle())
        .onTapGesture { hop += 1 }
    }

    private var welcome: some View {
        VStack(spacing: 12) {
            (Text("Meow").foregroundStyle(Color.ink) + Text("trek").foregroundStyle(Color.grassDark))
                .font(.story(44, .heavy))
            Text("Someone's been waiting for you").font(.story(21, .semibold)).multilineTextAlignment(.center)
            Text("Each step you take, they take too. Together you'll earn coins, try on hats and fill a little journal of the places you wander.")
                .font(.game(15, .medium)).multilineTextAlignment(.center).foregroundStyle(Color.inkSoft)
            if let backup {
                Button {
                    restoring = true
                    Task {
                        do {
                            try await CloudBackup.restore(state)
                            state.show(loc("Restored from iCloud"), art: "deco_cloud")
                            await state.steps.load()
                            state.refresh()
                        } catch { state.show(error.localizedDescription) }
                        restoring = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if restoring { ProgressView() } else { Image(systemName: "icloud.and.arrow.down") }
                        Text("Restore backup from \(backup.savedAt.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .buttonStyle(StoryChipStyle(on: false))
                .disabled(restoring)
                .padding(.top, 4)
            }
        }
    }

    private var makeItYours: some View {
        VStack(alignment: .leading, spacing: 16) {
            StoryHeading(text: loc("What shall we call them?"), size: 23)
            VStack(spacing: 2) {
                TextField("e.g. Miso", text: $name)
                    .font(.story(26, .bold))
                    .multilineTextAlignment(.center)
                    .submitLabel(.done)
                PencilRule().frame(height: 4)
            }
            .padding(.horizontal, 30)
            Text("And their coat").font(.story(15, .semibold)).foregroundStyle(Color.inkSoft)
            HStack(spacing: 10) {
                ForEach(starters, id: \.self) { id in
                    let item = Catalog.item(id)
                    let on = fur == id
                    Button {
                        withAnimation(.spring) { fur = id }
                        hop += 1
                    } label: {
                        VStack(spacing: 4) {
                            if let item { ItemArt(item: item, size: 38) }
                            Text(item?.name ?? "").font(.story(12, on ? .bold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(SketchSquare(on: on))
                        .overlay(alignment: .topTrailing) {
                            if on { Stamp(text: loc("Picked"), color: .grassDark, size: 30).offset(x: 8, y: -10).transition(.scale(scale: 0.6).combined(with: .opacity)) }
                        }
                    }
                    .buttonStyle(SquishStyle())
                }
            }
            Text("More coats wait in the shop, and you can rename them any time.")
                .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
        }
    }

    private var dailyGoal: some View {
        VStack(spacing: 12) {
            StoryHeading(text: loc("How far shall we walk each day?"), size: 21)
            HStack(spacing: 18) {
                Button { withAnimation(.snappy) { goal = max(2000, goal - 500) } } label: { Image(systemName: "minus").frame(width: 20, height: 20) }
                    .buttonStyle(StoryChipStyle(on: false))
                Text(goal.formatted()).font(.story(50, .heavy)).contentTransition(.numericText()).frame(minWidth: 150)
                Button { withAnimation(.snappy) { goal = min(AppState.goalMax, goal + 500) } } label: { Image(systemName: "plus").frame(width: 20, height: 20) }
                    .buttonStyle(StoryChipStyle(on: false))
            }
            Text("steps a day").font(.story(15, .medium)).italic().foregroundStyle(Color.inkSoft)
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { p in
                    Button(p.formatted()) { withAnimation(.snappy) { goal = p } }
                        .buttonStyle(StoryChipStyle(on: goal == p))
                }
            }
            Text("Steps come from Apple Health. Start gentle; you can stretch it later.")
                .font(.game(12, .medium)).multilineTextAlignment(.center).foregroundStyle(Color.inkSoft)
        }
    }
}
