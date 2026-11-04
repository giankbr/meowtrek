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

struct WitchHat: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Triangle().fill(Color(hex: 0x3E3266))
                    .frame(width: w * 0.55, height: h * 0.85)
                    .rotationEffect(.degrees(-8))
                    .position(x: w * 0.5, y: h * 0.45)
                Capsule().fill(Color(hex: 0xF6C945))
                    .frame(width: w * 0.48, height: h * 0.09)
                    .position(x: w / 2, y: h * 0.76)
                Capsule().fill(Color(hex: 0x2E2447))
                    .frame(width: w, height: h * 0.16)
                    .position(x: w / 2, y: h * 0.88)
                Text("☾").font(.system(size: h * 0.22, weight: .bold))
                    .foregroundStyle(Color(hex: 0xF6C945))
                    .position(x: w * 0.47, y: h * 0.5)
            }
        }
    }
}

/// Drawn on a fixed 200×250 canvas, then scaled to `size`.
struct CatView: View {
    var outfit: [Slot: Item]
    var size: CGFloat = 200
    @State private var bob = false

    var body: some View {
        CatCanvas(outfit: outfit)
            .frame(width: 200, height: 250)
            .offset(y: bob ? -3 : 0)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: bob)
            .scaleEffect(size / 200)
            .frame(width: size, height: size * 1.25)
            .onAppear { bob = true }
    }
}

private struct CatCanvas: View {
    let outfit: [Slot: Item]

    private let cream = Color(hex: 0xFFF6E8)
    private let pink = Color(hex: 0xF4A3A8)
    private var fur: Color { outfit[.fur]?.hex.map { Color(hex: $0) } ?? Color(hex: 0xF2A65A) }
    private var suit: Item? { outfit[.body] }
    private var suitColor: Color { suit?.hex.map { Color(hex: $0) } ?? fur }
    private var hooded: Bool { suit?.suit == .frog || suit?.suit == .bear }

    var body: some View {
        ZStack {
            Capsule().fill(suit?.suit == .frog ? suitColor : fur)
                .frame(width: 24, height: 72).rotationEffect(.degrees(35)).position(x: 152, y: 188)

            feet
            torso
            arms

            if let bag = outfit[.bag] { emoji(bag.emoji, 32).position(x: 158, y: 206) }
            if let neck = outfit[.neck] { emoji(neck.emoji, 30).position(x: 100, y: 152) }

            if hooded { hood } else { ears }
            head
            if let eyes = outfit[.eyes] { emoji(eyes.emoji, 54).position(x: 100, y: 104) }
            hat
            if let hand = outfit[.hand] { emoji(hand.emoji, 36).position(x: 42, y: 196) }
        }
    }

    private func emoji(_ s: String, _ size: CGFloat) -> some View {
        Text(s).font(.system(size: size))
    }

    @ViewBuilder private var feet: some View {
        if let shoes = outfit[.shoes] {
            emoji(shoes.emoji, 30).position(x: 76, y: 232)
            emoji(shoes.emoji, 30).scaleEffect(x: -1).position(x: 124, y: 232)
        } else {
            Ellipse().fill(fur).frame(width: 34, height: 20).position(x: 78, y: 232)
            Ellipse().fill(fur).frame(width: 34, height: 20).position(x: 122, y: 232)
        }
    }

    @ViewBuilder private var torso: some View {
        Ellipse().fill(suitColor).frame(width: 104, height: 96).position(x: 100, y: 188)
        if suit?.suit == .cloak {
            Text("✦  ✧\n ✧ ✦").font(.system(size: 12)).foregroundStyle(Color.honey.opacity(0.9))
                .position(x: 100, y: 196)
        } else {
            Ellipse().fill(hooded ? Color.white.opacity(0.75) : cream)
                .frame(width: 58, height: 58).position(x: 100, y: 196)
        }
    }

    @ViewBuilder private var arms: some View {
        Capsule().fill(suitColor).frame(width: 24, height: 44).rotationEffect(.degrees(25)).position(x: 56, y: 180)
        Capsule().fill(suitColor).frame(width: 24, height: 44).rotationEffect(.degrees(-25)).position(x: 144, y: 180)
        Circle().fill(fur).frame(width: 18).position(x: 48, y: 198)
        Circle().fill(fur).frame(width: 18).position(x: 152, y: 198)
    }

    @ViewBuilder private var ears: some View {
        Triangle().fill(fur).frame(width: 40, height: 46).rotationEffect(.degrees(-15)).position(x: 60, y: 50)
        Triangle().fill(fur).frame(width: 40, height: 46).rotationEffect(.degrees(15)).position(x: 140, y: 50)
        Triangle().fill(pink).frame(width: 20, height: 24).rotationEffect(.degrees(-15)).position(x: 61, y: 58)
        Triangle().fill(pink).frame(width: 20, height: 24).rotationEffect(.degrees(15)).position(x: 139, y: 58)
    }

    @ViewBuilder private var hood: some View {
        Circle().fill(suitColor).frame(width: 158).position(x: 100, y: 100)
        if suit?.suit == .frog {
            ForEach([64.0, 136.0], id: \.self) { x in
                ZStack {
                    Circle().fill(suitColor).frame(width: 48)
                    Circle().fill(.white).frame(width: 32)
                    Circle().fill(Color.ink).frame(width: 15)
                }
                .position(x: x, y: 32)
            }
        } else {
            ForEach([48.0, 152.0], id: \.self) { x in
                ZStack {
                    Circle().fill(suitColor).frame(width: 42)
                    Circle().fill(.black.opacity(0.15)).frame(width: 22)
                }
                .position(x: x, y: 42)
            }
        }
    }

    @ViewBuilder private var head: some View {
        Ellipse().fill(fur).frame(width: 140, height: 118).position(x: 100, y: 104)
        ForEach([88.0, 100.0, 112.0], id: \.self) { x in
            Capsule().fill(.black.opacity(0.08)).frame(width: 6, height: 16).position(x: x, y: x == 100 ? 58 : 62)
        }
        Ellipse().fill(cream).frame(width: 92, height: 56).position(x: 100, y: 126)
        ForEach([74.0, 126.0], id: \.self) { x in
            Circle().fill(Color.ink).frame(width: 24).position(x: x, y: 104)
            Circle().fill(.white).frame(width: 8).position(x: x - 5, y: 98)
        }
        Ellipse().fill(pink.opacity(0.55)).frame(width: 18, height: 10).position(x: 58, y: 126)
        Ellipse().fill(pink.opacity(0.55)).frame(width: 18, height: 10).position(x: 142, y: 126)
        Triangle().fill(pink).frame(width: 10, height: 7).rotationEffect(.degrees(180)).position(x: 100, y: 120)
        Text("ω").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.ink).position(x: 100, y: 129)
    }

    @ViewBuilder private var hat: some View {
        if let hat = outfit[.hat] {
            if hat.id == "witch_hat" {
                WitchHat().frame(width: 116, height: 92).position(x: 100, y: 30)
            } else {
                emoji(hat.emoji, 64).position(x: 100, y: hooded ? 26 : 38)
            }
        }
    }
}
