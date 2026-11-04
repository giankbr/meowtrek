import SwiftUI

func shortSteps(_ n: Int) -> String {
    n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

struct Pill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(text).font(.subheadline.weight(.bold)).monospacedDigit()
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white, in: Capsule())
    }
}

struct ProgressBar: View {
    let value: Double
    var color: Color = .leaf
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.leafLight.opacity(0.45))
                Capsule().fill(color).frame(width: g.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
        .animation(.spring, value: value)
    }
}

struct ItemArt: View {
    let item: Item
    var size: CGFloat = 44

    var body: some View {
        Group {
            if item.id == "witch_hat" {
                WitchHat().frame(width: size, height: size * 0.85)
            } else if item.slot == .fur, let c = item.hex {
                Circle().fill(Color(hex: c))
                    .overlay(Circle().stroke(.black.opacity(0.08)))
                    .frame(width: size * 0.75, height: size * 0.75)
            } else {
                Text(item.emoji).font(.system(size: size * 0.75))
            }
        }
        .frame(width: size, height: size)
    }
}

struct ItemCell: View {
    @Environment(AppState.self) private var state
    let item: Item
    let action: () -> Void

    private var status: (String, Color) {
        if state.equipped[item.slot] == item.id { return ("Wearing", .leafDark) }
        if state.owned.contains(item.id) { return ("Owned", .inkSoft) }
        if let ev = item.event {
            let name = state.content.events.first { $0.id == ev }?.name ?? "Event"
            return ("🔒 \(name)", .inkSoft)
        }
        return ("\(item.currency.icon) \(item.price)", .ink)
    }

    var body: some View {
        let wearing = state.equipped[item.slot] == item.id
        Button(action: action) {
            VStack(spacing: 6) {
                ItemArt(item: item, size: 46)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(item.name).font(.caption.weight(.bold)).lineLimit(1).foregroundStyle(Color.ink)
                Text(status.0).font(.caption2.weight(.semibold)).foregroundStyle(status.1)
            }
            .padding(8)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(wearing ? Color.leaf : .black.opacity(0.06), lineWidth: wearing ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BuyDialog: ViewModifier {
    @Environment(AppState.self) private var state
    @Binding var item: Item?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            item.map { $0.event == nil ? "Buy \($0.name)?" : $0.name } ?? "",
            isPresented: Binding(get: { item != nil }, set: { if !$0 { item = nil } }),
            titleVisibility: .visible,
            presenting: item
        ) { it in
            let have = state.balance(it.currency)
            if it.event != nil {
                Button("OK", role: .cancel) {}
            } else {
                if have >= it.price {
                    Button("Buy for \(it.price) \(it.currency == .coin ? "coins" : "gems")") { state.buy(it) }
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: { it in
            let have = state.balance(it.currency)
            let unit = it.currency == .coin ? "coins" : "gems"
            if let ev = it.event {
                Text("Earn it during the \(state.content.events.first { $0.id == ev }?.name ?? "seasonal") event.")
            } else {
                Text(have >= it.price ? "You have \(have.formatted()) \(unit)."
                     : "Need \(it.price - have) more \(unit). Keep walking!")
            }
        }
    }
}

extension View {
    func buyDialog(_ item: Binding<Item?>) -> some View { modifier(BuyDialog(item: item)) }
}
