import SwiftUI

struct ShopView: View {
    @Environment(AppState.self) private var state
    @State private var filter: Slot?
    @State private var buying: Item?
    @State private var hideOwned = false

    init(filter: Slot? = nil) { _filter = State(initialValue: filter) }

    private var items: [Item] {
        Catalog.items.filter {
            $0.forSale && (filter == nil || $0.slot == filter) && !(hideOwned && state.owned.contains($0.id))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Treats & boosts").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(state.content.consumables) { c in consumableCard(c) }
                    }
                }

                HStack {
                    Text("Wardrobe").font(.headline)
                    Spacer()
                    Toggle("Hide owned", isOn: $hideOwned).toggleStyle(.button).font(.caption).tint(.leaf)
                }
                .padding(.top, 6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("All", selected: filter == nil) { filter = nil }
                        ForEach(Slot.allCases) { s in
                            chip(s.title, selected: filter == s) { filter = s }
                        }
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
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
                    Text("You own everything here. Nice!").font(.subheadline).foregroundStyle(Color.inkSoft)
                        .frame(maxWidth: .infinity).padding(.vertical, 30)
                }
            }
            .padding(16)
        }
        .foregroundStyle(Color.ink)
        .background(Color.cream)
        .navigationTitle("Shop")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 6) {
                    Pill(icon: "🪙", text: state.coins.formatted())
                    Pill(icon: "💎", text: "\(state.gems)")
                }
            }
        }
        .buyDialog($buying)
    }

    private func consumableCard(_ c: Consumable) -> some View {
        let afford = state.balance(c.currency) >= c.price
        return VStack(spacing: 6) {
            Text(c.emoji).font(.system(size: 34))
            Text(c.name).font(.caption.weight(.bold)).lineLimit(1)
            Text(c.food > 0 ? "+\(c.food)% food" : "Saves 1 missed day")
                .font(.caption2).foregroundStyle(Color.inkSoft)
            Text("Have \(state.owns(c))").font(.caption2).foregroundStyle(Color.inkSoft)
            Button { withAnimation { state.buy(c) } } label: {
                Text("\(c.currency.icon) \(c.price)").font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    .background(afford ? Color.honey : Color.cream, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!afford)
        }
        .frame(width: 112)
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy) { action() } } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Color.leaf : .white, in: Capsule())
                .foregroundStyle(selected ? .white : Color.ink)
        }
        .buttonStyle(.plain)
    }
}
