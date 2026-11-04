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
                TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate * (pace > 1.5 ? 10 : 6.5)
                    CatCanvas(outfit: outfit, mood: mood, blink: blink, stride: sin(t))
                        .offset(y: -abs(cos(t)) * (pace > 1.5 ? 6 : 3))
                        .rotationEffect(.degrees(pace > 1.5 ? 4 : 1.5), anchor: .bottom)
                }
            } else {
                CatCanvas(outfit: outfit, mood: mood, blink: blink, stride: 0)
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

private struct VectorCat: View {
    let outfit: [Slot: Item]
    let mood: CatMood
    let blink: Bool
    var stride: Double = 0

    /// Lift for the left/right foot during the step cycle.
    private func lift(_ left: Bool) -> CGFloat { CGFloat(max(0, left ? stride : -stride)) * 7 }

    private let line: CGFloat = 3.5
    private let cream = Color(hex: 0xFFF3DE)
    private let pink = Color(hex: 0xFF9FB2)
    private var fur: Color { outfit[.fur]?.hex.map { Color(hex: $0) } ?? Color(hex: 0xF7A453) }
    private var suit: Item? { outfit[.body] }
    private var suitColor: Color { suit?.hex.map { Color(hex: $0) } ?? fur }
    private var hooded: Bool { suit?.suit == .frog || suit?.suit == .bear }
    private static let backBags: Set<String> = ["bat_wings", "butterfly"]

    var body: some View {
        ZStack {
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
            if hooded { hood } else { ears }
            head
            face
            if let eyes = outfit[.eyes] { ArtView(id: eyes.id, size: 124, line: line).position(x: 100, y: 104) }
            if let hat = outfit[.hat] { ArtView(id: hat.id, size: 124, line: line).position(x: 100, y: hooded ? 18 : 30) }
            if let hand = outfit[.hand] { ArtView(id: hand.id, size: 66, line: line).position(x: 38, y: 190) }
        }
    }

    private var tail: some View {
        UPath { p, pt in
            p.move(to: pt(8, 92))
            p.addCurve(to: pt(70, 14), control1: pt(80, 96), control2: pt(96, 40))
        }
        .tube(suit?.suit == .frog || suit?.suit == .bear ? suitColor : fur, 13)
        .frame(width: 64, height: 90)
        .position(x: 166, y: 178)
    }

    @ViewBuilder private var feet: some View {
        if let shoes = outfit[.shoes] {
            ArtView(id: shoes.id, size: 46, line: line).scaleEffect(x: -1).position(x: 76, y: 232 - lift(true))
            ArtView(id: shoes.id, size: 46, line: line).position(x: 124, y: 232 - lift(false))
        } else {
            ForEach([78.0, 122.0], id: \.self) { x in
                ZStack {
                    Ellipse().sticker(fur, line).frame(width: 38, height: 24)
                    HStack(spacing: 5) { ForEach(0..<2) { _ in Capsule().fill(Color.ink).frame(width: 2.5, height: 7) } }
                        .offset(y: 3)
                }
                .position(x: x, y: 234 - lift(x < 100))
            }
        }
    }

    @ViewBuilder private var torso: some View {
        UPath { p, pt in
            p.move(to: pt(50, 0))
            p.addCurve(to: pt(100, 70), control1: pt(86, 0), control2: pt(100, 36))
            p.addCurve(to: pt(50, 100), control1: pt(100, 92), control2: pt(78, 100))
            p.addCurve(to: pt(0, 70), control1: pt(22, 100), control2: pt(0, 92))
            p.addCurve(to: pt(50, 0), control1: pt(0, 36), control2: pt(14, 0))
        }
        .sticker(suitColor, line)
        .frame(width: 104, height: 100)
        .position(x: 100, y: 186)
        if suit?.suit == .cloak {
            ZStack {
                poly([(30, 0), (50, 40), (70, 0)]).sticker(.sun, line * 0.8)
                star(30, 70, 8).fill(Color.sun)
                star(70, 84, 6).fill(Color.sun)
                star(64, 56, 4).fill(Color.white)
            }
            .frame(width: 80, height: 70).position(x: 100, y: 180)
        } else {
            Ellipse().fill(hooded ? Color.white.opacity(0.7) : cream).frame(width: 58, height: 54).position(x: 100, y: 198)
        }
    }

    @ViewBuilder private var arms: some View {
        ForEach([(54.0, 22.0), (146.0, -22.0)], id: \.0) { x, rot in
            ZStack(alignment: .bottom) {
                Capsule().sticker(suitColor, line).frame(width: 24, height: 44)
                Circle().sticker(fur, line).frame(width: 22).offset(y: 4)
            }
            .rotationEffect(.degrees(rot + stride * (x < 100 ? 14 : -14)))
            .position(x: x, y: 182)
        }
    }

    @ViewBuilder private var ears: some View {
        ForEach([(58.0, -12.0), (142.0, 12.0)], id: \.0) { x, rot in
            ZStack {
                UPath { p, pt in
                    p.move(to: pt(0, 100)); p.addLine(to: pt(38, 10))
                    p.addQuadCurve(to: pt(62, 10), control: pt(50, -8))
                    p.addLine(to: pt(100, 100)); p.closeSubpath()
                }.sticker(fur, line)
                UPath { p, pt in
                    p.move(to: pt(22, 100)); p.addLine(to: pt(44, 34))
                    p.addQuadCurve(to: pt(56, 34), control: pt(50, 24))
                    p.addLine(to: pt(78, 100)); p.closeSubpath()
                }.fill(pink)
            }
            .frame(width: 46, height: 54)
            .rotationEffect(.degrees(rot))
            .position(x: x, y: 54)
        }
    }

    @ViewBuilder private var hood: some View {
        Circle().sticker(suitColor, line).frame(width: 172).position(x: 100, y: 100)
        if suit?.suit == .frog {
            ForEach([62.0, 138.0], id: \.self) { x in
                ZStack {
                    Circle().sticker(suitColor, line).frame(width: 50)
                    Circle().sticker(.white, line * 0.8).frame(width: 32)
                    Circle().fill(Color.ink).frame(width: 14).offset(y: 2)
                }
                .position(x: x, y: 30)
            }
        } else {
            ForEach([42.0, 158.0], id: \.self) { x in
                ZStack {
                    Circle().sticker(suitColor, line).frame(width: 44)
                    Circle().fill(Color.black.opacity(0.15)).frame(width: 22)
                }
                .position(x: x, y: 40)
            }
        }
    }

    @ViewBuilder private var head: some View {
        UPath { p, pt in
            p.move(to: pt(50, 0))
            p.addCurve(to: pt(100, 52), control1: pt(84, 0), control2: pt(100, 22))
            p.addCurve(to: pt(50, 100), control1: pt(100, 86), control2: pt(80, 100))
            p.addCurve(to: pt(0, 52), control1: pt(20, 100), control2: pt(0, 86))
            p.addCurve(to: pt(50, 0), control1: pt(0, 22), control2: pt(16, 0))
        }
        .sticker(fur, line)
        .frame(width: 152, height: 124)
        .position(x: 100, y: 104)
        ForEach([86.0, 100.0, 114.0], id: \.self) { x in
            Capsule().fill(Color.black.opacity(0.13)).frame(width: 6, height: x == 100 ? 18 : 13)
                .position(x: x, y: x == 100 ? 55 : 58)
        }
        Ellipse().fill(cream).frame(width: 94, height: 58).position(x: 100, y: 130)
    }

    @ViewBuilder private var face: some View {
        ForEach([72.0, 128.0], id: \.self) { x in eye.position(x: x, y: 106) }
        Ellipse().fill(pink.opacity(0.75)).frame(width: 20, height: 11).position(x: 54, y: 128)
        Ellipse().fill(pink.opacity(0.75)).frame(width: 20, height: 11).position(x: 146, y: 128)
        UPath { p, pt in
            p.move(to: pt(0, 0)); p.addLine(to: pt(100, 0))
            p.addQuadCurve(to: pt(0, 0), control: pt(50, 160))
        }
        .sticker(pink, 2).frame(width: 12, height: 8).position(x: 100, y: 122)
        mouth
        ForEach([(36.0, 132.0, -8.0), (36.0, 140.0, 6.0), (164.0, 132.0, 8.0), (164.0, 140.0, -6.0)], id: \.1) { x, y, r in
            Capsule().fill(Color.ink.opacity(0.55)).frame(width: 16, height: 2).rotationEffect(.degrees(r)).position(x: x, y: y)
        }
        if mood == .hungry {
            UPath { p, pt in
                p.move(to: pt(50, 0)); p.addQuadCurve(to: pt(50, 100), control: pt(110, 80))
                p.addQuadCurve(to: pt(50, 0), control: pt(-10, 80))
            }
            .sticker(.sky, 2).frame(width: 12, height: 18).position(x: 156, y: 84)
        }
    }

    @ViewBuilder private var eye: some View {
        switch mood {
        case .happy:
            arc((0, 90), (100, 90), via: (50, -40)).line(4.5).frame(width: 24, height: 14)
        case .sleepy:
            arc((0, 20), (100, 20), via: (50, 110)).line(4.5).frame(width: 24, height: 12)
        default:
            ZStack {
                Ellipse().fill(Color.ink).frame(width: mood == .hungry ? 30 : 25, height: mood == .hungry ? 34 : 29)
                Circle().fill(.white).frame(width: mood == .hungry ? 12 : 10).offset(x: -5, y: -7)
                Circle().fill(.white).frame(width: 5).offset(x: 5, y: 6)
            }
            .scaleEffect(x: 1, y: blink ? 0.08 : 1)
        }
    }

    @ViewBuilder private var mouth: some View {
        if mood == .happy {
            UPath { p, pt in
                p.move(to: pt(0, 0)); p.addLine(to: pt(100, 0))
                p.addQuadCurve(to: pt(0, 0), control: pt(50, 150))
            }
            .sticker(.tomato, 2.5).frame(width: 18, height: 12).position(x: 100, y: 134)
        } else {
            UPath { p, pt in
                p.move(to: pt(0, 10)); p.addQuadCurve(to: pt(50, 10), control: pt(25, 100))
                p.addQuadCurve(to: pt(100, 10), control: pt(75, 100))
            }
            .line(3).frame(width: 22, height: 10).position(x: 100, y: 132)
        }
    }
}
