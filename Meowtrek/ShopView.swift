import StoreKit
import SwiftUI

struct ShopView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var filter: Slot?
    @State private var buying: Item?
    @State private var trying: Item?
    @State private var hideOwned = false
    @State private var showPaywall = false
    private let pushed: Bool

    init(filter: Slot? = nil) {
        _filter = State(initialValue: filter)
        pushed = filter != nil
    }

    private var items: [Item] {
        Catalog.items.filter {
            $0.forSale && (filter == nil || $0.slot == filter) && !(hideOwned && state.owned.contains($0.id))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeader(title: loc("Shop")) {
                        HStack(spacing: 8) {
                            Pill(art: "coin", text: state.coins.formatted())
                            Pill(art: "gem", text: "\(state.gems)")
                        }
                    }
                    Text("A little stall by the trail. Everything here is paid for in steps.")
                        .font(.story(14, .regular)).italic().foregroundStyle(Color.inkSoft)
                        .padding(.top, 10)
                }

                if !state.isPlus { plusLetter }

                if !state.store.gemProducts.isEmpty {
                    shelfTitle(loc("Gem tickets"), loc("Little extras, if you'd like to support us"))
                    HStack(spacing: 10) {
                        ForEach(state.store.gemProducts, id: \.id) { p in gemTicket(p) }
                    }
                }

                shelfTitle(loc("Snack shelf"), loc("Treats for \(state.petName) and freezes for lazy days"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(state.content.consumables) { c in consumableCard(c) }
                    }
                    .padding(.top, 14).padding(.bottom, 8).padding(.horizontal, 4)
                }
                .padding(.horizontal, -4)

                VStack(spacing: 0) {
                    Awning(stripe: .bubble, height: 30)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            StoryHeading(text: loc("Clothes rack"), size: 22, color: .bubble)
                            Spacer()
                            Button { withAnimation(.snappy) { hideOwned.toggle() } } label: {
                                Label(hideOwned ? loc("Show yours") : loc("Hide yours"), systemImage: hideOwned ? "eye" : "eye.slash")
                            }
                            .buttonStyle(StoryChipStyle(on: hideOwned))
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                chip(loc("Everything"), selected: filter == nil) { filter = nil }
                                ForEach(Slot.allCases) { s in chip(s.title, selected: filter == s) { filter = s } }
                            }
                            .padding(.vertical, 4).padding(.horizontal, 2)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 18) {
                            ForEach(items) { item in
                                StallItemCell(item: item) {
                                    if state.owned.contains(item.id) {
                                        withAnimation { state.toggle(item) }
                                    } else {
                                        trying = item
                                    }
                                }
                            }
                        }
                        .padding(.top, 6)
                        if items.isEmpty {
                            VStack(spacing: 8) {
                                Stamp(text: loc("Sold out"), color: .grassDark, size: 70)
                                Text("You've bought the whole rack. Fancy cat!")
                                    .font(.story(15, .semibold)).foregroundStyle(Color.inkSoft)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    }
                    .padding(14)
                    .background(Color.paper.opacity(0.55))
                }
                .clipShape(PaperShape(radius: 12, wobble: 1, seed: 19))
                .overlay(PaperShape(radius: 12, wobble: 1, seed: 19).stroke(Color.ink.opacity(0.08), lineWidth: 1))
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .paperBackground()
        .toolbar(pushed ? .visible : .hidden, for: .navigationBar)
        .buyDialog($buying)
        .sheet(item: $trying) { TryOnSheet(item: $0) }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task { if !state.store.loaded { await state.store.load() } }
    }

    private var plusLetter: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                WaxSeal(symbol: "crown.fill", color: .tomato, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text("A letter from \(state.petName)").font(.story(17, .bold))
                    Text("Join Plus: a cat coach to chat with, 1.5× coins and a weekly streak freeze.")
                        .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "envelope.open").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.choco)
            }
            .card(padding: 14, color: Color.chestBg)
            .taped(.topTrailing, angle: 8, color: .bubble, x: -24, width: 46)
        }
        .buttonStyle(SquishStyle())
    }

    private func shelfTitle(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StoryHeading(text: title, size: 22)
            Text(detail).font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
        }
    }

    private func gemTicket(_ p: Product) -> some View {
        Button { Task { await state.store.buy(p) } } label: {
            VStack(spacing: 4) {
                ArtView(id: "gem", size: 34)
                Text("\(state.store.gems(for: p))").font(.story(20, .bold)).monospacedDigit()
                PencilRule().padding(.horizontal, 6)
                Text(p.displayPrice).font(.game(13, .bold)).foregroundStyle(Color.skyDark)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(TicketShape().fill(Color.paper))
            .overlay(TicketShape().stroke(Color.sky.opacity(0.8), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(SquishStyle())
        .disabled(state.store.purchasing)
    }

    private func consumableCard(_ c: Consumable) -> some View {
        let afford = state.balance(c.currency) >= c.price
        let have = state.owns(c)
        return VStack(spacing: 6) {
            ArtView(id: c.id, size: 56, line: 2.6)
                .frame(maxWidth: .infinity).frame(height: 66)
                .background(SketchSquare())
            Text(c.name).font(.story(14, .bold)).lineLimit(1)
            Text(c.food > 0 ? loc("Fills \(c.food)% of the bowl") : loc("Keeps a streak safe"))
                .font(.game(11, .medium)).foregroundStyle(Color.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
            Button { withAnimation { state.buy(c) } } label: {
                HStack(spacing: 4) {
                    ArtView(id: c.currency == .coin ? "coin" : "gem", size: 15, line: 1.2)
                    Text("\(c.price)").font(.game(14, .bold)).monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chunky(afford ? (c.currency == .gem ? .sky : .sun) : .paper, text: .ink, radius: 10, padV: 7))
            .disabled(!afford)
            .opacity(afford ? 1 : 0.55)
            .padding(.top, 2)
        }
        .frame(width: 112)
        .card(padding: 10, radius: 10)
        .overlay(alignment: .topTrailing) {
            if have > 0 {
                Stamp(text: "×\(have)", color: .grape, size: 34, angle: 10).offset(x: 8, y: -12)
            }
        }
    }
    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: { Text(title) }
            .buttonStyle(StoryChipStyle(on: selected, color: .grape))
    }
}

/// Clothes on the stall rack: price on a tied paper tag, or a stamp once it's yours.
struct StallItemCell: View {
    @Environment(AppState.self) private var state
    let item: Item
    let action: () -> Void

    var body: some View {
        let wearing = state.equipped[item.slot] == item.id
        let owned = state.owned.contains(item.id)
        let locked = !owned && item.event != nil
        let afford = state.balance(item.currency) >= item.price
        Button(action: action) {
            VStack(spacing: 6) {
                ItemArt(item: item, size: 54)
                    .frame(maxWidth: .infinity).frame(height: 70)
                    .background(SketchSquare(on: wearing))
                    .opacity(locked ? 0.45 : 1)
                Text(item.name).font(.story(13, .semibold)).lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(Color.ink)
                Group {
                    if owned {
                        Text(wearing ? loc("Wearing") : loc("Tap to put on")).foregroundStyle(wearing ? Color.grassDark : Color.inkSoft)
                    } else if let ev = item.event {
                        Label(state.content.events.first { $0.id == ev }?.name ?? loc("Event"), systemImage: "lock.fill")
                            .foregroundStyle(Color.grape)
                    } else {
                        Text(afford ? loc("Try it on") : loc("Keep walking")).foregroundStyle(Color.inkSoft)
                    }
                }
                .font(.game(11, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(7)
            .card(padding: 0, radius: 8)
            .overlay(alignment: .topTrailing) {
                if owned {
                    Stamp(text: wearing ? loc("On") : loc("Yours"), color: wearing ? .grassDark : .tomato, size: 36, angle: 14)
                        .offset(x: 8, y: -10)
                } else if item.event == nil {
                    HStack(spacing: 3) {
                        ArtView(id: item.currency == .coin ? "coin" : "gem", size: 12, line: 1.1)
                        Text("\(item.price)").font(.game(12, .bold)).monospacedDigit()
                    }
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(item.currency == .gem ? Color.sky : Color.sun))
                    .overlay(Capsule().stroke(Color.ink.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
                    .offset(x: -4, y: 6)
                }
            }
        }
        .buttonStyle(SquishStyle())
    }
}
