import SwiftUI

func shortSteps(_ n: Int) -> String {
    n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
}

extension Font {
    static func game(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Surfaces

private struct StickerCard: ViewModifier {
    var padding: CGFloat
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(padding)
            .background(shape.fill(color))
            .overlay(shape.stroke(Color.ink, lineWidth: 2.5))
            .background(shape.fill(Color.ink).offset(y: 4))
    }
}

extension View {
    func card(padding: CGFloat = 16, color: Color = .paper, radius: CGFloat = 22) -> some View {
        modifier(StickerCard(padding: padding, color: color, radius: radius))
    }

    func outlined(_ radius: CGFloat = 14, width: CGFloat = 2.5) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.ink, lineWidth: width))
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = .sun
    var text: Color = .ink
    var radius: CGFloat = 16
    var padH: CGFloat = 14
    var padV: CGFloat = 9

    func makeBody(configuration: Configuration) -> some View {
        ChunkyBody(configuration: configuration, color: color, text: text, radius: radius, padH: padH, padV: padV)
    }

    private struct ChunkyBody: View {
        @Environment(\.isEnabled) private var enabled
        let configuration: Configuration
        let color: Color, text: Color, radius: CGFloat, padH: CGFloat, padV: CGFloat

        var body: some View {
            let pressed = configuration.isPressed
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            configuration.label
                .font(.game(15))
                .foregroundStyle(enabled ? text : Color.inkSoft)
                .padding(.horizontal, padH)
                .padding(.vertical, padV)
                .background(shape.fill(enabled ? color : Color(hex: 0xEDE6D6)))
                .overlay(alignment: .top) {
                    shape.fill(.white.opacity(enabled ? 0.28 : 0)).frame(height: 6).padding(.horizontal, 6).padding(.top, 3)
                }
                .overlay(shape.stroke(Color.ink.opacity(enabled ? 1 : 0.35), lineWidth: 2.5))
                .background(shape.fill(Color.ink.opacity(enabled ? 1 : 0.25)).offset(y: pressed ? 1 : 4))
                .offset(y: pressed ? 3 : 0)
                .scaleEffect(pressed ? 0.97 : 1)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pressed)
        }
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static func chunky(_ color: Color = .sun, text: Color = .ink, radius: CGFloat = 16,
                       padH: CGFloat = 14, padV: CGFloat = 9) -> ChunkyButtonStyle {
        ChunkyButtonStyle(color: color, text: text, radius: radius, padH: padH, padV: padV)
    }
}

/// Plain press feedback for tappable cards and art.
struct SquishStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

// MARK: - Small pieces

struct Pill: View {
    let art: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            ArtView(id: art, size: 22, line: 1.8)
            Text(text).font(.game(15)).monospacedDigit().contentTransition(.numericText())
        }
        .foregroundStyle(Color.ink)
        .padding(.leading, 5).padding(.trailing, 11).padding(.vertical, 4)
        .background(Capsule().fill(Color.paper))
        .overlay(Capsule().stroke(Color.ink, lineWidth: 2.5))
        .background(Capsule().fill(Color.ink).offset(y: 3))
        .animation(.spring, value: text)
    }
}

struct ProgressBar: View {
    let value: Double
    var color: Color = .grass
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { g in
            let w = g.size.width * min(1, max(0, value))
            ZStack(alignment: .leading) {
                Capsule().fill(Color(hex: 0xEDE6D6))
                if value > 0 {
                    Capsule().fill(color).frame(width: max(height, w))
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.35)).frame(height: height * 0.28)
                                .padding(.horizontal, height * 0.4).padding(.top, height * 0.18)
                        }
                }
                Capsule().stroke(Color.ink, lineWidth: max(2, height / 6))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
    }
}

struct Tag: View {
    let text: String
    var color: Color = .grass
    var textColor: Color = .white

    var body: some View {
        Text(text.uppercased())
            .font(.game(10, .black))
            .foregroundStyle(textColor)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(color))
            .overlay(Capsule().stroke(Color.ink, lineWidth: 2))
    }
}

struct ItemArt: View {
    let item: Item
    var size: CGFloat = 44

    var body: some View {
        ArtView(id: item.id, size: size, tint: item.hex.map { Color(hex: $0) })
    }
}

struct ItemCell: View {
    @Environment(AppState.self) private var state
    let item: Item
    let action: () -> Void

    var body: some View {
        let wearing = state.equipped[item.slot] == item.id
        let owned = state.owned.contains(item.id)
        let locked = !owned && item.event != nil
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ItemArt(item: item, size: 54)
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(wearing ? Color.grassLight : Color.cream))
                        .opacity(locked ? 0.45 : 1)
                    if wearing {
                        Image(systemName: "checkmark").font(.game(11, .black)).foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.grass)).overlay(Circle().stroke(Color.ink, lineWidth: 2))
                            .offset(x: 5, y: -5)
                    } else if locked {
                        Image(systemName: "lock.fill").font(.game(10, .black)).foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.grape)).overlay(Circle().stroke(Color.ink, lineWidth: 2))
                            .offset(x: 5, y: -5)
                    }
                }
                Text(item.name).font(.game(12, .bold)).lineLimit(1).foregroundStyle(Color.ink)
                if owned {
                    Text(wearing ? "Wearing" : "Owned").font(.game(11, .bold))
                        .foregroundStyle(wearing ? Color.grassDark : Color.inkSoft)
                } else if let ev = item.event {
                    Text(state.content.events.first { $0.id == ev }?.name ?? "Event")
                        .font(.game(11, .bold)).foregroundStyle(Color.grape).lineLimit(1)
                } else {
                    HStack(spacing: 3) {
                        ArtView(id: item.currency == .coin ? "coin" : "gem", size: 14, line: 1.2)
                        Text("\(item.price)").font(.game(12)).foregroundStyle(Color.ink)
                    }
                }
            }
            .padding(8)
            .card(padding: 0, color: .paper, radius: 18)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(wearing ? Color.grass : .clear, lineWidth: 3).padding(3))
        }
        .buttonStyle(SquishStyle())
    }
}

/// Small header used at the top of every main tab.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title).font(.game(34, .black)).foregroundStyle(Color.ink)
            Spacer()
            trailing
        }
    }
}

// MARK: - Buy dialog

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

// MARK: - Toast & celebration

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            if let art = toast.art {
                ArtView(id: art, size: 30, line: 2)
            } else {
                GameIcon(symbol: "pawprint.fill", tint: .grass, size: 28)
            }
            Text(toast.text).font(.game(16)).foregroundStyle(Color.ink).lineLimit(2)
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 8)
        .background(Capsule().fill(Color.paper))
        .overlay(Capsule().stroke(Color.ink, lineWidth: 3))
        .background(Capsule().fill(Color.ink).offset(y: 4))
    }
}

struct FXLayer: View {
    let fx: FX
    @State private var bits: [Bit] = []

    struct Bit: Identifiable {
        let id = UUID()
        let art: String?
        let color: Color
        let start: CGPoint
        let end: CGPoint
        let spin: Double
        let delay: Double
        let size: CGFloat
    }

    var body: some View {
        GeometryReader { g in
            ZStack {
                ForEach(bits) { b in BitView(bit: b) }
            }
            .onChange(of: fx.tick) { spawn(in: g.size) }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func spawn(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
        var new: [Bit] = []
        switch fx.kind {
        case .coins, .gems:
            for i in 0..<14 {
                let a = Double(i) / 14 * 2 * .pi + Double.random(in: -0.2...0.2)
                let r = CGFloat.random(in: 90...170)
                new.append(Bit(art: fx.kind == .coins ? "coin" : "gem", color: .sun, start: center,
                               end: CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r - 60),
                               spin: Double.random(in: -200...200), delay: Double(i) * 0.012, size: 26))
            }
        case .confetti:
            let colors: [Color] = [.tomato, .sun, .grass, .sky, .grape, .bubble]
            for i in 0..<46 {
                let x = CGFloat.random(in: 0...size.width)
                new.append(Bit(art: nil, color: colors[i % colors.count], start: CGPoint(x: x, y: -20),
                               end: CGPoint(x: x + CGFloat.random(in: -60...60), y: size.height * CGFloat.random(in: 0.5...0.95)),
                               spin: Double.random(in: -540...540), delay: Double.random(in: 0...0.35), size: 10))
            }
        }
        bits.append(contentsOf: new)
        let ids = Set(new.map(\.id))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { bits.removeAll { ids.contains($0.id) } }
    }

    private struct BitView: View {
        let bit: Bit
        @State private var go = false

        var body: some View {
            Group {
                if let art = bit.art {
                    ArtView(id: art, size: bit.size, line: 2)
                } else {
                    RoundedRectangle(cornerRadius: 2).fill(bit.color).frame(width: bit.size, height: bit.size * 0.55)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.ink, lineWidth: 1.2))
                }
            }
            .rotationEffect(.degrees(go ? bit.spin : 0))
            .scaleEffect(go ? (bit.art == nil ? 1 : 0.6) : (bit.art == nil ? 1 : 0.2))
            .position(go ? bit.end : bit.start)
            .opacity(go ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: bit.art == nil ? 1.5 : 0.9).delay(bit.delay)) { go = true }
            }
        }
    }
}

// MARK: - Tab bar

struct GameTabBar: View {
    @Binding var selection: Int
    var badge: Int

    private let tabs: [(String, String, Color)] = [
        ("Home", "house.fill", .tomato), ("Journey", "map.fill", .sky), ("Shop", "bag.fill", .sun),
        ("Social", "person.2.fill", .grape), ("Stats", "chart.bar.fill", .grass),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, t in
                let on = selection == i
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { selection = i }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.1)
                            .font(.system(size: on ? 20 : 18, weight: .black))
                            .foregroundStyle(on ? .white : Color.inkSoft)
                            .frame(width: 44, height: 34)
                            .background {
                                if on {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(t.2)
                                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.ink, lineWidth: 2.5))
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if i == 0 && badge > 0 {
                                    Text("\(badge)").font(.game(10, .black)).foregroundStyle(.white)
                                        .frame(minWidth: 18, minHeight: 18)
                                        .background(Circle().fill(Color.tomato))
                                        .overlay(Circle().stroke(Color.ink, lineWidth: 2))
                                        .offset(x: 6, y: -6)
                                }
                            }
                            .offset(y: on ? -2 : 0)
                        Text(t.0).font(.game(11, on ? .black : .bold))
                            .foregroundStyle(on ? Color.ink : Color.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SquishStyle())
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.paper))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.ink, lineWidth: 3))
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color.ink).offset(y: 5))
        .padding(.horizontal, 14)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
