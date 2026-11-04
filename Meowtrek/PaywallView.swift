import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = "id.gian.meowtrek.plus.yearly"

    private let perks: [(String, Color, String, String)] = [
        ("bubble.left.and.bubble.right.fill", .grape, "Unlimited cat chat", "Talk with your cat coach any time"),
        ("sparkles", .sun, "Weekly AI insights", "Personal walking report and goal tips"),
        ("wand.and.stars", .bubble, "AI daily quests", "Quests tuned to your own rhythm"),
        ("bitcoinsign.circle.fill", .pumpkin, "1.5× coins", "Every claimed step pays more"),
        ("snowflake", .sky, "Free weekly streak freeze", "One freeze every Monday"),
        ("crown.fill", .tomato, "Plus badge", "Show it on your friend card"),
    ]

    var body: some View {
        let store = state.store
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Color.sun.opacity(0.25)).frame(width: 170)
                        CatView(outfit: state.outfit.merging([.hat: Catalog.item("crown")!]) { _, b in b }, size: 130, mood: .happy)
                    }
                    Text("Meowtrek Plus").font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("More love for \(state.petName), more reasons to walk.")
                        .font(.game(15, .semibold)).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    ForEach(perks, id: \.2) { icon, tint, title, detail in
                        HStack(spacing: 12) {
                            GameIcon(symbol: icon, tint: tint, size: 40)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(title).font(.game(15, .bold))
                                Text(detail).font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                            }
                            Spacer()
                        }
                    }
                }
                .card()

                if store.isPlus {
                    VStack(spacing: 6) {
                        Label("You're a Plus member", systemImage: "checkmark.seal.fill")
                            .font(.game(17, .bold)).foregroundStyle(Color.grassDark)
                        if let r = store.plusRenewal {
                            Text("Renews \(r.formatted(date: .abbreviated, time: .omitted))")
                                .font(.game(13, .medium)).foregroundStyle(Color.inkSoft)
                        }
                    }
                    .frame(maxWidth: .infinity).card()
                } else if store.plusProducts.isEmpty {
                    VStack(spacing: 6) {
                        ProgressView()
                        Text(store.loaded ? "Plans aren't available right now. Try again later." : "Loading plans…")
                            .font(.game(13, .medium)).foregroundStyle(Color.inkSoft)
                    }
                    .frame(maxWidth: .infinity).card()
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.plusProducts.reversed(), id: \.id) { p in planRow(p) }
                    }
                    Button {
                        guard let p = store.plusProducts.first(where: { $0.id == selected }) else { return }
                        Task {
                            if await store.buy(p), store.isPlus {
                                state.show("Welcome to Plus!", art: "crown")
                                state.celebrate(.confetti)
                                dismiss()
                            }
                        }
                    } label: {
                        Text(trialText ?? "Continue").font(.game(18, .bold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chunky(.grass, text: .white, radius: 20, padV: 15))
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
        .background(Color.cream)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.inkSoft)
                    .frame(width: 32, height: 32).background(Circle().fill(Color.paper))
            }
            .padding(16)
        }
        .task { if !store.loaded { await store.load() } }
    }

    private var trialText: String? {
        guard let p = state.store.plusProducts.first(where: { $0.id == selected }),
              let offer = p.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return "Start \(offer.period.value)-\(unitName(offer.period.unit)) free trial"
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
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22)).foregroundStyle(on ? Color.grass : Color.inkSoft.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(yearly ? "Yearly" : "Monthly").font(.game(16, .bold))
                        if let saving { Tag(text: "Save \(saving)%", color: .tomato) }
                    }
                    if yearly {
                        Text("\(p.displayPrice) / year").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                    }
                }
                Spacer()
                Text(yearly ? (p.price / 12).formatted(p.priceFormatStyle) + "/mo" : p.displayPrice + "/mo")
                    .font(.game(15, .bold))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.paper))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(on ? Color.grass : .black.opacity(0.06), lineWidth: on ? 2 : 1))
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
