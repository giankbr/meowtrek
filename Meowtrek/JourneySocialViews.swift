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
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: loc("Journey")) {
                    Tag(text: loc("Lv \(state.level)"), color: .sun, textColor: .ink).scaleEffect(1.3).padding(.trailing, 8)
                }

                HStack(spacing: 14) {
                    CatView(outfit: state.outfit, size: 74, mood: .happy)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(walked.formatted()) steps").font(.game(26, .black)).contentTransition(.numericText())
                        Text("together in \(state.daysTogether) days").font(.game(13, .bold)).foregroundStyle(Color.inkSoft)
                        ProgressBar(value: state.levelProgress, color: .sun, height: 14)
                        HStack(spacing: 4) {
                            Text("\((AppState.threshold(state.level + 1) - walked).formatted()) to Lv \(state.level + 1) ·")
                            ArtView(id: "gem", size: 14, line: 1.2)
                            Text("+1")
                        }
                        .font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                    }
                }
                .card()

                HStack {
                    Text("Treks").font(.game(22, .bold))
                    Spacer()
                    Button { recording = true } label: { Label("Record", systemImage: "location.north.circle.fill") }
                        .buttonStyle(.chunky(.grass, text: .white, radius: 18, padH: 12, padV: 7))
                }
                if state.treks.treks.isEmpty {
                    Text("Record a walk, run or hike to see your routes here.")
                        .font(.game(13, .medium)).foregroundStyle(Color.inkSoft)
                } else {
                    HStack {
                        statPill("\(state.treks.treks.count)", loc("treks"))
                        statPill(state.distanceText(state.treks.totalKm * 1000), loc("total"))
                        statPill(String(format: "%.1f km", state.treks.longest(.run)), loc("longest run"))
                    }
                    ForEach(state.treks.treks.prefix(5)) { t in
                        Button { opened = t } label: { TrekRow(trek: t) }.buttonStyle(SquishStyle())
                    }
                }

                Text("Landmarks").font(.game(22, .bold)).padding(.top, 6)
                VStack(spacing: 0) {
                    ForEach(Array(landmarks.enumerated()), id: \.element.id) { i, l in
                        landmarkRow(l, index: i, walked: walked, prev: i == 0 ? 0 : landmarks[i - 1].steps,
                                    isNext: i == nextIndex)
                        if i < landmarks.count - 1 {
                            trail(from: i, reached: state.isReached(landmarks[i + 1]))
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .background(Color.cream)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $recording) { TrekRecordView() }
        .sheet(item: $opened) { TrekSummaryView(trek: $0) }
    }

    private func statPill(_ v: String, _ l: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(.game(16, .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 10, radius: 16)
    }

    private func trail(from i: Int, reached: Bool) -> some View {
        let flip = i.isMultiple(of: 2)
        return UPath { p, pt in
            p.move(to: pt(flip ? 18 : 82, 0))
            p.addCurve(to: pt(flip ? 82 : 18, 100), control1: pt(flip ? 18 : 82, 70), control2: pt(flip ? 82 : 18, 30))
        }
        .stroke(reached ? Color.grassDark : Color.inkSoft.opacity(0.45),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 11]))
        .frame(height: 44)
    }

    private func landmarkRow(_ l: Landmark, index: Int, walked: Int, prev: Int, isNext: Bool) -> some View {
        let reached = state.isReached(l)
        let claimed = state.isClaimed(l)
        let node = ZStack {
            GameIcon(symbol: l.icon, tint: Color(hexString: l.tint), size: 62, muted: !reached)
            if isNext {
                CatView(outfit: state.outfit, size: 34, mood: .happy).offset(x: 26, y: -30)
            }
        }
        let info = VStack(alignment: index.isMultiple(of: 2) ? .leading : .trailing, spacing: 4) {
            Text(l.name).font(.game(17, .black))
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
                ProgressBar(value: Double(walked - prev) / Double(l.steps - prev), color: Color(hexString: l.tint), height: 10)
                    .frame(width: 130)
            }
            if claimed {
                Tag(text: loc("Visited"), color: .grass)
            } else if reached {
                Button("Claim") { withAnimation { state.claim(l) } }.buttonStyle(.chunky(.sun, padH: 12, padV: 5))
            }
        }
        .card(padding: 12, color: reached ? .paper : Color(hex: 0xF6EFE1))
        return HStack(spacing: 12) {
            if index.isMultiple(of: 2) { node; info; Spacer(minLength: 0) } else { Spacer(minLength: 0); info; node }
        }
    }
}

struct SocialView: View {
    @Environment(AppState.self) private var state
    @State private var adding = false
    @State private var code = ""

    var body: some View {
        let me = state.myCard
        let board = (state.friends + [me]).sorted { $0.week > $1.week }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: loc("Social")) { EmptyView() }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CatView(outfit: state.outfit, size: 66, mood: .happy)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.petName).font(.game(22, .black))
                            HStack(spacing: 6) {
                                Tag(text: loc("\(shortSteps(me.week)) this week"), color: .sky)
                                Tag(text: loc("\(me.streak) day streak"), color: .pumpkin)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        ShareLink(item: state.inviteURL,
                                  message: Text("Walk with \(state.petName) on Meowtrek! Tap to add me.")) {
                            Label("Share card", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.chunky(.grass, text: .white))
                        Button { adding = true } label: { Label("Add friend", systemImage: "person.badge.plus") }
                            .buttonStyle(.chunky(.paper))
                    }
                    Text("Friends trade card links. Open theirs to add or refresh them.")
                        .font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                Text("Leaderboard · 7 days").font(.game(20, .black))
                if state.friends.isEmpty {
                    Text("No friends yet. Share your card to start a pack!")
                        .font(.game(14, .bold)).foregroundStyle(Color.inkSoft)
                }
                ForEach(Array(board.enumerated()), id: \.element.id) { i, f in
                    friendRow(f, rank: i + 1, isMe: f.id == me.id)
                        .contextMenu {
                            if f.id != me.id {
                                Button("Remove", role: .destructive) { state.removeFriend(f) }
                            }
                        }
                }
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .background(Color.cream)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Add friend", isPresented: $adding) {
            TextField("Paste their card link", text: $code)
            Button("Paste from clipboard") {
                if let s = UIPasteboard.general.string, !state.addFriend(from: s) { state.show(loc("No friend card on the clipboard")) }
            }
            Button("Add") {
                if !state.addFriend(from: code) { state.show(loc("That code didn't work")) }
                code = ""
            }
            Button("Cancel", role: .cancel) { code = "" }
        } message: {
            Text("Ask your friend to share their Meowtrek card, then paste the link here.")
        }
    }

    private func friendRow(_ f: Friend, rank: Int, isMe: Bool) -> some View {
        var outfit: [Slot: Item] = [:]
        outfit[.fur] = Catalog.item(f.fur)
        if let h = f.hat { outfit[.hat] = Catalog.item(h) }
        let medal: Color = rank == 1 ? .sun : rank == 2 ? Color(hex: 0xD5DCE6) : rank == 3 ? Color(hex: 0xE3A16B) : .paper
        return HStack(spacing: 12) {
            Text("\(rank)").font(.game(16, .black))
                .frame(width: 32, height: 32)
                .background(Circle().fill(medal)).overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            CatView(outfit: outfit, size: 44, animated: false)
                .frame(width: 50, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "\(f.name) (you)" : f.name).font(.game(16, .black))
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Color.pumpkin)
                    Text("\(f.streak)")
                    if !isMe { Text("· \(f.updated.formatted(.relative(presentation: .named)))") }
                }
                .font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Text(shortSteps(f.week)).font(.game(18, .black))
        }
        .card(padding: 10, color: isMe ? .grassLight : .paper)
    }
}

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var page = 0
    @State private var name = "Gohan"
    @State private var fur = "fur_ginger"
    @State private var goal = 8000
    @State private var hop = 0

    private let starters = ["fur_ginger", "fur_snow", "fur_smoke", "fur_cocoa"]

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 10)
            ZStack {
                Ellipse().sticker(.grassLight, 3).frame(width: 200, height: 40).offset(y: 96)
                CatView(outfit: [.fur: Catalog.item(fur)!], size: 170, mood: page == 2 ? .happy : .normal, hop: hop)
            }
            .onTapGesture { hop += 1 }
            Group {
                switch page {
                case 0:
                    VStack(spacing: 10) {
                        (Text("Meow").foregroundStyle(Color.ink) + Text("trek").foregroundStyle(Color.grassDark))
                            .font(.game(46, .black))
                        Text("Meet your walking buddy").font(.game(22, .black))
                        Text("Every step you take, your cat walks too. Earn coins, dress them up and explore together.")
                            .font(.game(15, .bold)).multilineTextAlignment(.center).foregroundStyle(Color.inkSoft)
                    }
                case 1:
                    VStack(spacing: 14) {
                        Text("Make it yours").font(.game(26, .black))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your cat's name").font(.game(13, .black)).foregroundStyle(Color.inkSoft)
                            TextField("e.g. Gohan", text: $name)
                                .font(.game(20, .black))
                                .multilineTextAlignment(.center)
                                .padding(12)
                                .card(padding: 0, radius: 16)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fur color").font(.game(13, .black)).foregroundStyle(Color.inkSoft)
                            HStack(spacing: 10) {
                                ForEach(starters, id: \.self) { id in
                                    let item = Catalog.item(id)
                                    let on = fur == id
                                    Button {
                                        withAnimation(.spring) { fur = id }
                                        hop += 1
                                    } label: {
                                        VStack(spacing: 4) {
                                            if let item { ItemArt(item: item, size: 40) }
                                            Text(item?.name ?? "").font(.game(12, .black))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .card(padding: 0, color: on ? .sun : .paper, radius: 16)
                                    }
                                    .buttonStyle(SquishStyle())
                                }
                            }
                        }
                        Text("You can rename them and unlock more colors later.")
                            .font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                    }
                default:
                    VStack(spacing: 14) {
                        Text("Daily goal").font(.game(26, .black))
                        Text("\(goal.formatted())").font(.game(52, .black)).contentTransition(.numericText())
                        Text("steps a day").font(.game(15, .bold)).foregroundStyle(Color.inkSoft)
                        HStack(spacing: 16) {
                            Button { withAnimation { goal = max(2000, goal - 500) } } label: { Image(systemName: "minus") }
                                .buttonStyle(.chunky(.paper, radius: 20, padH: 18, padV: 12))
                            Button { withAnimation { goal = min(30000, goal + 500) } } label: { Image(systemName: "plus") }
                                .buttonStyle(.chunky(.paper, radius: 20, padH: 18, padV: 12))
                        }
                        Text("Meowtrek reads steps from Apple Health. You can change this later.")
                            .font(.game(12, .bold)).multilineTextAlignment(.center).foregroundStyle(Color.inkSoft)
                    }
                }
            }
            .padding(.horizontal, 28)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(page)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Capsule().fill(i == page ? Color.grass : Color.paper)
                        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                        .frame(width: i == page ? 26 : 12, height: 12)
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
                Text(page < 2 ? "Continue" : "Start walking!").font(.game(19, .black)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.chunky(.grass, text: .white, radius: 22, padH: 20, padV: 15))
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: 0xD8F1FF), Color.cream], startPoint: .top, endPoint: .bottom))
    }
}
