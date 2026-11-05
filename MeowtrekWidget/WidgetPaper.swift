import SwiftUI

/// Storybook paper bits for the widget, drawn once per timeline entry.
extension Font {
    static func page(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct WidgetPaperBackground: View {
    var body: some View {
        ZStack {
            Color.cream
            Canvas { ctx, size in
                var seed: UInt64 = 0x9E37_79B9
                func next() -> CGFloat {
                    seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    return CGFloat((seed >> 33) % 10_000) / 10_000
                }
                for _ in 0..<Int(size.width * size.height / 900) {
                    let d = 0.6 + next() * 1.2
                    ctx.fill(Path(ellipseIn: CGRect(x: next() * size.width, y: next() * size.height, width: d, height: d)),
                             with: .color(Color.choco.opacity(0.05 + Double(next()) * 0.05)))
                }
            }
        }
    }
}

/// Crayon-stroke progress bar.
struct CrayonBar: View {
    let value: Double
    var color: Color = .leaf
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule().fill(color)
                    .overlay(Strokes().stroke(Color.white.opacity(0.32), lineWidth: 1).clipShape(Capsule()))
                    .frame(width: max(value > 0 ? height : 0, g.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: height)
    }

    private struct Strokes: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path(), x = r.minX - r.height
            while x < r.maxX {
                p.move(to: CGPoint(x: x, y: r.maxY))
                p.addLine(to: CGPoint(x: x + r.height, y: r.minY))
                x += 4
            }
            return p
        }
    }
}

/// Dotted pencil box behind the widget's buttons.
struct PencilBox: View {
    var tint: Color
    var enabled = true

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint.opacity(enabled ? 0.2 : 0.07))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(enabled ? 0.7 : 0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])))
    }
}

/// Small crooked rubber stamp for finished quests.
struct InkStamp: View {
    let text: String
    var color: Color = .leafDark

    var body: some View {
        Text(text.uppercased())
            .font(.page(9, .heavy)).kerning(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 1.2))
            .rotationEffect(.degrees(-10))
            .opacity(0.85)
    }
}
