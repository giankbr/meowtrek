import SwiftUI
import UIKit

typealias UnitPoint2 = (CGFloat, CGFloat) -> CGPoint

/// A path described in a 0…100 box that stretches to whatever frame it is given.
struct UPath: Shape {
    let build: @Sendable (inout Path, UnitPoint2) -> Void

    init(_ build: @escaping @Sendable (inout Path, UnitPoint2) -> Void) { self.build = build }

    func path(in r: CGRect) -> Path {
        var p = Path()
        build(&p) { x, y in CGPoint(x: r.minX + x / 100 * r.width, y: r.minY + y / 100 * r.height) }
        return p
    }
}

func oval(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> UPath {
    UPath { p, pt in
        let a = pt(cx - w / 2, cy - h / 2), b = pt(cx + w / 2, cy + h / 2)
        p.addEllipse(in: CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y))
    }
}

func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> UPath {
    UPath { p, pt in
        let a = pt(x, y), b = pt(x + w, y + h)
        let k = (b.x - a.x) / w
        p.addRoundedRect(in: CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y),
                         cornerSize: CGSize(width: r * k, height: r * k), style: .continuous)
    }
}

func poly(_ pts: [(CGFloat, CGFloat)], closed: Bool = true) -> UPath {
    UPath { p, pt in
        guard let f = pts.first else { return }
        p.move(to: pt(f.0, f.1))
        for q in pts.dropFirst() { p.addLine(to: pt(q.0, q.1)) }
        if closed { p.closeSubpath() }
    }
}

func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, points: Int = 5) -> UPath {
    let pts: [(CGFloat, CGFloat)] = (0..<(points * 2)).map { i in
        let a = Double(i) * .pi / Double(points) - .pi / 2
        let rr = i.isMultiple(of: 2) ? r : r * 0.45
        return (cx + CGFloat(cos(a)) * rr, cy + CGFloat(sin(a)) * rr)
    }
    return poly(pts)
}

func arc(_ from: (CGFloat, CGFloat), _ to: (CGFloat, CGFloat), via c: (CGFloat, CGFloat)) -> UPath {
    UPath { p, pt in
        p.move(to: pt(from.0, from.1))
        p.addQuadCurve(to: pt(to.0, to.1), control: pt(c.0, c.1))
    }
}

extension Shape {
    /// Soft illustration style: fill plus a thin outline in a deeper shade of the same colour.
    func sticker(_ color: Color, _ w: CGFloat = 3) -> some View {
        ZStack {
            fill(color)
            stroke(color.darker(0.28).opacity(0.9), style: StrokeStyle(lineWidth: w * 0.55, lineCap: .round, lineJoin: .round))
        }
    }

    func line(_ w: CGFloat = 3, _ color: Color = .ink) -> some View {
        stroke(color, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
    }

    func tube(_ color: Color, _ w: CGFloat) -> some View {
        ZStack {
            stroke(color.darker(0.28), style: StrokeStyle(lineWidth: w + 2, lineCap: .round, lineJoin: .round))
            stroke(color, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
    }
}

/// Every collectible, treat, token and scene prop is drawn here in one sticker style.
struct ArtView: View {
    let id: String
    var size: CGFloat = 44
    var line: CGFloat? = nil
    var tint: Color? = nil

    var body: some View {
        if let img = ArtImages.image(id) {
            Image(uiImage: img).resizable().interpolation(.high).scaledToFit()
                .frame(width: size, height: size)
        } else {
            Art.draw(id, w: line ?? max(1.6, size / 20), s: size, tint: tint)
                .frame(width: size, height: size)
        }
    }
}

/// Illustrated PNGs from Shared/Art.xcassets win over the vector fallback when present.
enum ArtImages {
    static func image(_ id: String) -> UIImage? {
        let name = id.hasPrefix("fur_") ? "cat_\(id)" : id
        return UIImage(named: name)
    }
}

enum Art {
    static func draw(_ id: String, w: CGFloat, s: CGFloat, tint: Color?) -> AnyView {
        let t = s / 100
        switch id {
        // MARK: Hats
        case "witch_hat":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(26, 76))
                    p.addLine(to: pt(46, 30))
                    p.addQuadCurve(to: pt(84, 12), control: pt(56, 8))
                    p.addQuadCurve(to: pt(62, 40), control: pt(66, 24))
                    p.addLine(to: pt(74, 76))
                    p.closeSubpath()
                }.sticker(.grape, w)
                rrect(28, 60, 44, 11, 3).sticker(.sun, w)
                oval(50, 79, 98, 22).sticker(.grapeDark, w)
                star(50, 44, 7).sticker(.sun, w * 0.7)
            })
        case "top_hat":
            return AnyView(ZStack {
                rrect(24, 18, 52, 64, 8).sticker(.coal, w)
                rrect(24, 60, 52, 11, 2).sticker(.tomato, w)
                oval(50, 82, 94, 18).sticker(.coal, w)
                rrect(32, 24, 6, 30, 3).fill(.white.opacity(0.25))
            })
        case "crown":
            return AnyView(ZStack {
                poly([(12, 80), (12, 34), (31, 56), (50, 22), (69, 56), (88, 34), (88, 80)]).sticker(.sun, w)
                rrect(12, 70, 76, 10, 2).sticker(.sunDark, w)
                oval(50, 58, 13, 13).sticker(.tomato, w * 0.8)
                oval(28, 64, 9, 9).sticker(.sky, w * 0.8)
                oval(72, 64, 9, 9).sticker(.grass, w * 0.8)
                ForEach([(12.0, 32.0), (50.0, 20.0), (88.0, 32.0)], id: \.0) { x, y in
                    oval(x, y, 9, 9).sticker(.sun, w * 0.8)
                }
            })
        case "bow":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(50, 52)); p.addQuadCurve(to: pt(10, 26), control: pt(30, 14))
                    p.addLine(to: pt(10, 76)); p.addQuadCurve(to: pt(50, 52), control: pt(30, 84))
                }.sticker(.bubble, w)
                UPath { p, pt in
                    p.move(to: pt(50, 52)); p.addQuadCurve(to: pt(90, 26), control: pt(70, 14))
                    p.addLine(to: pt(90, 76)); p.addQuadCurve(to: pt(50, 52), control: pt(70, 84))
                }.sticker(.bubble, w)
                oval(50, 52, 20, 22).sticker(.bubble.darker(0.08), w)
                oval(24, 40, 8, 8).fill(.white.opacity(0.6))
            })
        case "grad_cap":
            return AnyView(ZStack {
                rrect(30, 46, 40, 26, 8).sticker(.coal, w)
                poly([(50, 24), (94, 40), (50, 56), (6, 40)]).sticker(.coal, w)
                poly([(50, 40), (80, 46), (82, 70)], closed: false).line(w * 1.3, .sun)
                oval(82, 72, 9, 12).sticker(.sun, w * 0.8)
            })
        case "sun_hat":
            return AnyView(ZStack {
                oval(50, 54, 56, 48).sticker(Color(hex: 0xF2CF83), w)
                rrect(23, 54, 54, 10, 4).sticker(.tomato, w)
                oval(50, 72, 100, 28).sticker(Color(hex: 0xF2CF83), w)
                oval(70, 52, 14, 14).sticker(.bubble, w * 0.8)
            })
        case "cap":
            return AnyView(ZStack {
                oval(78, 70, 46, 14).sticker(.skyDark, w)
                UPath { p, pt in
                    p.move(to: pt(16, 72)); p.addQuadCurve(to: pt(82, 72), control: pt(48, 8))
                    p.closeSubpath()
                }.sticker(.sky, w)
                oval(48, 34, 9, 6).sticker(.skyDark, w * 0.7)
            })
        case "mushroom":
            return AnyView(ZStack {
                oval(50, 66, 80, 14).sticker(.cream, w)
                UPath { p, pt in
                    p.move(to: pt(6, 66)); p.addQuadCurve(to: pt(94, 66), control: pt(50, -12))
                    p.closeSubpath()
                }.sticker(.tomato, w)
                oval(32, 44, 16, 12).sticker(.white, w * 0.7)
                oval(58, 30, 13, 10).sticker(.white, w * 0.7)
                oval(74, 52, 11, 9).sticker(.white, w * 0.7)
            })
        case "pumpkin_head":
            return AnyView(ZStack {
                rrect(45, 14, 10, 18, 3).sticker(.grassDark, w)
                oval(64, 22, 20, 10).sticker(.grass, w * 0.8)
                oval(30, 58, 42, 50).sticker(.pumpkin, w)
                oval(70, 58, 42, 50).sticker(.pumpkin, w)
                oval(50, 57, 44, 54).sticker(.pumpkin.darker(0.04), w)
                poly([(36, 52), (42, 44), (46, 52)]).fill(Color.ink)
                poly([(54, 52), (58, 44), (64, 52)]).fill(Color.ink)
                arc((38, 66), (62, 66), via: (50, 76)).line(w)
            })
        case "snowman_hat":
            return AnyView(ZStack {
                oval(50, 62, 74, 66).sticker(.sky, w)
                arc((30, 46), (30, 66), via: (36, 56)).line(w * 0.8, .white.opacity(0.7))
                rrect(12, 62, 76, 18, 9).sticker(.white, w)
                oval(50, 24, 24, 24).sticker(.white, w)
            })
        case "flower_crown":
            return AnyView(ZStack {
                oval(50, 72, 84, 24).line(w * 1.4, .grassDark)
                ForEach(Array([(14.0, 68.0), (32.0, 62.0), (50.0, 60.0), (68.0, 62.0), (86.0, 68.0)].enumerated()), id: \.offset) { i, f in
                    ZStack {
                        star(f.0, f.1, 11, points: 5).sticker([Color.bubble, .sun, .white, .sun, .bubble][i], w * 0.8)
                        oval(f.0, f.1, 6, 6).fill(i == 2 ? Color.sun : .white)
                    }
                }
            })

        // MARK: Eyes (lenses sit at x 28 and 72)
        case "glasses":
            return AnyView(ZStack {
                arc((44, 48), (56, 48), via: (50, 42)).line(w)
                poly([(12, 46), (2, 40)], closed: false).line(w)
                poly([(88, 46), (98, 40)], closed: false).line(w)
                oval(28, 50, 32, 32).sticker(.white.opacity(0.3), w * 1.2)
                oval(72, 50, 32, 32).sticker(.white.opacity(0.3), w * 1.2)
            })
        case "shades":
            return AnyView(ZStack {
                poly([(44, 46), (56, 46)], closed: false).line(w)
                rrect(10, 38, 36, 24, 9).sticker(.coal, w)
                rrect(54, 38, 36, 24, 9).sticker(.coal, w)
                arc((16, 46), (26, 42), via: (19, 42)).line(w * 0.8, .white.opacity(0.7))
                arc((60, 46), (70, 42), via: (63, 42)).line(w * 0.8, .white.opacity(0.7))
            })
        case "goggles":
            return AnyView(ZStack {
                rrect(0, 43, 100, 12, 5).sticker(.tomato, w)
                oval(28, 50, 36, 36).sticker(.coal, w)
                oval(72, 50, 36, 36).sticker(.coal, w)
                oval(28, 50, 24, 24).fill(Color.sky.opacity(0.85))
                oval(72, 50, 24, 24).fill(Color.sky.opacity(0.85))
            })
        case "dive_mask":
            return AnyView(ZStack {
                UPath { p, pt in p.move(to: pt(90, 46)); p.addQuadCurve(to: pt(94, 6), control: pt(100, 30)) }.tube(.sun, 4 * t)
                rrect(8, 32, 84, 36, 16).sticker(.sky.opacity(0.55), w * 1.2)
                rrect(8, 32, 84, 8, 4).fill(Color.skyDark.opacity(0.5))
            })

        // MARK: Neck
        case "scarf":
            return AnyView(ZStack {
                poly([(56, 50), (76, 50), (72, 88), (54, 86)]).sticker(.tomato, w)
                rrect(8, 38, 84, 20, 10).sticker(.tomato, w)
                ForEach([24.0, 44.0, 64.0], id: \.self) { x in rrect(x, 40, 6, 16, 2).fill(.white.opacity(0.85)) }
            })
        case "bell":
            return AnyView(ZStack {
                rrect(10, 36, 80, 13, 6).sticker(.tomato, w)
                oval(50, 62, 26, 26).sticker(.sun, w)
                poly([(50, 64), (50, 74)], closed: false).line(w * 0.8)
                oval(50, 64, 6, 6).fill(Color.ink)
            })
        case "beads":
            return AnyView(ZStack {
                ForEach(Array(stride(from: 12.0, through: 88.0, by: 12.67).enumerated()), id: \.offset) { i, x in
                    oval(x, 44 + (1 - pow((x - 50) / 38, 2)) * 14, 13, 13)
                        .sticker([Color.sky, .bubble, .sun][i % 3], w * 0.7)
                }
            })
        case "medal":
            return AnyView(ZStack {
                poly([(34, 20), (50, 54), (66, 20), (56, 20), (50, 34), (44, 20)]).sticker(.sky, w)
                oval(50, 64, 32, 32).sticker(.sun, w)
                star(50, 64, 9).sticker(.sunDark, w * 0.6)
            })
        case "swim_ring":
            return AnyView(ZStack {
                oval(50, 50, 92, 46).tube(.tomato, 16 * t)
                ForEach([18.0, 82.0], id: \.self) { x in rrect(x - 4, 40, 8, 20, 3).fill(.white) }
            })

        // MARK: Hand items (held around x 62, y 60)
        case "wand":
            return AnyView(ZStack {
                poly([(64, 66), (32, 24)], closed: false).tube(.choco, 5 * t)
                star(28, 18, 16).sticker(.sun, w)
                oval(42, 10, 5, 5).fill(Color.white)
            })
        case "lantern":
            return AnyView(ZStack {
                arc((40, 22), (60, 22), via: (50, 2)).line(w)
                oval(50, 52, 46, 54).sticker(.tomato, w)
                ForEach([40.0, 50.0, 60.0], id: \.self) { x in
                    arc((x, 28), (x, 76), via: (x + (x - 50) * 0.6, 52)).line(w * 0.6, .ink.opacity(0.5))
                }
                rrect(37, 22, 26, 8, 3).sticker(.sun, w * 0.8)
                rrect(37, 74, 26, 8, 3).sticker(.sun, w * 0.8)
            })
        case "lollipop":
            return AnyView(ZStack {
                poly([(64, 66), (46, 38)], closed: false).tube(.white, 5 * t)
                oval(40, 28, 44, 44).sticker(.bubble, w)
                UPath { p, pt in
                    p.move(to: pt(40, 28))
                    p.addQuadCurve(to: pt(50, 28), control: pt(45, 20))
                    p.addQuadCurve(to: pt(32, 30), control: pt(44, 42))
                    p.addQuadCurve(to: pt(52, 20), control: pt(30, 10))
                }.line(w * 1.1, .white)
            })
        case "balloon":
            return AnyView(ZStack {
                arc((62, 66), (36, 46), via: (40, 62)).line(w * 0.7)
                poly([(33, 46), (39, 46), (36, 40)]).sticker(.tomato, w * 0.7)
                oval(36, 22, 40, 44).sticker(.tomato, w)
                oval(28, 14, 8, 12).fill(.white.opacity(0.6))
            })
        case "tulip":
            return AnyView(ZStack {
                arc((62, 66), (48, 30), via: (60, 44)).tube(.grass, 4 * t)
                oval(62, 46, 20, 9).sticker(.grass, w * 0.8)
                poly([(34, 30), (36, 8), (44, 18), (50, 6), (56, 18), (64, 8), (66, 30)]).sticker(.bubble, w)
                oval(50, 30, 32, 20).sticker(.bubble, w)
            })
        case "candy_bag":
            return AnyView(ZStack {
                arc((26, 50), (74, 50), via: (50, 6)).line(w * 1.2)
                oval(42, 38, 12, 12).sticker(.bubble, w * 0.7)
                oval(56, 34, 12, 12).sticker(.sky, w * 0.7)
                oval(50, 62, 58, 48).sticker(.pumpkin, w)
                poly([(36, 58), (42, 50), (46, 58)]).fill(Color.ink)
                poly([(54, 58), (58, 50), (64, 58)]).fill(Color.ink)
                arc((38, 70), (62, 70), via: (50, 80)).line(w)
            })
        case "mittens":
            return AnyView(ZStack {
                oval(34, 50, 18, 26).sticker(.sky, w)
                rrect(38, 26, 34, 48, 16).sticker(.sky, w)
                rrect(36, 68, 38, 14, 5).sticker(.white, w)
                oval(55, 44, 10, 10).fill(.white.opacity(0.8))
            })
        case "bouquet":
            return AnyView(ZStack {
                oval(36, 30, 20, 20).sticker(.bubble, w)
                oval(52, 22, 20, 20).sticker(.sun, w)
                oval(66, 34, 18, 18).sticker(.tomato, w)
                oval(28, 44, 14, 10).sticker(.grass, w * 0.8)
                poly([(50, 94), (26, 40), (74, 40)]).sticker(.cream, w)
                poly([(38, 56), (62, 56)], closed: false).line(w, .bubble)
            })

        // MARK: Bags
        case "backpack":
            return AnyView(ZStack {
                rrect(20, 16, 60, 74, 18).sticker(.grass, w)
                rrect(20, 16, 60, 26, 14).sticker(.grassDark, w)
                rrect(30, 54, 40, 26, 8).sticker(.grassLight, w)
                oval(50, 42, 8, 8).sticker(.sun, w * 0.7)
            })
        case "purse":
            return AnyView(ZStack {
                arc((26, 48), (74, 48), via: (50, -6)).line(w * 1.4, .choco)
                rrect(14, 42, 72, 44, 16).sticker(.bubble, w)
                oval(50, 46, 12, 12).sticker(.sun, w)
            })
        case "basket":
            return AnyView(ZStack {
                arc((18, 48), (82, 48), via: (50, -4)).tube(Color(hex: 0xD9A45B), 5 * t)
                poly([(10, 44), (90, 44), (78, 88), (22, 88)]).sticker(Color(hex: 0xE3B26A), w)
                ForEach([58.0, 72.0], id: \.self) { y in
                    poly([(14 + (y - 44) * 0.25, y), (86 - (y - 44) * 0.25, y)], closed: false).line(w * 0.6, .choco)
                }
                rrect(8, 40, 84, 9, 4).sticker(Color(hex: 0xC98D3F), w)
            })
        case "bat_wings":
            return AnyView(ZStack {
                poly([(46, 40), (4, 16), (12, 42), (0, 56), (18, 56), (16, 72), (46, 58)]).sticker(.coal, w)
                poly([(54, 40), (96, 16), (88, 42), (100, 56), (82, 56), (84, 72), (54, 58)]).sticker(.coal, w)
            })
        case "butterfly":
            return AnyView(ZStack {
                oval(30, 38, 38, 44).sticker(.sky, w)
                oval(70, 38, 38, 44).sticker(.sky, w)
                oval(32, 66, 28, 28).sticker(.bubble, w)
                oval(68, 66, 28, 28).sticker(.bubble, w)
                rrect(46, 30, 8, 46, 4).sticker(.coal, w * 0.8)
            })

        // MARK: Shoes (one shoe, toe to the right)
        case "sneakers":
            return AnyView(ZStack {
                rrect(10, 32, 80, 42, 20).sticker(.tomato, w)
                rrect(6, 64, 88, 16, 8).sticker(.white, w)
                ForEach([34.0, 46.0], id: \.self) { x in poly([(x, 40), (x + 8, 48)], closed: false).line(w * 0.8, .white) }
            })
        case "boots":
            return AnyView(ZStack {
                rrect(22, 6, 46, 62, 12).sticker(.choco, w)
                rrect(12, 44, 80, 34, 16).sticker(.choco, w)
                rrect(10, 70, 84, 12, 6).sticker(.coal, w)
                rrect(22, 6, 46, 12, 6).sticker(.choco.darker(0.1), w)
            })
        case "ballet":
            return AnyView(ZStack {
                poly([(36, 42), (48, 8)], closed: false).line(w * 1.2, .bubble)
                poly([(62, 42), (50, 8)], closed: false).line(w * 1.2, .bubble)
                rrect(8, 38, 84, 40, 20).sticker(.bubble, w)
                oval(50, 44, 12, 8).sticker(.white, w * 0.6)
            })
        case "socks":
            return AnyView(ZStack {
                rrect(14, 6, 50, 64, 14).sticker(.white, w)
                rrect(14, 44, 78, 34, 17).sticker(.white, w)
                rrect(14, 12, 50, 8, 2).fill(Color.tomato)
                rrect(14, 28, 50, 8, 2).fill(Color.tomato)
            })
        case "skates":
            return AnyView(ZStack {
                poly([(10, 90), (90, 90)], closed: false).line(w * 1.4, .coal)
                poly([(30, 76), (30, 90)], closed: false).line(w, .coal)
                poly([(72, 76), (72, 90)], closed: false).line(w, .coal)
                rrect(20, 6, 46, 64, 12).sticker(.white, w)
                rrect(14, 44, 76, 34, 16).sticker(.white, w)
                poly([(30, 20), (52, 20)], closed: false).line(w * 0.8, .sky)
            })
        case "flipflops":
            return AnyView(ZStack {
                oval(50, 70, 92, 24).sticker(.sun, w)
                poly([(28, 66), (50, 46), (72, 66)], closed: false).tube(.tomato, 4 * t)
            })

        // MARK: Furs & suits
        case let fur where fur.hasPrefix("fur_"):
            let c = tint ?? .pumpkin
            return AnyView(ZStack {
                poly([(14, 52), (22, 12), (46, 34)]).sticker(c, w)
                poly([(86, 52), (78, 12), (54, 34)]).sticker(c, w)
                oval(50, 58, 80, 66).sticker(c, w)
                oval(36, 56, 9, 11).fill(Color.ink)
                oval(64, 56, 9, 11).fill(Color.ink)
                oval(50, 68, 6, 4).fill(Color.bubble)
            })
        case "frog_suit", "bear_suit", "witch_cloak", "ghost_sheet":
            let c = tint ?? .grass
            let onesie = poly([(30, 20), (42, 16), (50, 24), (58, 16), (70, 20), (92, 38), (82, 52), (72, 46),
                               (72, 92), (28, 92), (28, 46), (18, 52), (8, 38)])
            return AnyView(ZStack {
                if id == "frog_suit" {
                    ForEach([36.0, 64.0], id: \.self) { x in
                        ZStack {
                            oval(x, 16, 22, 22).sticker(c, w)
                            oval(x, 16, 13, 13).sticker(.white, w * 0.7)
                            oval(x, 17, 6, 6).fill(Color.ink)
                        }
                    }
                }
                if id == "bear_suit" {
                    oval(32, 16, 18, 18).sticker(c, w)
                    oval(68, 16, 18, 18).sticker(c, w)
                }
                onesie.sticker(c, w)
                if id == "witch_cloak" {
                    star(40, 60, 6).fill(Color.sun)
                    star(60, 74, 5).fill(Color.sun)
                    poly([(38, 24), (50, 40), (62, 24)]).sticker(.sun, w * 0.8)
                } else if id == "ghost_sheet" {
                    oval(42, 56, 8, 11).fill(Color.ink)
                    oval(58, 56, 8, 11).fill(Color.ink)
                } else {
                    oval(50, 66, 26, 30).fill(.white.opacity(0.6))
                }
            })

        // MARK: Treats
        case "milk":
            return AnyView(ZStack {
                poly([(28, 32), (50, 10), (72, 32)]).sticker(.sky, w)
                rrect(28, 30, 44, 60, 6).sticker(.white, w)
                rrect(34, 50, 32, 22, 5).sticker(.sky, w * 0.8)
            })
        case "fish":
            return AnyView(ZStack {
                poly([(70, 50), (94, 30), (94, 70)]).sticker(.sky, w)
                oval(44, 50, 66, 40).sticker(.sky, w)
                arc((52, 36), (52, 64), via: (60, 50)).line(w * 0.8)
                oval(26, 46, 9, 9).fill(Color.ink)
            })
        case "sushi":
            return AnyView(ZStack {
                oval(50, 62, 80, 42).sticker(.white, w)
                rrect(12, 32, 76, 26, 13).sticker(Color(hex: 0xFF8A65), w)
                ForEach([30.0, 46.0, 62.0], id: \.self) { x in poly([(x, 36), (x + 8, 54)], closed: false).line(w * 0.7, .white) }
                rrect(40, 28, 20, 48, 3).sticker(Color(hex: 0x2F3B2F), w)
            })
        case "cake":
            return AnyView(ZStack {
                rrect(46, 16, 8, 26, 3).sticker(.sky, w * 0.8)
                oval(50, 12, 10, 14).sticker(.sun, w * 0.7)
                rrect(14, 44, 72, 44, 10).sticker(.bubble, w)
                rrect(14, 40, 72, 16, 8).sticker(.white, w)
                ForEach([28.0, 50.0, 72.0], id: \.self) { x in oval(x, 70, 7, 7).fill(Color.tomato) }
            })
        case "water":
            return AnyView(ZStack {
                poly([(24, 14), (76, 14), (68, 90), (32, 90)]).sticker(.white.opacity(0.9), w)
                poly([(28, 40), (72, 40), (68, 88), (32, 88)]).fill(Color.sky.opacity(0.8))
                arc((28, 40), (72, 40), via: (50, 46)).line(w * 0.7, .white)
                rrect(36, 22, 6, 50, 3).fill(.white.opacity(0.6))
            })
        case "streak_freeze":
            return AnyView(ZStack {
                rrect(16, 16, 68, 68, 18).sticker(.sky.opacity(0.85), w)
                rrect(26, 24, 14, 26, 7).fill(.white.opacity(0.7))
                star(62, 62, 12, points: 6).fill(.white)
            })

        // MARK: Currency & tokens
        case "coin":
            return AnyView(ZStack {
                oval(50, 54, 90, 90).fill(Color.sunDark)
                oval(50, 50, 90, 90).sticker(.sun, w)
                oval(50, 50, 62, 62).line(w * 0.8, .sunDark)
                oval(50, 56, 20, 16).fill(Color.sunDark)
                ForEach([(36.0, 42.0), (46.0, 36.0), (56.0, 36.0), (66.0, 42.0)], id: \.0) { x, y in
                    oval(x - 1, y, 9, 11).fill(Color.sunDark)
                }
            })
        case "gem":
            return AnyView(ZStack {
                poly([(50, 94), (6, 38), (26, 10), (74, 10), (94, 38)]).sticker(Color(hex: 0x5FD1F5), w)
                poly([(6, 38), (94, 38)], closed: false).line(w * 0.7)
                poly([(26, 10), (38, 38), (50, 10), (62, 38), (74, 10)], closed: false).line(w * 0.7)
                poly([(38, 38), (50, 94), (62, 38)], closed: false).line(w * 0.7)
                poly([(30, 18), (34, 30)], closed: false).line(w, .white.opacity(0.8))
            })
        case "chest":
            return AnyView(ZStack {
                rrect(8, 44, 84, 46, 8).sticker(.choco, w)
                rrect(8, 18, 84, 34, 16).sticker(.choco.darker(-0.08), w)
                rrect(8, 44, 84, 9, 2).sticker(.sun, w)
                rrect(40, 40, 20, 22, 5).sticker(.sun, w)
                oval(50, 50, 5, 7).fill(Color.ink)
            })
        case "token_candy":
            return AnyView(ZStack {
                poly([(30, 50), (8, 32), (8, 68)]).sticker(.tomato, w)
                poly([(70, 50), (92, 32), (92, 68)]).sticker(.tomato, w)
                oval(50, 50, 46, 36).sticker(.tomato, w)
                arc((38, 42), (58, 40), via: (46, 34)).line(w * 0.8, .white.opacity(0.8))
            })
        case "token_snow":
            return AnyView(ZStack {
                ForEach([0.0, 60.0, 120.0], id: \.self) { a in
                    poly([(50, 8), (50, 92)], closed: false).tube(.white, 6 * t).rotationEffect(.degrees(a))
                }
                oval(50, 50, 16, 16).sticker(.sky, w * 0.7)
            })
        case "token_petal":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(50, 8)); p.addQuadCurve(to: pt(50, 92), control: pt(96, 46))
                    p.addQuadCurve(to: pt(50, 8), control: pt(4, 46))
                }.sticker(.bubble, w)
                arc((50, 24), (50, 80), via: (56, 50)).line(w * 0.7, .white.opacity(0.7))
            })
        case "token_shell":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(50, 88)); p.addLine(to: pt(8, 44))
                    p.addQuadCurve(to: pt(92, 44), control: pt(50, -10)); p.closeSubpath()
                }.sticker(Color(hex: 0xFFB38A), w)
                ForEach([30.0, 50.0, 70.0], id: \.self) { x in poly([(50, 84), (x, 20)], closed: false).line(w * 0.7) }
            })

        // MARK: Scene props
        case "deco_tree":
            return AnyView(ZStack {
                rrect(43, 56, 14, 40, 5).sticker(.choco, w)
                oval(50, 38, 76, 66).sticker(.grass, w)
                oval(34, 26, 20, 12).fill(Color.grassLight)
            })
        case "deco_pine":
            return AnyView(ZStack {
                rrect(44, 74, 12, 22, 4).sticker(.choco, w)
                poly([(50, 30), (86, 80), (14, 80)]).sticker(.grassDark, w)
                poly([(50, 4), (78, 50), (22, 50)]).sticker(.grassDark, w)
                star(50, 6, 7).fill(Color.sun)
            })
        case "deco_bush":
            return AnyView(ZStack {
                oval(28, 70, 46, 40).sticker(.grass, w)
                oval(72, 72, 44, 36).sticker(.grass, w)
                oval(50, 60, 56, 50).sticker(.grass, w)
                oval(42, 50, 7, 7).fill(Color.bubble)
                oval(62, 62, 7, 7).fill(Color.sun)
            })
        case "deco_snowman":
            return AnyView(ZStack {
                oval(50, 72, 54, 46).sticker(.white, w)
                oval(50, 36, 38, 36).sticker(.white, w)
                poly([(50, 38), (68, 42), (50, 44)]).sticker(.pumpkin, w * 0.6)
                oval(43, 32, 5, 5).fill(Color.ink)
                oval(57, 32, 5, 5).fill(Color.ink)
                rrect(36, 6, 28, 16, 3).sticker(.coal, w)
                rrect(30, 18, 40, 6, 3).sticker(.coal, w)
            })
        case "deco_sunflower":
            return AnyView(ZStack {
                rrect(46, 44, 8, 52, 4).sticker(.grass, w)
                oval(64, 70, 22, 10).sticker(.grass, w * 0.8)
                star(50, 30, 30, points: 9).sticker(.sun, w)
                oval(50, 30, 26, 26).sticker(.choco, w)
            })
        case "deco_lamp":
            return AnyView(ZStack {
                oval(50, 20, 60, 60).fill(Color.sun.opacity(0.25))
                rrect(46, 30, 8, 66, 3).sticker(.coal, w)
                rrect(36, 8, 28, 26, 8).sticker(.sun, w)
                rrect(32, 4, 36, 8, 4).sticker(.coal, w)
            })
        case "deco_bat":
            return AnyView(ZStack {
                poly([(46, 50), (8, 34), (16, 54), (6, 66), (46, 60)]).sticker(.coal, w)
                poly([(54, 50), (92, 34), (84, 54), (94, 66), (54, 60)]).sticker(.coal, w)
                oval(50, 54, 18, 20).sticker(.coal, w)
                oval(46, 52, 4, 4).fill(Color.sun)
                oval(54, 52, 4, 4).fill(Color.sun)
            })
        case "deco_cloud":
            return AnyView(ZStack {
                oval(32, 60, 40, 32).sticker(.white, w)
                oval(66, 58, 44, 36).sticker(.white, w)
                oval(50, 46, 44, 40).sticker(.white, w)
                rrect(20, 58, 64, 18, 9).fill(.white)
            })
        default:
            return WardrobeArt.draw(id, w: w, s: s, tint: tint) ?? AnyView(star(50, 50, 40).sticker(.sun, w))
        }
    }
}

/// SF Symbol on a soft tinted disc — used for quests, landmarks and badges.
struct GameIcon: View {
    let symbol: String
    var tint: Color = .grass
    var size: CGFloat = 44
    var muted = false

    var body: some View {
        let c = muted ? Color.inkSoft : tint
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(c)
            .frame(width: size, height: size)
            .background(Circle().fill(c.opacity(0.16)))
    }
}
