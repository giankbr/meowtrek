import SwiftUI

func shortSteps(_ n: Int) -> String {
    n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
}

extension Font {
    /// Rounded type; weights are softened so the UI stays calm.
    static func game(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        let w: Font.Weight = weight == .black ? .bold : weight == .heavy ? .bold : weight == .bold ? .semibold : weight
        return .system(size: size, weight: w, design: .rounded)
    }
}

// MARK: - Surfaces

private struct SoftCard: ViewModifier {
    var padding: CGFloat
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(color))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

extension View {
    func card(padding: CGFloat = 16, color: Color = .paper, radius: CGFloat = 22) -> some View {
        modifier(SoftCard(padding: padding, color: color, radius: radius))
    }

    func outlined(_ radius: CGFloat = 14, width: CGFloat = 1) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: width))
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = .sun
    var text: Color = .ink
    var radius: CGFloat = 16
    var padH: CGFloat = 14
    var padV: CGFloat = 9

    func makeBody(configuration: Configuration) -> some View {
        SoftBody(configuration: configuration, color: color, text: text, radius: radius, padH: padH, padV: padV)
    }

    private struct SoftBody: View {
        @Environment(\.isEnabled) private var enabled
        let configuration: Configuration
        let color: Color, text: Color, radius: CGFloat, padH: CGFloat, padV: CGFloat

        var body: some View {
            let plain = color == .paper
            configuration.label
                .font(.game(15, .bold))
                .foregroundStyle(enabled ? text : Color.inkSoft.opacity(0.7))
                .padding(.horizontal, padH)
                .padding(.vertical, padV)
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(enabled ? color : Color.black.opacity(0.05)))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.black.opacity(plain && enabled ? 0.07 : 0), lineWidth: 1))
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
    @State private var bump = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ArtView(id: art, size: 22, line: 1.8)
            Text(text).font(.game(15, .bold)).monospacedDigit().contentTransition(.numericText())
        }
        .foregroundStyle(Color.ink)
        .padding(.leading, 6).padding(.trailing, 11).padding(.vertical, 5)
        .background(Capsule().fill(Color.paper))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .scaleEffect(bump ? 1.1 : 1)
        .animation(.snappy(duration: 0.25), value: text)
        .onChange(of: text) { old, new in
            // Only celebrate increases; spending stays quiet.
            guard !reduceMotion, (Int(new.filter(\.isNumber)) ?? 0) > (Int(old.filter(\.isNumber)) ?? 0) else { return }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { bump = false }
            }
        }
    }
}

struct ProgressBar: View {
    let value: Double
    var color: Color = .grass
    var height: CGFloat = 10
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.grassLight.opacity(0.6))
                Capsule().fill(color).frame(width: g.size.width * min(1, max(0, shown ? value : 0)))
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: value)
        .onAppear {
            guard !shown else { return }
            if reduceMotion { shown = true } else { withAnimation(.easeOut(duration: 0.6).delay(0.1)) { shown = true } }
        }
    }
}

/// Fades and lifts a view in once, staggered by index.
private struct AppearIn: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                withAnimation(.easeOut(duration: 0.3).delay(Double(index) * 0.04)) { shown = true }
            }
    }
}

extension View {
    func appearIn(_ index: Int) -> some View { modifier(AppearIn(index: index)) }
}

/// Fixed-size circular icon button so paired controls line up exactly.
struct RoundIconButton: View {
    let symbol: String
    var fill: Color = .paper
    var tint: Color = .ink
    var size: CGFloat = 40
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(enabled ? tint : Color.inkSoft.opacity(0.5))
                .frame(width: size, height: size)
                .background(Circle().fill(enabled ? fill : Color.black.opacity(0.04)))
                .overlay(Circle().stroke(Color.black.opacity(fill == .paper ? 0.08 : 0), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(PressScale())
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct Tag: View {
    let text: String
    var color: Color = .grass
    var textColor: Color = .white

    var body: some View {
        Text(text)
            .font(.game(11, .bold))
            .foregroundStyle(textColor == .white ? color.darker(0.15) : textColor)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.2)))
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
                ItemArt(item: item, size: 58)
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(wearing ? Color.grassLight : Color.cream))
                    .opacity(locked ? 0.45 : 1)
                    .overlay(alignment: .topTrailing) {
                        if locked {
                            Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.grape).padding(6)
                        }
                    }
                Text(item.name).font(.game(13, .bold)).lineLimit(1).foregroundStyle(Color.ink)
                Group {
                    if owned {
                        Text(wearing ? "Wearing" : "Owned")
                            .foregroundStyle(wearing ? Color.grassDark : Color.inkSoft)
                    } else if let ev = item.event {
                        Text(state.content.events.first { $0.id == ev }?.name ?? "Event").foregroundStyle(Color.grape)
                    } else {
                        HStack(spacing: 3) {
                            ArtView(id: item.currency == .coin ? "coin" : "gem", size: 14, line: 1.2)
                            Text("\(item.price)").foregroundStyle(Color.ink)
                        }
                    }
                }
                .font(.game(12, .semibold))
                .lineLimit(1)
            }
            .padding(8)
            .card(padding: 0, radius: 18)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(wearing ? Color.grass : .clear, lineWidth: 2))
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
            Text(title).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Color.ink)
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
                ArtView(id: art, size: 28, line: 2)
            } else {
                Image(systemName: "pawprint.fill").foregroundStyle(Color.grass)
            }
            Text(toast.text).font(.game(15, .bold)).foregroundStyle(Color.ink).lineLimit(2)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Capsule().fill(Color.paper))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
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
