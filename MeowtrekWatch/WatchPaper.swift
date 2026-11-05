import SwiftUI

/// Storybook touches for the small screen: bookish numbers and a crayon bar.
extension Font {
    static func page(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

struct WatchCrayonBar: View {
    let value: Double
    var color: Color = .grass

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.cream.opacity(0.18))
                Capsule().fill(color)
                    .overlay(Strokes().stroke(Color.white.opacity(0.3), lineWidth: 1).clipShape(Capsule()))
                    .frame(width: max(value > 0 ? 8 : 0, g.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
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

struct WatchDottedRule: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.5))
                p.addLine(to: CGPoint(x: g.size.width, y: 0.5))
            }
            .stroke(Color.cream.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 3]))
        }
        .frame(height: 1)
    }
}
