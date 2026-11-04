import SwiftUI
import UIKit

struct JourneyView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let walked = state.journeySteps
        let landmarks = state.content.landmarks
        let next = landmarks.first { $0.steps > walked }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(walked.formatted()) steps").font(.system(size: 30, weight: .bold))
                        Spacer()
                        Text("Lv \(state.level)").font(.headline)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.honey, in: Capsule())
                    }
                    Text("walked together in \(state.daysTogether) days").font(.subheadline).foregroundStyle(Color.inkSoft)
                    ProgressBar(value: state.levelProgress)
                    Text("\((AppState.threshold(state.level + 1) - walked).formatted()) steps to level \(state.level + 1) · +1 💎")
                        .font(.caption).foregroundStyle(Color.inkSoft)
                    if let next {
                        Text("Next stop: \(next.emoji) \(next.name) in \((next.steps - walked).formatted()) steps")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.leafDark)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                VStack(spacing: 0) {
                    ForEach(Array(landmarks.enumerated()), id: \.element.id) { i, l in
                        landmarkRow(l, index: i, walked: walked, prev: i == 0 ? 0 : landmarks[i - 1].steps,
                                    last: i == landmarks.count - 1)
                    }
                }
                .card()
            }
            .padding(16)
        }
        .foregroundStyle(Color.ink)
        .background(Color.cream)
        .navigationTitle("Journey")
    }

    private func landmarkRow(_ l: Landmark, index: Int, walked: Int, prev: Int, last: Bool) -> some View {
        let reached = state.isReached(l)
        let claimed = state.isClaimed(l)
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(l.emoji).font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(reached ? Color.leafLight : .white, in: Circle())
                    .overlay(Circle().stroke(reached ? Color.leaf : .black.opacity(0.08), lineWidth: 2))
                    .grayscale(reached ? 0 : 1)
                if !last {
                    Rectangle().fill(reached ? Color.leaf : Color.leafLight.opacity(0.5))
                        .frame(width: 3, height: 34)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(l.name).font(.headline)
                Text("\(l.steps.formatted()) steps · \(l.coins) 🪙\(l.gems > 0 ? " \(l.gems) 💎" : "")")
                    .font(.caption).foregroundStyle(Color.inkSoft)
                if !reached && walked > prev {
                    ProgressBar(value: Double(walked - prev) / Double(l.steps - prev), height: 6)
                }
            }
            .padding(.top, 8)
            Spacer()
            if claimed {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.leaf).padding(.top, 14)
            } else if reached {
                Button("Claim") { withAnimation { state.claim(l) } }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderedProminent).tint(.honey).foregroundStyle(Color.night)
                    .padding(.top, 10)
            }
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

        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        CatView(outfit: state.outfit, size: 54).frame(width: 60, height: 68)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.petName).font(.headline)
                            Text("\(me.week.formatted()) steps this week · 🔥 \(me.streak)")
                                .font(.caption).foregroundStyle(Color.inkSoft)
                        }
                    }
                    HStack {
                        ShareLink(item: state.inviteURL,
                                  message: Text("Walk with \(state.petName) on Meowtrek! Tap to add me.")) {
                            Label("Share my card", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent).tint(.leaf)
                        Button { adding = true } label: { Label("Add friend", systemImage: "person.badge.plus") }
                            .buttonStyle(.bordered).tint(.leafDark)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Friends share a card link. Open theirs to add or refresh them; share yours again to update your stats.")
            }

            Section("Last 7 days") {
                if state.friends.isEmpty {
                    Text("No friends yet. Share your card to start a pack.")
                        .font(.subheadline).foregroundStyle(Color.inkSoft)
                }
                ForEach(Array(board.enumerated()), id: \.element.id) { i, f in
                    friendRow(f, rank: i + 1, isMe: f.id == me.id)
                        .swipeActions {
                            if f.id != me.id {
                                Button("Remove", role: .destructive) { state.removeFriend(f) }
                            }
                        }
                }
            }
        }
        .foregroundStyle(Color.ink)
        .scrollContentBackground(.hidden)
        .background(Color.cream)
        .navigationTitle("Social")
        .alert("Add friend", isPresented: $adding) {
            TextField("Paste their card link", text: $code)
            Button("Paste from clipboard") {
                if let s = UIPasteboard.general.string, !state.addFriend(from: s) { state.show("No friend card on the clipboard") }
            }
            Button("Add") {
                if !state.addFriend(from: code) { state.show("That code didn't work") }
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
        return HStack(spacing: 12) {
            Text(rank == 1 ? "👑" : "\(rank)").font(.headline).foregroundStyle(Color.inkSoft).frame(width: 24)
            CatView(outfit: outfit, size: 38).frame(width: 44, height: 48)
                .background(Color.cream, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(isMe ? "\(f.name) (you)" : f.name).font(.headline)
                Text("\(f.week.formatted()) steps · 🔥 \(f.streak)").font(.caption).foregroundStyle(Color.inkSoft)
                if !isMe {
                    Text("updated \(f.updated.formatted(.relative(presentation: .named)))")
                        .font(.caption2).foregroundStyle(Color.inkSoft)
                }
            }
            Spacer()
        }
        .listRowBackground(isMe ? Color.leafLight.opacity(0.4) : Color.white)
    }
}

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var page = 0
    @State private var name = "Gohan"
    @State private var fur = "fur_ginger"
    @State private var goal = 8000

    private let starters = ["fur_ginger", "fur_snow", "fur_smoke", "fur_cocoa"]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            CatView(outfit: [.fur: Catalog.item(fur)!], size: 170)
            Group {
                switch page {
                case 0:
                    VStack(spacing: 10) {
                        (Text("Meow").foregroundStyle(Color.ink) + Text("trek").foregroundStyle(Color.leafDark))
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                        Text("Meet your walking buddy").font(.title2.weight(.bold))
                        Text("Every step you take, your cat walks too. Earn coins, dress them up and explore together.")
                            .multilineTextAlignment(.center).foregroundStyle(Color.inkSoft)
                    }
                case 1:
                    VStack(spacing: 14) {
                        Text("Name & fur").font(.title2.weight(.bold))
                        TextField("Name", text: $name)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        HStack(spacing: 14) {
                            ForEach(starters, id: \.self) { id in
                                Button { withAnimation(.spring) { fur = id } } label: {
                                    Circle().fill(Color(hex: Catalog.item(id)?.hex ?? 0))
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().stroke(fur == id ? Color.leafDark : .clear, lineWidth: 3).padding(-4))
                                }
                            }
                        }
                    }
                default:
                    VStack(spacing: 14) {
                        Text("Daily goal").font(.title2.weight(.bold))
                        Text("\(goal.formatted()) steps").font(.system(size: 34, weight: .bold))
                        Stepper("Goal", value: $goal, in: 2000...30000, step: 500).labelsHidden()
                        Text("Meowtrek reads steps from Apple Health. You can change this later.")
                            .font(.caption).multilineTextAlignment(.center).foregroundStyle(Color.inkSoft)
                    }
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<3) { i in
                    Capsule().fill(i == page ? Color.leaf : Color.leafLight).frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            Button {
                if page < 2 {
                    withAnimation(.snappy) { page += 1 }
                } else {
                    state.finishOnboarding(name: name, fur: fur, goal: goal)
                    Task { await state.steps.load(); state.refresh() }
                }
            } label: {
                Text(page < 2 ? "Continue" : "Start walking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.leaf, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(hex: 0xEAF2E0), Color.cream], startPoint: .top, endPoint: .bottom))
    }
}
