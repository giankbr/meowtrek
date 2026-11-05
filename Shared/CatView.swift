import SwiftUI

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            p.closeSubpath()
        }
    }
}

enum CatMood {
    case normal, happy, sleepy, hungry

    init(_ text: String) {
        switch text {
        case "Proud", "Cheerful": self = .happy
        case "Sleepy": self = .sleepy
        case "Hungry": self = .hungry
        default: self = .normal
        }
    }
}

/// Drawn on a fixed 200×250 canvas, then scaled to `size`.
struct CatView: View {
    var outfit: [Slot: Item]
    var size: CGFloat = 200
    var mood: CatMood = .normal
    var hop = 0
    var animated = true
    /// 0 still, ~1 walking, ~2 running. Drives a step cycle only while moving.
    var pace: Double = 0

    @State private var bob = false
    @State private var blink = false
    @State private var lift: CGFloat = 0

    var body: some View {
        Group {
            if pace > 0 && animated {
                TimelineView(.animation(minimumInterval: pace > 1.5 ? 1 / 30 : 1 / 24)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate * (pace > 1.5 ? 10 : 6.5)
                    CatCanvas(outfit: outfit, mood: mood, blink: blink, stride: sin(t))
                        .drawingGroup()
                        .offset(y: -abs(cos(t)) * (pace > 1.5 ? 6 : 3))
                        .rotationEffect(.degrees(pace > 1.5 ? 4 : 1.5), anchor: .bottom)
                }
            } else {
                // Flatten the many vector layers into one Metal-rasterised image so the bob/blink
                // animations composite a single texture instead of dozens of gradient layers.
                CatCanvas(outfit: outfit, mood: mood, blink: blink, stride: 0).drawingGroup()
            }
        }
            .frame(width: 200, height: 250)
            .scaleEffect(x: 1, y: bob ? 1.025 : 0.985, anchor: .bottom)
            .offset(y: lift)
            .animation(animated ? .easeInOut(duration: 1.3).repeatForever(autoreverses: true) : nil, value: bob)
            .scaleEffect(size / 200)
            .frame(width: size, height: size * 1.25)
            .onAppear { if animated { bob = true } }
            .task {
                guard animated else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 2.2...4.5)))
                    withAnimation(.easeIn(duration: 0.06)) { blink = true }
                    try? await Task.sleep(for: .milliseconds(110))
                    withAnimation(.easeOut(duration: 0.08)) { blink = false }
                }
            }
            .onChange(of: hop) {
                withAnimation(.easeOut(duration: 0.16)) { lift = -34 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.42)) { lift = 0 }
                }
            }
    }
}

/// Anchor points (0–1) of the illustrated cat images, measured once on the base pose.
struct CatAnchors: Codable {
    struct P: Codable { let x: Double; let y: Double }
    let headTop: P, headWidth: Double, eyesCenter: P, neck: P, leftPaw: P, rightHip: P, leftFoot: P, rightFoot: P, back: P

    static let shared: CatAnchors? = {
        guard let url = Bundle.main.url(forResource: "cat_anchors", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CatAnchors.self, from: data)
    }()
}

/// Uses the illustrated cat when its PNG and anchors are bundled, otherwise the vector cat.
private struct CatCanvas: View {
    let outfit: [Slot: Item]
    let mood: CatMood
    let blink: Bool
    var stride: Double = 0

    var body: some View {
        let fur = outfit[.fur]?.id ?? "fur_ginger"
        let suit = outfit[.body]?.id
        if let anchors = CatAnchors.shared,
           let base = UIImage(named: suit.map { "cat_\(fur)_\($0)" } ?? "cat_\(fur)") ?? UIImage(named: "cat_\(fur)") {
            IllustratedCat(base: base, outfit: outfit, a: anchors)
        } else {
            VectorCat(outfit: outfit, mood: mood, blink: blink, stride: stride)
        }
    }
}

private struct IllustratedCat: View {
    let base: UIImage
    let outfit: [Slot: Item]
    let a: CatAnchors
    private static let backBags: Set<String> = ["bat_wings", "butterfly"]

    private func pt(_ p: CatAnchors.P) -> CGPoint { CGPoint(x: p.x * 200, y: p.y * 250) }

    var body: some View {
        let head = a.headWidth * 200
        ZStack {
            if let bag = outfit[.bag], Self.backBags.contains(bag.id) {
                ArtView(id: bag.id, size: head * 1.15).position(pt(a.back))
            }
            Image(uiImage: base).resizable().interpolation(.high).frame(width: 200, height: 250)
            if let shoes = outfit[.shoes] {
                ArtView(id: shoes.id, size: head * 0.36).scaleEffect(x: -1).position(pt(a.leftFoot))
                ArtView(id: shoes.id, size: head * 0.36).position(pt(a.rightFoot))
            }
            if let neck = outfit[.neck] { ArtView(id: neck.id, size: head * 0.62).position(pt(a.neck)) }
            if let bag = outfit[.bag], !Self.backBags.contains(bag.id) {
                ArtView(id: bag.id, size: head * 0.45).position(pt(a.rightHip))
            }
            if let eyes = outfit[.eyes] { ArtView(id: eyes.id, size: head * 0.82).position(pt(a.eyesCenter)) }
            if let hat = outfit[.hat] {
                ArtView(id: hat.id, size: head * 0.78)
                    .position(x: a.headTop.x * 200, y: a.headTop.y * 250 - head * 0.05)
            }
            if let hand = outfit[.hand] { ArtView(id: hand.id, size: head * 0.5).position(pt(a.leftPaw)) }
        }
    }
}

/// Nudges curve control points by a fixed, seeded amount so outlines read as hand-inked rather than geometric.
private struct Wobble<S: Shape>: Shape {
    let base: S
    var seed: Double = 1

    func path(in r: CGRect) -> Path {
        let amt = max(0.5, min(r.width, r.height) * 0.014)
        var out = Path()
        var i = 0.0
        func j(_ p: CGPoint) -> CGPoint {
            i += 1
            return CGPoint(x: p.x + CGFloat(sin(i * 12.9898 + seed * 78.233)) * amt,
                           y: p.y + CGFloat(cos(i * 4.1414 + seed * 3.719)) * amt)
        }
        base.path(in: r).forEach { e in
            switch e {
            case .move(let p): out.move(to: p)
            case .line(let p): out.addLine(to: p)
            case .quadCurve(let p, let c): out.addQuadCurve(to: p, control: j(c))
            case .curve(let p, let c1, let c2): out.addCurve(to: p, control1: j(c1), control2: j(c2))
            case .closeSubpath: out.closeSubpath()
            }
        }
        return out
    }
}

/// A shape drawn in the cat's 200×250 canvas coordinates.
private func canvas(_ seed: Double = 1, _ b: @escaping @Sendable (inout Path, UnitPoint2) -> Void) -> Wobble<UPath> {
    Wobble(base: UPath { p, pt in b(&p) { x, y in pt(x / 2, y / 2.5) } }, seed: seed)
}

fileprivate extension Shape {
    /// Fill with soft top-down volume and a lit sheen, then a doubled, slightly offset outline so the line weight varies like a pen.
    func inked(_ color: Color, _ w: CGFloat = 3.5, shade: Bool = true) -> some View {
        let ink = color.darker(0.42).opacity(0.85)
        let style = StrokeStyle(lineWidth: w * 0.6, lineCap: .round, lineJoin: .round)
        return ZStack {
            if shade {
                fill(LinearGradient(colors: [color.lighter(0.13), color, color.darker(0.15)],
                                    startPoint: .top, endPoint: .bottom))
            } else {
                fill(color)
            }
            stroke(ink, style: style)
            stroke(ink, style: style).offset(x: 0.6, y: 0.9)
        }
    }
}

private struct VectorCat: View {
    let outfit: [Slot: Item]
    let mood: CatMood
    let blink: Bool
    var stride: Double = 0

    /// Lift for the left/right foot during the step cycle.
    private func lift(_ left: Bool) -> CGFloat { CGFloat(max(0, left ? stride : -stride)) * 7 }

    private let line: CGFloat = 3.5
    private let cream = Color(hex: 0xFFF4E2)
    private let pink = Color(hex: 0xF4A3AF)
    private let ink = Color(hex: 0x3A2B26)
    private var fur: Color { outfit[.fur]?.hex.map { Color(hex: $0) } ?? Color(hex: 0xF7A453) }
    private var suit: Item? { outfit[.body] }
    private var suitColor: Color { suit?.hex.map { Color(hex: $0) } ?? fur }
    private var hooded: Bool { suit?.suit == .frog || suit?.suit == .bear }
    private static let backBags: Set<String> = ["bat_wings", "butterfly"]

    var body: some View {
        ZStack {
            Ellipse().fill(Color.black.opacity(0.09)).frame(width: 116, height: 18).position(x: 100, y: 241)
            if let bag = outfit[.bag], Self.backBags.contains(bag.id) {
                ArtView(id: bag.id, size: 176, line: line).position(x: 100, y: 176)
            }
            tail
            feet
            torso
            if let neck = outfit[.neck] { ArtView(id: neck.id, size: 92, line: line).position(x: 100, y: 152) }
            arms
            if let bag = outfit[.bag], !Self.backBags.contains(bag.id) {
                ArtView(id: bag.id, size: 62, line: line).position(x: 160, y: 204)
            }
            if hooded { hood } else { ear(false); ear(true) }
            head
            face
            if let eyes = outfit[.eyes] { ArtView(id: eyes.id, size: 124, line: line).position(x: 100, y: 104) }
            if let hat = outfit[.hat] { ArtView(id: hat.id, size: 124, line: line).position(x: 100, y: hooded ? 18 : 30) }
            if let hand = outfit[.hand] { ArtView(id: hand.id, size: 66, line: line).position(x: 38, y: 190) }
        }
    }

    private var tail: some View {
        let t = canvas(3) { p, q in
            p.move(to: q(132, 212))
            p.addCurve(to: q(180, 168), control1: q(166, 218), control2: q(186, 194))
            p.addCurve(to: q(160, 126), control1: q(176, 146), control2: q(160, 142))
        }
        let c = hooded ? suitColor : fur
        return ZStack {
            t.tube(c, 15)
            t.trim(from: 0.56, to: 0.63).stroke(c.darker(0.2), style: StrokeStyle(lineWidth: 14.5, lineCap: .butt))
            t.trim(from: 0.84, to: 1).stroke(c.darker(0.22), style: StrokeStyle(lineWidth: 14.5, lineCap: .round))
        }
        .rotationEffect(.degrees(stride * 5), anchor: UnitPoint(x: 0.66, y: 0.85))
    }

    @ViewBuilder private var feet: some View {
        if let shoes = outfit[.shoes] {
            ArtView(id: shoes.id, size: 46, line: line).scaleEffect(x: -1).position(x: 76, y: 232 - lift(true))
            ArtView(id: shoes.id, size: 46, line: line).position(x: 124, y: 232 - lift(false))
        } else {
            ForEach([80.0, 120.0], id: \.self) { x in
                ZStack {
                    Wobble(base: Ellipse(), seed: x).inked(fur, line, shade: false).frame(width: 36, height: 22)
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in Capsule().fill(fur.darker(0.42)).frame(width: 1.8, height: i == 1 ? 6 : 5) }
                    }
                    .offset(y: 4)
                }
                .position(x: x, y: 235 - lift(x < 100))
            }
        }
    }

    @ViewBuilder private var torso: some View {
        canvas(5) { p, q in
            p.move(to: q(100, 136))
            p.addCurve(to: q(150, 198), control1: q(128, 136), control2: q(146, 168))
            p.addCurve(to: q(100, 232), control1: q(154, 224), control2: q(130, 232))
            p.addCurve(to: q(50, 198), control1: q(70, 232), control2: q(46, 224))
            p.addCurve(to: q(100, 136), control1: q(54, 168), control2: q(72, 136))
        }
        .inked(suitColor, line)
        if suit == nil {
            // Tabby stripes on the undressed body, matching the head and tail markings.
            canvas(8) { p, q in
                p.move(to: q(62, 144)); p.addQuadCurve(to: q(78, 148), control: q(70, 143))
                p.move(to: q(138, 144)); p.addQuadCurve(to: q(122, 148), control: q(130, 143))
                p.move(to: q(58, 158)); p.addQuadCurve(to: q(75, 162), control: q(66, 157))
                p.move(to: q(142, 158)); p.addQuadCurve(to: q(125, 162), control: q(134, 157))
            }
            .line(5, fur.darker(0.16))
        }
        if suit?.suit == .cloak {
            ZStack {
                poly([(30, 0), (50, 40), (70, 0)]).sticker(.sun, line * 0.8)
                star(30, 70, 8).fill(Color.sun)
                star(70, 84, 6).fill(Color.sun)
                star(64, 56, 4).fill(Color.white)
            }
            .frame(width: 80, height: 70).position(x: 100, y: 180)
        } else {
            canvas(7) { p, q in
                p.move(to: q(80, 170))
                p.addQuadCurve(to: q(90, 167), control: q(84, 160))
                p.addQuadCurve(to: q(100, 170), control: q(95, 158))
                p.addQuadCurve(to: q(110, 167), control: q(105, 159))
                p.addQuadCurve(to: q(120, 170), control: q(116, 160))
                p.addCurve(to: q(100, 222), control1: q(126, 192), control2: q(118, 222))
                p.addCurve(to: q(80, 170), control1: q(82, 222), control2: q(74, 192))
            }
            .fill(hooded ? Color.white.opacity(0.7) : cream)
            if let id = suit?.id { SuitOverlay(id: id).frame(width: 104, height: 100).position(x: 100, y: 186) }
        }
        Ellipse().fill(Color.black.opacity(0.07)).frame(width: 84, height: 16).position(x: 100, y: 160)
    }

    @ViewBuilder private var arms: some View {
        ForEach([(56.0, 22.0), (144.0, -22.0)], id: \.0) { x, rot in
            ZStack(alignment: .bottom) {
                Wobble(base: UPath { p, pt in
                    p.move(to: pt(0, 26)); p.addCurve(to: pt(50, 0), control1: pt(0, 11), control2: pt(22, 0))
                    p.addCurve(to: pt(100, 26), control1: pt(78, 0), control2: pt(100, 11)); p.addLine(to: pt(100, 74))
                    p.addCurve(to: pt(50, 100), control1: pt(100, 89), control2: pt(78, 100))
                    p.addCurve(to: pt(0, 74), control1: pt(22, 100), control2: pt(0, 89)); p.closeSubpath()
                }, seed: x).inked(suitColor, line, shade: false).frame(width: 24, height: 46)
                ZStack {
                    Wobble(base: Circle(), seed: x + 1).inked(fur, line, shade: false).frame(width: 22, height: 22)
                    HStack(spacing: 3.5) {
                        ForEach(0..<2) { _ in Capsule().fill(fur.darker(0.42)).frame(width: 1.6, height: 5) }
                    }
                    .offset(y: 5)
                }
                .offset(y: 4)
            }
            .rotationEffect(.degrees(rot + stride * (x < 100 ? 14 : -14)))
            .position(x: x, y: 182)
        }
    }

    /// Wide, soft-tipped ears; the left one carries a small notch, Meowtrek's signature.
    @ViewBuilder private func ear(_ right: Bool) -> some View {
        let m: @Sendable (CGFloat) -> CGFloat = { right ? 200 - $0 : $0 }
        canvas(right ? 11 : 13) { p, q in
            p.move(to: q(m(34), 92))
            p.addCurve(to: q(m(40), 46), control1: q(m(30), 74), control2: q(m(34), 58))
            if !right { p.addLine(to: q(m(47), 43)); p.addLine(to: q(m(45), 35)) }
            p.addCurve(to: q(m(58), 20), control1: q(m(46), 28), control2: q(m(52), 20))
            p.addCurve(to: q(m(96), 66), control1: q(m(68), 22), control2: q(m(84), 44))
            p.closeSubpath()
        }
        .inked(fur, line)
        canvas(right ? 21 : 23) { p, q in
            p.move(to: q(m(48), 80))
            p.addCurve(to: q(m(57), 38), control1: q(m(45), 62), control2: q(m(49), 45))
            p.addCurve(to: q(m(84), 70), control1: q(m(65), 40), control2: q(m(78), 52))
            p.closeSubpath()
        }
        .fill(pink.opacity(0.85))
        canvas(right ? 31 : 33) { p, q in
            p.move(to: q(m(55), 78)); p.addQuadCurve(to: q(m(59), 56), control: q(m(53), 66))
            p.move(to: q(m(63), 80)); p.addQuadCurve(to: q(m(67), 61), control: q(m(63), 70))
        }
        .line(2, cream)
    }

    @ViewBuilder private var hood: some View {
        Wobble(base: Circle(), seed: 41).inked(suitColor, line).frame(width: 172, height: 172).position(x: 100, y: 100)
        if suit?.suit == .frog {
            ForEach([62.0, 138.0], id: \.self) { x in
                ZStack {
                    Wobble(base: Circle(), seed: x).inked(suitColor, line, shade: false).frame(width: 50, height: 50)
                    Wobble(base: Circle(), seed: x + 2).inked(.white, line * 0.8, shade: false).frame(width: 32, height: 32)
                    Circle().fill(ink).frame(width: 13).offset(x: x < 100 ? 2 : -2, y: 3)
                }
                .position(x: x, y: 30)
            }
        } else {
            ForEach([42.0, 158.0], id: \.self) { x in
                ZStack {
                    Wobble(base: Circle(), seed: x).inked(suitColor, line, shade: false).frame(width: 44, height: 44)
                    Circle().fill(Color.black.opacity(0.15)).frame(width: 22)
                }
                .position(x: x, y: 40)
            }
        }
    }

    @ViewBuilder private var head: some View {
        let tufts = !hooded
        canvas(17) { p, q in
            p.move(to: q(100, 46))
            p.addCurve(to: q(166, 80), control1: q(134, 44), control2: q(156, 58))
            p.addCurve(to: q(176, 120), control1: q(174, 94), control2: q(176, 108))
            if tufts {
                p.addQuadCurve(to: q(186, 132), control: q(180, 128))
                p.addQuadCurve(to: q(174, 136), control: q(180, 134))
                p.addQuadCurve(to: q(180, 146), control: q(178, 140))
                p.addQuadCurve(to: q(160, 150), control: q(170, 150))
            } else {
                p.addQuadCurve(to: q(160, 150), control: q(176, 142))
            }
            p.addCurve(to: q(100, 160), control1: q(146, 158), control2: q(124, 160))
            p.addCurve(to: q(40, 150), control1: q(76, 160), control2: q(54, 158))
            if tufts {
                p.addQuadCurve(to: q(20, 146), control: q(30, 150))
                p.addQuadCurve(to: q(26, 136), control: q(22, 140))
                p.addQuadCurve(to: q(14, 132), control: q(20, 134))
                p.addQuadCurve(to: q(24, 120), control: q(20, 128))
            } else {
                p.addQuadCurve(to: q(24, 120), control: q(24, 142))
            }
            p.addCurve(to: q(34, 80), control1: q(24, 108), control2: q(26, 94))
            p.addCurve(to: q(100, 46), control1: q(44, 58), control2: q(66, 44))
        }
        .inked(fur, line)
        canvas(19) { p, q in
            p.move(to: q(89, 57)); p.addQuadCurve(to: q(91, 71), control: q(87, 64))
            p.move(to: q(100, 53)); p.addQuadCurve(to: q(100, 74), control: q(102, 63))
            p.move(to: q(111, 57)); p.addQuadCurve(to: q(109, 71), control: q(113, 64))
            p.move(to: q(28, 100)); p.addQuadCurve(to: q(42, 101), control: q(35, 97))
            p.move(to: q(28, 109)); p.addQuadCurve(to: q(40, 111), control: q(34, 107))
            p.move(to: q(172, 100)); p.addQuadCurve(to: q(158, 101), control: q(165, 97))
            p.move(to: q(172, 109)); p.addQuadCurve(to: q(160, 111), control: q(166, 107))
        }
        .line(4.5, fur.darker(0.16))
        canvas(27) { p, q in
            p.move(to: q(100, 117))
            p.addCurve(to: q(132, 135), control1: q(118, 113), control2: q(132, 121))
            p.addCurve(to: q(100, 153), control1: q(132, 149), control2: q(116, 155))
            p.addCurve(to: q(68, 135), control1: q(84, 155), control2: q(68, 149))
            p.addCurve(to: q(100, 117), control1: q(68, 121), control2: q(82, 113))
        }
        .fill(cream)
    }

    @ViewBuilder private var face: some View {
        ForEach([(74.0, -1.0), (126.0, 1.0)], id: \.0) { x, side in eye(side).position(x: x, y: 108) }
        ForEach([54.0, 146.0], id: \.self) { x in
            ZStack {
                Ellipse().fill(pink.opacity(0.5)).frame(width: 22, height: 11)
                HStack(spacing: 3) {
                    ForEach(0..<3) { _ in Capsule().fill(pink.darker(0.16)).frame(width: 1.5, height: 6).rotationEffect(.degrees(22)) }
                }
            }
            .position(x: x, y: 128)
        }
        canvas(29) { p, q in
            p.move(to: q(94, 121))
            p.addQuadCurve(to: q(106, 121), control: q(100, 117.5))
            p.addQuadCurve(to: q(100, 128), control: q(106, 125))
            p.addQuadCurve(to: q(94, 121), control: q(94, 125))
        }
        .inked(Color(hex: 0xE58593), 2.2, shade: false)
        Circle().fill(.white.opacity(0.65)).frame(width: 3.2).position(x: 97, y: 121.5) // nose shine
        mouth
        ForEach([false, true], id: \.self) { right in
            let m: @Sendable (CGFloat) -> CGFloat = { right ? 200 - $0 : $0 }
            canvas(right ? 37 : 39) { p, q in
                p.move(to: q(m(42), 124)); p.addQuadCurve(to: q(m(16), 118), control: q(m(28), 119))
                p.move(to: q(m(42), 130)); p.addQuadCurve(to: q(m(13), 131), control: q(m(28), 128.5))
                p.move(to: q(m(44), 136)); p.addQuadCurve(to: q(m(20), 144), control: q(m(31), 137))
            }
            .line(1.6, ink.opacity(0.5))
        }
        if mood == .hungry {
            UPath { p, pt in
                p.move(to: pt(50, 0)); p.addQuadCurve(to: pt(50, 100), control: pt(110, 80))
                p.addQuadCurve(to: pt(50, 0), control: pt(-10, 80))
            }
            .sticker(.sky, 2).frame(width: 12, height: 18).position(x: 158, y: 84)
        }
    }

    @ViewBuilder private func eye(_ side: Double) -> some View {
        switch mood {
        case .happy:
            arc((0, 85), (100, 85), via: (50, -35)).line(4, ink).frame(width: 20, height: 12)
        case .sleepy:
            ZStack {
                arc((0, 20), (100, 20), via: (50, 100)).line(4, ink).frame(width: 20, height: 10)
                Capsule().fill(ink).frame(width: 2, height: 5)
                    .rotationEffect(.degrees(side * 30)).offset(x: side * 9, y: 5)
            }
        default:
            let big = mood == .hungry
            ZStack {
                Wobble(base: Ellipse(), seed: side + 50).fill(ink).frame(width: big ? 21 : 16.5, height: big ? 25 : 22)
                // Two catchlights read as a glossy, wet eye.
                Circle().fill(.white).frame(width: big ? 8 : 6.5).offset(x: -3, y: big ? -5.5 : -5)
                Circle().fill(.white).frame(width: big ? 3.5 : 3).offset(x: 3, y: big ? 5 : 4.5)
                Capsule().fill(ink).frame(width: 2.2, height: 6)
                    .rotationEffect(.degrees(side * 55)).offset(x: side * (big ? 11 : 9), y: big ? -9.5 : -8)
            }
            .rotationEffect(.degrees(side * 6))
            .scaleEffect(x: 1, y: blink ? 0.08 : 1)
        }
    }

    @ViewBuilder private var mouth: some View {
        canvas(43) { p, q in p.move(to: q(100, 128)); p.addLine(to: q(100, 131.5)) }.line(2, ink)
        switch mood {
        case .happy:
            canvas(45) { p, q in
                p.move(to: q(92, 132))
                p.addQuadCurve(to: q(108, 132), control: q(100, 130.5))
                p.addQuadCurve(to: q(92, 132), control: q(100, 149))
            }
            .inked(Color(hex: 0xB9525E), 2, shade: false)
            canvas(47) { p, q in
                p.move(to: q(95, 140))
                p.addQuadCurve(to: q(105, 140), control: q(100, 135.5))
                p.addQuadCurve(to: q(95, 140), control: q(100, 143.5))
            }
            .fill(pink)
        case .hungry:
            Wobble(base: Ellipse(), seed: 49).inked(Color(hex: 0xB9525E), 2, shade: false).frame(width: 8, height: 9).position(x: 100, y: 137)
        default:
            canvas(51) { p, q in
                p.move(to: q(91, 131)); p.addQuadCurve(to: q(100, 131.5), control: q(95, 137))
                p.addQuadCurve(to: q(109, 131), control: q(105, 137))
            }
            .line(2.2, ink)
        }
    }
}
