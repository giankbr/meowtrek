import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = "id.gian.meowtrek.plus.yearly"

    private let perks: [(String, String, String)] = [
        ("bubble.left.and.bubble.right", loc("Chats without a daily limit"), loc("Talk walks, moods and snacks with your cat whenever you like")),
        ("sparkles", loc("A weekly letter about your walks"), loc("What went well, what to try, and a goal that fits")),
        ("wand.and.stars", loc("Errands written just for you"), loc("Daily quests shaped around your own rhythm")),
        ("circle.circle", loc("1.5× coins"), loc("Every step you collect is worth a little more")),
        ("snowflake", loc("A streak freeze every Monday"), loc("For rainy weeks and lazy Sundays")),
        ("icloud", loc("A daily copy in your iCloud"), loc("Your cat moves with you to a new iPhone")),
        ("crown", loc("The Plus crown"), loc("Shown on your friend card")),
    ]

    var body: some View {
        let store = state.store
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Text("YOU'RE INVITED").font(.story(12, .bold)).kerning(3).foregroundStyle(Color.grassDark)
                    ZStack {
                        Circle().fill(Color.sun.opacity(0.22)).frame(width: 150).blur(radius: 6)
                        CatView(outfit: state.outfit.merging([.hat: Catalog.item("crown")!]) { _, b in b }, size: 124, mood: .happy)
                    }
                    Text("Meowtrek Plus").font(.story(32, .bold))
                    Text("\(state.petName) would love you to join the Plus club. Here's what's inside the envelope:")
                        .font(.story(15, .regular)).italic().foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(perks, id: \.1) { icon, title, detail in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.grassDark).frame(width: 22).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(title).font(.story(16, .bold))
                                    Text(detail).font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.top, 6)
                    Text("With love, \(state.petName)").font(.story(15, .semibold)).italic()
                        .frame(maxWidth: .infinity, alignment: .trailing).padding(.top, 4)
                }
                .invitation()
                .overlay(alignment: .bottom) { WaxSeal(symbol: "crown.fill", size: 50).offset(y: 22) }
                .padding(.top, 34)
                .padding(.bottom, 8)

                if store.isPlus {
                    VStack(spacing: 6) {
                        Stamp(text: loc("Member"), color: .grassDark, size: 72)
                        Text("You're in the Plus club").font(.story(18, .bold))
                        if let r = store.plusRenewal {
                            Text("Renews \(r.formatted(date: .abbreviated, time: .omitted))")
                                .font(.game(13, .medium)).foregroundStyle(Color.inkSoft)
                        }
                    }
                    .frame(maxWidth: .infinity).card()
                } else if store.plusProducts.isEmpty {
                    VStack(spacing: 6) {
                        ProgressView()
                        Text(store.loaded ? "The plans didn't arrive. Try again a little later." : "Fetching the plans…")
                            .font(.game(13, .medium)).foregroundStyle(Color.inkSoft)
                    }
                    .frame(maxWidth: .infinity).card()
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.plusProducts.reversed(), id: \.id) { p in planRow(p) }
                    }
                    Button {
                        guard let p = store.plusProducts.first(where: { $0.id == selected }) else { return }
                        Task {
                            if await store.buy(p), store.isPlus {
                                Telemetry.track("plus_purchased")
                                state.show(loc("Welcome to the Plus club!"), art: "crown")
                                state.celebrate(.confetti)
                                dismiss()
                            }
                        }
                    } label: {
                        Text(trialText ?? loc("Accept the invitation")).font(.story(18, .bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chunky(.grass, text: .white, radius: 14, padV: 15))
                    .disabled(store.purchasing)
                }

                HStack(spacing: 18) {
                    Button("Restore") { Task { await store.restore() } }
                    Link("Terms", destination: AppConfig.termsURL)
                    Link("Privacy", destination: AppConfig.privacyURL)
                }
                .font(.game(13, .semibold))
                .foregroundStyle(Color.inkSoft)

                Text("Subscriptions renew automatically until cancelled in Settings › Apple ID › Subscriptions. Payment is charged to your Apple ID.")
                    .font(.game(11, .medium)).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .foregroundStyle(Color.ink)
        .paperBackground()
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.inkSoft)
                    .frame(width: 32, height: 32).background(Circle().fill(Color.paper))
            }
            .accessibilityLabel(Text("Close"))
            .padding(16)
        }
        .task { if !store.loaded { await store.load() } }
        .onAppear { Telemetry.track("paywall_shown") }
        .presentationBackground(Color.cream)
    }

    private var trialText: String? {
        guard let p = state.store.plusProducts.first(where: { $0.id == selected }),
              let offer = p.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return offer.period.unit == .week && offer.period.value == 1 ? loc("Start 1-week free trial") : loc("Start free trial")
    }

    private func unitName(_ u: Product.SubscriptionPeriod.Unit) -> String {
        switch u {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
    }

    private func planRow(_ p: Product) -> some View {
        let on = selected == p.id
        let yearly = p.subscription?.subscriptionPeriod.unit == .year
        let monthlyPrice = state.store.plusProducts.first { $0.subscription?.subscriptionPeriod.unit == .month }?.price
        let saving: Int? = {
            guard yearly, let m = monthlyPrice, m > 0 else { return nil }
            let s = 1 - (p.price as NSDecimalNumber).doubleValue / ((m as NSDecimalNumber).doubleValue * 12)
            return s > 0.05 ? Int((s * 100).rounded()) : nil
        }()
        return Button { withAnimation(.snappy) { selected = p.id } } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(yearly ? loc("A whole year") : loc("Month by month")).font(.story(17, .bold))
                    Text(yearly ? loc("\(p.displayPrice) once a year") : loc("Cancel whenever you like"))
                        .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(yearly ? (p.price / 12).formatted(p.priceFormatStyle) : p.displayPrice)
                        .font(.story(19, .bold)).monospacedDigit()
                    Text("a month").font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(TicketShape(notch: 9).fill(on ? Color.grassLight.opacity(0.6) : Color.paper))
            .overlay(TicketShape(notch: 9).stroke(on ? Color.grass : Color.ink.opacity(0.15),
                                                  style: StrokeStyle(lineWidth: on ? 2 : 1, dash: on ? [] : [4, 3])))
            .overlay(alignment: .topTrailing) {
                if let saving {
                    PriceTag(text: loc("Save \(saving)%"), color: Color.bubble.opacity(0.5), angle: 8).offset(x: 6, y: -14)
                }
            }
            .overlay(alignment: .topLeading) {
                if on { Stamp(text: loc("Picked"), color: .grassDark, size: 40, angle: -16).offset(x: -10, y: -16) }
            }
        }
        .buttonStyle(SquishStyle())
    }
}

enum AppConfig {
    private static func info(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    static var apiBase: URL? { URL(string: info("MeowtrekAPIBase")).flatMap { $0.host == nil ? nil : $0 } }
    static var facebookAppID: String { info("MeowtrekFacebookAppID") }
    static var fitbitClientID: String { info("MeowtrekFitbitClientID") }
    static let termsURL = URL(string: "https://giankbr.github.io/meowtrek/terms.html")!
    static let privacyURL = URL(string: "https://giankbr.github.io/meowtrek/privacy.html")!
}
