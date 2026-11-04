import SwiftUI

struct ShopView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var filter: Slot?
    @State private var buying: Item?
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
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: loc("Shop")) {
                    HStack(spacing: 8) {
                        Pill(art: "coin", text: state.coins.formatted())
                        Pill(art: "gem", text: "\(state.gems)")
                    }
                }

                if !state.isPlus {
                    Button { showPaywall = true } label: {
                        HStack(spacing: 12) {
                            GameIcon(symbol: "crown.fill", tint: .sun, size: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Meowtrek Plus").font(.game(17, .bold))
                                Text("AI cat coach · 1.5× coins · weekly freeze").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Color.inkSoft)
                        }
                        .card(padding: 14, color: Color(hex: 0xFFF6D8))
                    }
                    .buttonStyle(SquishStyle())
                }

                if !state.store.gemProducts.isEmpty {
                    Text("Gems").font(.game(20, .black))
                    HStack(spacing: 10) {
                        ForEach(state.store.gemProducts, id: \.id) { p in
                            Button { Task { await state.store.buy(p) } } label: {
                                VStack(spacing: 6) {
                                    ArtView(id: "gem", size: 40)
                                    Text("\(state.store.gems(for: p))").font(.game(18, .bold))
                                    Text(p.displayPrice).font(.game(13, .bold))
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Capsule().fill(Color.sky.opacity(0.25)))
                                }
                                .frame(maxWidth: .infinity)
                                .card(padding: 10, radius: 18)
                            }
                            .buttonStyle(SquishStyle())
                            .disabled(state.store.purchasing)
                        }
                    }
                }

                Text("Treats & boosts").font(.game(20, .black))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(state.content.consumables) { c in consumableCard(c) }
                    }
                    .padding(.vertical, 4).padding(.bottom, 4).padding(.horizontal, 2)
                }

                HStack {
                    Text("Wardrobe").font(.game(20, .black))
                    Spacer()
                    Button { withAnimation(.snappy) { hideOwned.toggle() } } label: {
                        Label(hideOwned ? "Show owned" : "Hide owned", systemImage: hideOwned ? "eye" : "eye.slash")
                    }
                    .buttonStyle(.chunky(hideOwned ? .grass : .paper, text: hideOwned ? .white : .ink, padH: 10, padV: 6))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("All", selected: filter == nil) { filter = nil }
                        ForEach(Slot.allCases) { s in chip(s.title, selected: filter == s) { filter = s } }
                    }
                    .padding(.vertical, 4).padding(.bottom, 3).padding(.horizontal, 2)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                    ForEach(items) { item in
                        ItemCell(item: item) {
                            if state.owned.contains(item.id) {
                                withAnimation { state.toggle(item) }
                            } else {
                                buying = item
                            }
                        }
                    }
                }
                if items.isEmpty {
                    Text("You own everything here. Nice!").font(.game(15, .bold)).foregroundStyle(Color.inkSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .background(Color.cream)
        .toolbar(pushed ? .visible : .hidden, for: .navigationBar)
        .buyDialog($buying)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task { if !state.store.loaded { await state.store.load() } }
    }

    private func consumableCard(_ c: Consumable) -> some View {
        let afford = state.balance(c.currency) >= c.price
        return VStack(spacing: 6) {
            ArtView(id: c.id, size: 56, line: 2.6)
                .frame(maxWidth: .infinity).frame(height: 66)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cream))
                .overlay(alignment: .topTrailing) {
                    if state.owns(c) > 0 {
                        Text("×\(state.owns(c))").font(.game(11, .black)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.grape)).overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                            .offset(x: 6, y: -6)
                    }
                }
            Text(c.name).font(.game(13, .black)).lineLimit(1)
            Text(c.food > 0 ? "+\(c.food)% food" : "Saves a streak").font(.game(11, .bold)).foregroundStyle(Color.inkSoft)
            Button { withAnimation { state.buy(c) } } label: {
                HStack(spacing: 4) {
                    ArtView(id: c.currency == .coin ? "coin" : "gem", size: 16, line: 1.3)
                    Text("\(c.price)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chunky(.sun, radius: 12, padH: 6, padV: 5))
            .disabled(!afford)
        }
        .frame(width: 112)
        .card(padding: 10, radius: 18)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: { Text(title) }
            .buttonStyle(.chunky(selected ? .grape : .paper, text: selected ? .white : .ink, radius: 20, padH: 14, padV: 7))
    }
}
