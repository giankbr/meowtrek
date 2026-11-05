import SwiftUI

/// Serif section title with a squiggle underline and an optional italic aside.
struct StorySection<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var color: Color = .sun
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 9) {
                StoryHeading(text: title, size: 22, color: color)
                if let subtitle {
                    Text(subtitle).font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension StorySection where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, color: Color = .sun) {
        self.init(title: title, subtitle: subtitle, color: color) { EmptyView() }
    }
}

/// A pencil-dashed wavy rule between parts of a page.
struct InkRule: View {
    var color: Color = .inkSoft

    var body: some View {
        Squiggle()
            .stroke(color.opacity(0.32), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [5, 4]))
            .frame(height: 6)
            .accessibilityHidden(true)
    }
}

/// A small slip of paper, slightly tilted, like a label tucked on a page.
struct PaperLabel: View {
    let text: String
    var color: Color = .sun
    var angle: Double = -3
    var size: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.story(size, .bold))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(PaperShape(radius: 4, wobble: 0.8, seed: text.count + 3).fill(color.opacity(0.55)))
            .overlay(PaperShape(radius: 4, wobble: 0.8, seed: text.count + 3).stroke(Color.ink.opacity(0.08), lineWidth: 1))
            .rotationEffect(.degrees(angle))
    }
}

/// Dashed pencil box with a sketchy icon, for empty states and gentle hints.
struct PencilNote: View {
    let text: String
    var symbol = "pencil.and.scribble"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.inkSoft.opacity(0.7))
            Text(text).font(.story(14, .regular)).italic().foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(PaperShape(radius: 12, wobble: 1, seed: 21).fill(Color.cream.opacity(0.6)))
        .overlay(PaperShape(radius: 12, wobble: 1, seed: 21)
            .stroke(Color.inkSoft.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])))
    }
}

/// Faint ruled lines, like a notebook page.
struct RuledLines: View {
    var spacing: CGFloat = 30
    var color: Color = .sky

    var body: some View {
        Canvas { ctx, size in
            var y = spacing
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(color.opacity(0.18)), lineWidth: 1)
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// Parchment for the trail map: warm wash, faint contour rings and a little compass.
struct MapPaper: View {
    var compass = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xF3EAD3)))
                var n = Noise(77)
                let rings: [(CGFloat, CGFloat)] = [(0.18, 0.12), (0.82, 0.38), (0.25, 0.62), (0.78, 0.86)]
                for (fx, fy) in rings {
                    let c = CGPoint(x: size.width * fx, y: size.height * fy)
                    for k in 1...4 {
                        let r = CGFloat(k) * 22 + n.next() * 8
                        let rect = CGRect(x: c.x - r * 1.3, y: c.y - r * 0.8, width: r * 2.6, height: r * 1.6)
                        ctx.stroke(Path(ellipseIn: rect), with: .color(Color.choco.opacity(0.07)), lineWidth: 1)
                    }
                }
                for _ in 0..<26 {
                    let x = n.next() * size.width, y = n.next() * size.height
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + 5, y: y - 5))
                    p.move(to: CGPoint(x: x + 4, y: y)); p.addLine(to: CGPoint(x: x + 9, y: y - 5))
                    ctx.stroke(p, with: .color(Color.grassDark.opacity(0.12)), lineWidth: 1)
                }
            }
            if compass { Compass().frame(width: 46, height: 46).padding(12).opacity(0.55) }
        }
    }
}

private struct Compass: View {
    var body: some View {
        ZStack {
            Circle().stroke(Color.choco.opacity(0.5), lineWidth: 1.2)
            Circle().inset(by: 5).stroke(Color.choco.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            UPath { p, pt in
                p.move(to: pt(50, 6)); p.addLine(to: pt(58, 50)); p.addLine(to: pt(50, 94)); p.addLine(to: pt(42, 50)); p.closeSubpath()
            }
            .fill(Color.choco.opacity(0.55))
            Text("N").font(.story(9, .heavy)).foregroundStyle(Color.choco).offset(y: -30)
        }
    }
}

/// A hand-inked ring around an icon, for map nodes and badges.
struct InkRing: View {
    var color: Color = .ink
    var seed = 9

    var body: some View {
        PaperShape(radius: 400, wobble: 1.4, seed: seed)
            .stroke(color.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
}

/// A prize ribbon (rosette) for top places on the leaderboard.
struct Rosette: View {
    let rank: Int

    private var color: Color {
        switch rank {
        case 1: .sun
        case 2: Color(hex: 0xC9D3E0)
        case 3: Color(hex: 0xE3A16B)
        default: .paper
        }
    }

    var body: some View {
        ZStack {
            if rank <= 3 {
                HStack(spacing: 2) {
                    ribbon.rotationEffect(.degrees(12))
                    ribbon.rotationEffect(.degrees(-12))
                }
                .offset(y: 13)
            }
            PaperShape(radius: 100, wobble: 1.2, seed: rank + 40).fill(color)
                .overlay(PaperShape(radius: 100, wobble: 1.2, seed: rank + 40).stroke(Color.ink.opacity(0.18), lineWidth: 1))
                .overlay(Circle().inset(by: 4).stroke(Color.ink.opacity(rank <= 3 ? 0.18 : 0), style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                .frame(width: 32, height: 32)
            Text("\(rank)").font(.story(15, .heavy)).foregroundStyle(Color.ink)
        }
        .frame(width: 36, height: 44)
    }

    private var ribbon: some View {
        UPath { p, pt in
            p.move(to: pt(0, 0)); p.addLine(to: pt(100, 0)); p.addLine(to: pt(100, 100))
            p.addLine(to: pt(50, 78)); p.addLine(to: pt(0, 100)); p.closeSubpath()
        }
        .fill(color.darker(0.12))
        .frame(width: 10, height: 18)
    }
}

/// Postage-stamp frame with perforated edges.
struct PostageStamp<Content: View>: View {
    var color: Color = .sky
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(6)
            .background(color.opacity(0.25))
            .padding(4)
            .background(Color.paper)
            .mask {
                Canvas { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                    let r: CGFloat = 2.2, step: CGFloat = 7
                    var x: CGFloat = step / 2
                    while x < size.width {
                        ctx.blendMode = .destinationOut
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: -r, width: r * 2, height: r * 2)), with: .color(.black))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: size.height - r, width: r * 2, height: r * 2)), with: .color(.black))
                        x += step
                    }
                    var y: CGFloat = step / 2
                    while y < size.height {
                        ctx.fill(Path(ellipseIn: CGRect(x: -r, y: y - r, width: r * 2, height: r * 2)), with: .color(.black))
                        ctx.fill(Path(ellipseIn: CGRect(x: size.width - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.black))
                        y += step
                    }
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
    }
}
