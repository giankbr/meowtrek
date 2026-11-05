import SwiftUI

// MARK: - Paper market stall

/// Luggage-style paper tag with a punched hole, pointing left.
struct TagShape: Shape {
    func path(in r: CGRect) -> Path {
        let n = min(r.height * 0.42, 12), c: CGFloat = 4
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + c), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A price written on a tied paper tag, hanging off a string.
struct PriceTag: View {
    var art: String? = nil
    let text: String
    var color: Color = .paper
    var ink: Color = .ink
    var angle: Double = -8
    var string = true

    var body: some View {
        HStack(spacing: 3) {
            if let art { ArtView(id: art, size: 15, line: 1.2) }
            Text(text).font(.story(14, .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(ink)
        .padding(.leading, 17).padding(.trailing, 8).padding(.vertical, 4)
        .background(TagShape().fill(color))
        .overlay(TagShape().stroke(Color.ink.opacity(0.55), lineWidth: 1))
        .overlay(alignment: .leading) {
            Circle().fill(Color.cream).frame(width: 5, height: 5)
                .overlay(Circle().stroke(Color.ink.opacity(0.5), lineWidth: 0.8))
                .padding(.leading, 7)
        }
        .overlay(alignment: .topLeading) {
            if string {
                StringLoop().stroke(Color.choco.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .frame(width: 18, height: 16)
                    .offset(x: -6, y: -12)
            }
        }
        .rotationEffect(.degrees(angle), anchor: .leading)
    }

    private struct StringLoop: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.maxX * 0.75, y: r.maxY))
            p.addCurve(to: CGPoint(x: r.minX, y: r.minY), control1: CGPoint(x: r.maxX * 0.2, y: r.maxY), control2: CGPoint(x: r.maxX, y: r.minY))
            return p
        }
    }
}

/// Striped shop awning with a scalloped hem.
struct Awning: View {
    var stripe: Color = .grass
    var ground: Color = .paper
    var height: CGFloat = 34

    var body: some View {
        GeometryReader { g in
            let count = max(6, Int(g.size.width / 30))
            let w = g.size.width / CGFloat(count)
            ZStack {
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { i in
                        Rectangle().fill(i.isMultiple(of: 2) ? stripe : ground)
                    }
                }
                .overlay(Hatch(gap: 5).stroke(Color.white.opacity(0.18), lineWidth: 1))
                .mask(Scallops(count: count))
                Scallops(count: count).stroke(Color.ink.opacity(0.45), lineWidth: 1.2)
            }
            .frame(width: w * CGFloat(count))
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    struct Scallops: Shape {
        let count: Int
        func path(in r: CGRect) -> Path {
            let w = r.width / CGFloat(count), hem = r.height * 0.3
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - hem))
            for i in (0..<count).reversed() {
                let x0 = r.minX + CGFloat(i) * w
                p.addQuadCurve(to: CGPoint(x: x0, y: r.maxY - hem), control: CGPoint(x: x0 + w / 2, y: r.maxY + hem * 0.6))
            }
            p.closeSubpath()
            return p
        }
    }
}

/// Ticket with perforated half-moon notches on both sides.
struct TicketShape: Shape {
    var notch: CGFloat = 7

    func path(in r: CGRect) -> Path {
        var p = Path(roundedRect: r, cornerRadius: 8, style: .continuous)
        p = p.subtracting(Path(ellipseIn: CGRect(x: r.minX - notch, y: r.midY - notch, width: notch * 2, height: notch * 2)))
        p = p.subtracting(Path(ellipseIn: CGRect(x: r.maxX - notch, y: r.midY - notch, width: notch * 2, height: notch * 2)))
        return p
    }
}

/// Postage stamp with a pinked, perforated edge.
struct PostageShape: Shape {
    var tooth: CGFloat = 3.2

    func path(in r: CGRect) -> Path {
        var p = Path(r)
        let step = tooth * 2.4
        var x = r.minX + step / 2
        while x < r.maxX {
            p = p.subtracting(Path(ellipseIn: CGRect(x: x - tooth / 2, y: r.minY - tooth / 2, width: tooth, height: tooth)))
            p = p.subtracting(Path(ellipseIn: CGRect(x: x - tooth / 2, y: r.maxY - tooth / 2, width: tooth, height: tooth)))
            x += step
        }
        var y = r.minY + step / 2
        while y < r.maxY {
            p = p.subtracting(Path(ellipseIn: CGRect(x: r.minX - tooth / 2, y: y - tooth / 2, width: tooth, height: tooth)))
            p = p.subtracting(Path(ellipseIn: CGRect(x: r.maxX - tooth / 2, y: y - tooth / 2, width: tooth, height: tooth)))
            y += step
        }
        return p
    }
}

/// Reward button drawn as a little postage stamp.
struct PostageButtonStyle: ButtonStyle {
    var color: Color = .sun

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.story(14, .bold))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(PostageShape().fill(color.opacity(0.9)))
            .overlay(Rectangle().inset(by: 3.5).stroke(Color.ink.opacity(0.25), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2])))
            .rotationEffect(.degrees(configuration.isPressed ? 0 : 3))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Paper tab chip for filters and small choices.
struct StoryChipStyle: ButtonStyle {
    var on: Bool
    var color: Color = .grass

    func makeBody(configuration: Configuration) -> some View {
        let shape = PaperShape(radius: 9, wobble: 0.8, seed: 21)
        configuration.label
            .font(.story(14, on ? .bold : .medium))
            .foregroundStyle(on ? Color.white : Color.ink)
            .lineLimit(1)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(shape.fill(on ? color : Color.paper))
            .overlay(shape.stroke(on ? color.darker(0.12) : Color.ink.opacity(0.14), lineWidth: 1))
            .rotationEffect(.degrees(on ? -1.5 : 0))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.18), value: on)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Dashed pencil rule between rows.
struct PencilRule: View {
    var body: some View {
        Line().stroke(Color.inkSoft.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 4]))
            .frame(height: 1)
    }

    private struct Line: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            return p
        }
    }
}

// MARK: - Invitations and sheets

/// Wax seal with a scalloped rim and an emblem pressed in.
struct WaxSeal: View {
    var symbol: String = "pawprint.fill"
    var color: Color = .tomato
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Rim().fill(color)
            Circle().inset(by: size * 0.16).stroke(Color.black.opacity(0.18), lineWidth: 1.5)
            Image(systemName: symbol).font(.system(size: size * 0.32, weight: .bold)).foregroundStyle(Color.black.opacity(0.22))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1.5)
        .rotationEffect(.degrees(-10))
        .accessibilityHidden(true)
    }

    private struct Rim: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path(), n = Noise(9)
            let c = CGPoint(x: r.midX, y: r.midY), base = min(r.width, r.height) / 2
            for i in 0...28 {
                let a = Double(i) / 28 * 2 * .pi
                let rad = base * (0.9 + n.next() * 0.1)
                let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }
    }
}

/// Double-ruled border with little corner leaves, like the front of a storybook invitation.
private struct InvitationFrame: ViewModifier {
    var color: Color

    func body(content: Content) -> some View {
        let shape = PaperShape(radius: 12, wobble: 1.6, seed: 33)
        content
            .padding(.horizontal, 22).padding(.vertical, 26)
            .background(shape.fill(Color.paper)
                .shadow(color: Color.choco.opacity(0.14), radius: 0.5, y: 1)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5))
            .overlay(RoundedRectangle(cornerRadius: 8).inset(by: 9).stroke(color.opacity(0.75), lineWidth: 1.4))
            .overlay(RoundedRectangle(cornerRadius: 6).inset(by: 13).stroke(color.opacity(0.4), lineWidth: 0.8))
            .overlay(alignment: .topLeading) { corner.padding(4) }
            .overlay(alignment: .topTrailing) { corner.scaleEffect(x: -1).padding(4) }
            .overlay(alignment: .bottomLeading) { corner.scaleEffect(y: -1).padding(4) }
            .overlay(alignment: .bottomTrailing) { corner.scaleEffect(x: -1, y: -1).padding(4) }
    }

    private var corner: some View {
        Image(systemName: "leaf.fill").font(.system(size: 11)).foregroundStyle(color)
            .rotationEffect(.degrees(-45))
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }
}

extension View {
    func invitation(_ color: Color = .grassDark) -> some View { modifier(InvitationFrame(color: color)) }

    /// Serif title in the navigation bar instead of the system one.
    func storyNavTitle(_ title: String) -> some View {
        navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    StoryHeading(text: title, size: 19).foregroundStyle(Color.ink)
                }
            }
    }
}

/// Section header for paper forms: small serif caps with a pencil tick.
struct StorySectionHeader: View {
    let text: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(Color.grassDark) }
            Text(text).font(.story(14, .bold)).foregroundStyle(Color.ink).textCase(nil)
        }
        .padding(.bottom, 2)
    }
}
