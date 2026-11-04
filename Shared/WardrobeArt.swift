import SwiftUI

/// Vector fallbacks for the second wave of wardrobe items, in the same 0…100 sticker style as `Art`.
enum WardrobeArt {
    static func draw(_ id: String, w: CGFloat, s: CGFloat, tint: Color?) -> AnyView? {
        let t = s / 100
        switch id {
        // MARK: Hats (brim sits around y 75)
        case "beret":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(10, 70)); p.addQuadCurve(to: pt(92, 62), control: pt(40, 14))
                    p.addQuadCurve(to: pt(10, 70), control: pt(60, 84))
                }.sticker(.tomato, w)
                rrect(47, 20, 6, 12, 3).sticker(.tomato.darker(0.1), w * 0.8)
                arc((24, 58), (46, 40), via: (30, 44)).line(w * 0.7, .white.opacity(0.5))
            })
        case "pom_beanie":
            return AnyView(ZStack {
                oval(50, 20, 24, 24).sticker(.white, w)
                UPath { p, pt in
                    p.move(to: pt(16, 72)); p.addQuadCurve(to: pt(84, 72), control: pt(50, 4)); p.closeSubpath()
                }.sticker(.grape, w)
                ForEach([34.0, 50.0, 66.0], id: \.self) { x in
                    poly([(x, 38), (x, 66)], closed: false).line(w * 0.6, .grapeDark.opacity(0.6))
                }
                rrect(12, 64, 76, 16, 8).sticker(.grapeDark, w)
            })
        case "sprout":
            return AnyView(ZStack {
                arc((50, 80), (50, 40), via: (44, 60)).tube(.grass, 4 * t)
                UPath { p, pt in
                    p.move(to: pt(50, 44)); p.addQuadCurve(to: pt(14, 30), control: pt(26, 54))
                    p.addQuadCurve(to: pt(50, 44), control: pt(30, 16))
                }.sticker(.grass, w)
                UPath { p, pt in
                    p.move(to: pt(50, 40)); p.addQuadCurve(to: pt(86, 20), control: pt(76, 44))
                    p.addQuadCurve(to: pt(50, 40), control: pt(62, 10))
                }.sticker(.grassLight, w)
            })
        case "tricorn":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(4, 70)); p.addQuadCurve(to: pt(50, 22), control: pt(16, 26))
                    p.addQuadCurve(to: pt(96, 70), control: pt(84, 26))
                    p.addQuadCurve(to: pt(4, 70), control: pt(50, 86))
                }.sticker(.coal, w)
                arc((14, 64), (86, 64), via: (50, 76)).line(w * 1.2, .sun)
                oval(50, 48, 16, 14).sticker(.white, w * 0.7)
                poly([(44, 58), (56, 50)], closed: false).line(w * 0.7)
                poly([(44, 50), (56, 58)], closed: false).line(w * 0.7)
            })
        case "headphones":
            return AnyView(ZStack {
                arc((16, 70), (84, 70), via: (50, -16)).tube(.coal, 7 * t)
                rrect(4, 54, 24, 34, 10).sticker(.tomato, w)
                rrect(72, 54, 24, 34, 10).sticker(.tomato, w)
                rrect(10, 62, 8, 18, 4).fill(.white.opacity(0.5))
            })
        case "halo":
            return AnyView(ZStack {
                oval(50, 66, 80, 24).tube(.sun, 7 * t)
                arc((22, 60), (40, 56), via: (28, 56)).line(w * 0.7, .white.opacity(0.8))
                star(86, 34, 7).fill(Color.sun)
                star(16, 38, 5).fill(Color.sun)
            })
        case "bucket_hat":
            return AnyView(ZStack {
                poly([(10, 78), (24, 56), (76, 56), (90, 78)]).sticker(Color(hex: 0xE7D3A8), w)
                UPath { p, pt in
                    p.move(to: pt(24, 60)); p.addQuadCurve(to: pt(76, 60), control: pt(50, 10)); p.closeSubpath()
                }.sticker(Color(hex: 0xE7D3A8), w)
                rrect(24, 54, 52, 8, 3).sticker(.grassDark, w * 0.8)
            })
        case "party_hat":
            return AnyView(ZStack {
                poly([(50, 10), (78, 80), (22, 80)]).sticker(.sky, w)
                ForEach([(42.0, 40.0), (58.0, 56.0), (40.0, 66.0)], id: \.1) { x, y in oval(x, y, 7, 7).fill(Color.sun) }
                oval(50, 10, 14, 14).sticker(.bubble, w)
                rrect(20, 76, 60, 7, 3).sticker(.white, w * 0.8)
            })
        case "ranch_hat":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(28, 66)); p.addLine(to: pt(32, 24))
                    p.addQuadCurve(to: pt(50, 30), control: pt(42, 18))
                    p.addQuadCurve(to: pt(68, 24), control: pt(58, 18))
                    p.addLine(to: pt(72, 66)); p.closeSubpath()
                }.sticker(.choco, w)
                rrect(28, 56, 44, 9, 3).sticker(.coal, w * 0.8)
                UPath { p, pt in
                    p.move(to: pt(2, 60)); p.addQuadCurve(to: pt(98, 60), control: pt(50, 96))
                    p.addQuadCurve(to: pt(2, 60), control: pt(50, 74))
                }.sticker(.choco.darker(0.06), w)
            })
        case "straw_hat":
            return AnyView(ZStack {
                oval(50, 72, 100, 26).sticker(Color(hex: 0xF0D27E), w)
                UPath { p, pt in
                    p.move(to: pt(24, 70)); p.addQuadCurve(to: pt(76, 70), control: pt(50, 12)); p.closeSubpath()
                }.sticker(Color(hex: 0xF0D27E), w)
                rrect(25, 58, 50, 10, 4).sticker(.tomato, w)
                ForEach([12.0, 30.0, 70.0, 88.0], id: \.self) { x in
                    poly([(x, 68), (x + 4, 78)], closed: false).line(w * 0.6, .sunDark.opacity(0.7))
                }
            })
        case "earmuffs":
            return AnyView(ZStack {
                arc((14, 70), (86, 70), via: (50, 0)).tube(.skyDark, 5 * t)
                oval(14, 70, 26, 30).sticker(.white, w)
                oval(86, 70, 26, 30).sticker(.white, w)
                oval(14, 70, 12, 14).fill(Color.bubble.opacity(0.7))
                oval(86, 70, 12, 14).fill(Color.bubble.opacity(0.7))
            })

        // MARK: Eyes (lenses at x 28 and 72, y 50)
        case "heart_shades":
            return AnyView(ZStack {
                poly([(44, 46), (56, 46)], closed: false).line(w)
                ForEach([28.0, 72.0], id: \.self) { x in
                    UPath { p, pt in
                        p.move(to: pt(x, 66))
                        p.addCurve(to: pt(x, 40), control1: pt(x - 22, 50), control2: pt(x - 12, 30))
                        p.addCurve(to: pt(x, 66), control1: pt(x + 12, 30), control2: pt(x + 22, 50))
                    }.sticker(.tomato, w)
                }
                oval(22, 44, 5, 5).fill(.white.opacity(0.7))
                oval(66, 44, 5, 5).fill(.white.opacity(0.7))
            })
        case "star_specs":
            return AnyView(ZStack {
                poly([(42, 48), (58, 48)], closed: false).line(w)
                star(28, 50, 20).sticker(.sun, w)
                star(72, 50, 20).sticker(.sun, w)
                oval(28, 52, 12, 12).fill(Color.sky.opacity(0.7))
                oval(72, 52, 12, 12).fill(Color.sky.opacity(0.7))
            })
        case "monocle":
            return AnyView(ZStack {
                UPath { p, pt in p.move(to: pt(86, 62)); p.addQuadCurve(to: pt(96, 96), control: pt(100, 80)) }.line(w * 0.6, .sunDark)
                oval(72, 50, 32, 32).sticker(.white.opacity(0.3), w * 1.2)
                oval(72, 50, 32, 32).line(w * 0.9, .sunDark)
                arc((62, 44), (70, 38), via: (64, 38)).line(w * 0.7, .white.opacity(0.8))
            })
        case "eye_patch":
            return AnyView(ZStack {
                poly([(0, 30), (100, 62)], closed: false).line(w * 0.8, .coal)
                oval(72, 52, 30, 26).sticker(.coal, w)
            })
        case "cat_eye":
            return AnyView(ZStack {
                poly([(44, 48), (56, 48)], closed: false).line(w)
                ForEach([28.0, 72.0], id: \.self) { x in
                    let dir: CGFloat = x < 50 ? -1 : 1
                    poly([(x - 16 * dir, 58), (x - 16 * dir, 44), (x + 20 * dir, 34), (x + 16 * dir, 58)]).sticker(.bubble, w)
                }
                oval(28, 50, 20, 14).fill(.white.opacity(0.45))
                oval(72, 50, 20, 14).fill(.white.opacity(0.45))
            })
        case "aviators":
            return AnyView(ZStack {
                poly([(40, 40), (60, 40)], closed: false).line(w * 0.8, .sunDark)
                ForEach([28.0, 72.0], id: \.self) { x in
                    UPath { p, pt in
                        p.move(to: pt(x - 16, 40)); p.addLine(to: pt(x + 16, 40))
                        p.addQuadCurve(to: pt(x, 66), control: pt(x + 16, 66))
                        p.addQuadCurve(to: pt(x - 16, 40), control: pt(x - 16, 66))
                    }.sticker(Color(hex: 0x6E8B74), w)
                }
                arc((16, 46), (24, 42), via: (18, 42)).line(w * 0.8, .white.opacity(0.7))
            })
        case "sleep_mask":
            return AnyView(ZStack {
                rrect(0, 44, 100, 8, 4).fill(Color.grapeDark)
                rrect(8, 34, 84, 34, 17).sticker(.grape, w)
                arc((18, 50), (38, 50), via: (28, 60)).line(w * 0.9, .white)
                arc((62, 50), (82, 50), via: (72, 60)).line(w * 0.9, .white)
            })
        case "pixel_shades":
            return AnyView(ZStack {
                rrect(6, 38, 88, 8, 1).fill(Color.ink)
                ForEach([10.0, 54.0], id: \.self) { x in
                    rrect(x, 38, 36, 22, 1).fill(Color.ink)
                }
                ForEach([14.0, 58.0], id: \.self) { x in
                    rrect(x, 46, 6, 6, 0).fill(.white)
                    rrect(x + 6, 52, 6, 6, 0).fill(.white)
                }
            })

        // MARK: Neck (band around y 36–58)
        case "bandana":
            return AnyView(ZStack {
                poly([(10, 38), (90, 38), (50, 88)]).sticker(.tomato, w)
                ForEach([(36.0, 50.0), (60.0, 52.0), (48.0, 66.0)], id: \.1) { x, y in
                    oval(x, y, 7, 7).fill(.white.opacity(0.85))
                }
                rrect(8, 34, 84, 10, 5).sticker(.tomato.darker(0.08), w)
            })
        case "bowtie":
            return AnyView(ZStack {
                poly([(50, 50), (14, 30), (14, 70)]).sticker(.skyDark, w)
                poly([(50, 50), (86, 30), (86, 70)]).sticker(.skyDark, w)
                rrect(42, 40, 16, 20, 5).sticker(.sky, w)
                ForEach([(24.0, 44.0), (76.0, 56.0)], id: \.0) { x, y in oval(x, y, 6, 6).fill(.white.opacity(0.8)) }
            })
        case "pearls":
            return AnyView(ZStack {
                ForEach(Array(stride(from: 10.0, through: 90.0, by: 8.9).enumerated()), id: \.offset) { _, x in
                    oval(x, 40 + (1 - pow((x - 50) / 40, 2)) * 18, 11, 11).sticker(.white, w * 0.6)
                }
                oval(50, 66, 14, 16).sticker(Color(hex: 0xF5E6F0), w * 0.7)
            })
        case "flower_lei":
            return AnyView(ZStack {
                ForEach(Array(stride(from: 10.0, through: 90.0, by: 13.3).enumerated()), id: \.offset) { i, x in
                    let y = 40 + (1 - pow((x - 50) / 40, 2)) * 16
                    ZStack {
                        star(x, y, 9, points: 5).sticker([Color.bubble, .sun, .tomato][i % 3], w * 0.6)
                        oval(x, y, 4, 4).fill(.white)
                    }
                }
            })
        case "whistle":
            return AnyView(ZStack {
                arc((14, 30), (86, 30), via: (50, 70)).line(w * 0.8, .tomato)
                rrect(36, 52, 34, 22, 10).sticker(.sun, w)
                rrect(62, 52, 18, 10, 4).sticker(.sun, w)
                oval(46, 63, 8, 8).fill(Color.ink.opacity(0.6))
            })
        case "clover_charm":
            return AnyView(ZStack {
                arc((14, 30), (86, 30), via: (50, 62)).line(w * 0.7, .sunDark)
                ForEach(Array([(50.0, 56.0), (40.0, 66.0), (60.0, 66.0), (50.0, 76.0)].enumerated()), id: \.offset) { _, f in
                    oval(f.0, f.1, 14, 14).sticker(.grass, w * 0.7)
                }
                oval(50, 66, 6, 6).fill(Color.grassDark)
            })
        case "name_tag":
            return AnyView(ZStack {
                rrect(8, 34, 84, 14, 7).sticker(.sky, w)
                UPath { p, pt in
                    p.move(to: pt(50, 50)); p.addLine(to: pt(64, 60)); p.addLine(to: pt(58, 78))
                    p.addLine(to: pt(42, 78)); p.addLine(to: pt(36, 60)); p.closeSubpath()
                }.sticker(.sun, w)
                oval(50, 66, 6, 6).fill(Color.sunDark)
            })
        case "frilly_collar":
            return AnyView(ZStack {
                ForEach(Array(stride(from: 12.0, through: 88.0, by: 12.6).enumerated()), id: \.offset) { _, x in
                    oval(x, 46 + (1 - pow((x - 50) / 38, 2)) * 10, 18, 22).sticker(.white, w * 0.7)
                }
                rrect(18, 36, 64, 8, 4).fill(Color.bubble)
            })

        // MARK: Hand items (held around x 62, y 60)
        case "umbrella":
            return AnyView(ZStack {
                poly([(62, 70), (40, 30)], closed: false).tube(.coal, 3.5 * t)
                arc((62, 70), (72, 70), via: (68, 80)).line(w, .coal)
                UPath { p, pt in
                    p.move(to: pt(6, 40)); p.addQuadCurve(to: pt(70, 6), control: pt(20, 0))
                    p.addQuadCurve(to: pt(52, 28), control: pt(64, 22))
                    p.addQuadCurve(to: pt(30, 34), control: pt(40, 26))
                    p.addQuadCurve(to: pt(6, 40), control: pt(16, 32))
                }.sticker(.sun, w)
            })
        case "ice_cream":
            return AnyView(ZStack {
                poly([(48, 44), (72, 44), (62, 82)]).sticker(Color(hex: 0xE3B26A), w)
                poly([(52, 54), (68, 50)], closed: false).line(w * 0.6, .choco)
                oval(60, 34, 30, 28).sticker(.bubble, w)
                oval(60, 18, 22, 20).sticker(.white, w)
                oval(66, 10, 7, 7).sticker(.tomato, w * 0.6)
            })
        case "fishing_rod":
            return AnyView(ZStack {
                poly([(66, 72), (18, 6)], closed: false).tube(.choco, 3.5 * t)
                poly([(18, 6), (10, 52)], closed: false).line(w * 0.5, .ink.opacity(0.6))
                oval(60, 62, 12, 12).sticker(.coal, w * 0.7)
                poly([(4, 56), (16, 50), (16, 62)]).sticker(.sky, w * 0.6)
                oval(10, 56, 12, 8).sticker(.sky, w * 0.7)
            })
        case "trail_map":
            return AnyView(ZStack {
                poly([(18, 22), (40, 14), (60, 22), (82, 14), (82, 74), (60, 82), (40, 74), (18, 82)]).sticker(Color(hex: 0xF4E7C6), w)
                poly([(40, 14), (40, 74)], closed: false).line(w * 0.5, .choco.opacity(0.4))
                poly([(60, 22), (60, 82)], closed: false).line(w * 0.5, .choco.opacity(0.4))
                UPath { p, pt in
                    p.move(to: pt(26, 66)); p.addCurve(to: pt(72, 30), control1: pt(44, 70), control2: pt(52, 30))
                }.stroke(Color.tomato, style: StrokeStyle(lineWidth: w * 0.8, lineCap: .round, dash: [w * 1.4, w * 1.4]))
                poly([(66, 24), (78, 36)], closed: false).line(w * 0.8, .tomato)
                poly([(78, 24), (66, 36)], closed: false).line(w * 0.8, .tomato)
            })
        case "paper_fan":
            return AnyView(ZStack {
                poly([(62, 70), (54, 46)], closed: false).tube(.choco, 3 * t)
                UPath { p, pt in
                    p.move(to: pt(54, 50)); p.addLine(to: pt(10, 30))
                    p.addQuadCurve(to: pt(70, 4), control: pt(30, 2)); p.closeSubpath()
                }.sticker(.bubble, w)
                ForEach([(24.0, 22.0), (38.0, 12.0), (54.0, 8.0)], id: \.0) { x, y in
                    poly([(54, 50), (x, y)], closed: false).line(w * 0.5, .tomato.opacity(0.6))
                }
            })
        case "racket":
            return AnyView(ZStack {
                poly([(64, 70), (48, 44)], closed: false).tube(.coal, 4.5 * t)
                oval(36, 26, 40, 46).tube(.tomato, 4 * t)
                ForEach([26.0, 36.0, 46.0], id: \.self) { x in poly([(x, 8), (x, 44)], closed: false).line(w * 0.4, .ink.opacity(0.35)) }
                ForEach([16.0, 26.0, 36.0], id: \.self) { y in poly([(18, y), (54, y)], closed: false).line(w * 0.4, .ink.opacity(0.35)) }
                oval(80, 12, 14, 14).sticker(Color(hex: 0xD9E86A), w * 0.7)
            })
        case "cocoa_mug":
            return AnyView(ZStack {
                arc((40, 22), (46, 8), via: (34, 14)).line(w * 0.7, .white.opacity(0.9))
                arc((56, 22), (62, 8), via: (50, 14)).line(w * 0.7, .white.opacity(0.9))
                oval(76, 52, 20, 22).line(w * 1.4, .tomato)
                rrect(28, 30, 48, 48, 10).sticker(.tomato, w)
                oval(52, 32, 44, 10).sticker(.choco, w * 0.7)
                oval(46, 31, 9, 6).fill(.white)
            })
        case "magnifier":
            return AnyView(ZStack {
                poly([(66, 70), (46, 44)], closed: false).tube(.choco, 5 * t)
                oval(36, 30, 40, 40).sticker(.sky.opacity(0.5), w * 1.4)
                oval(36, 30, 40, 40).line(w * 1.1, .sunDark)
                arc((24, 28), (32, 18), via: (24, 20)).line(w * 0.8, .white)
            })

        // MARK: Bags
        case "satchel":
            return AnyView(ZStack {
                arc((20, 40), (80, 40), via: (50, -18)).line(w * 1.4, .choco.darker(0.1))
                rrect(10, 34, 80, 54, 12).sticker(.choco, w)
                UPath { p, pt in
                    p.move(to: pt(10, 46)); p.addQuadCurve(to: pt(90, 46), control: pt(50, 70))
                    p.addLine(to: pt(90, 40)); p.addQuadCurve(to: pt(10, 40), control: pt(50, 30)); p.closeSubpath()
                }.sticker(.choco.darker(0.08), w)
                rrect(44, 52, 12, 12, 3).sticker(.sun, w * 0.7)
            })
        case "belt_bag":
            return AnyView(ZStack {
                rrect(0, 40, 100, 10, 5).fill(Color.coal)
                rrect(14, 30, 72, 44, 22).sticker(.sky, w)
                arc((22, 46), (78, 46), via: (50, 40)).line(w * 0.8, .skyDark)
                rrect(66, 42, 8, 10, 3).fill(Color.sun)
            })
        case "tote":
            return AnyView(ZStack {
                arc((30, 34), (70, 34), via: (50, -6)).line(w * 1.3, Color(hex: 0xC8B48A))
                poly([(16, 30), (84, 30), (80, 92), (20, 92)]).sticker(Color(hex: 0xEADFC4), w)
                oval(50, 62, 22, 20).sticker(.grass, w * 0.7)
                oval(44, 56, 5, 5).fill(Color.ink)
                oval(56, 56, 5, 5).fill(Color.ink)
            })
        case "bento":
            return AnyView(ZStack {
                rrect(46, 8, 8, 18, 2).fill(Color.tomato)
                rrect(10, 20, 80, 14, 3).sticker(.tomato, w)
                rrect(12, 30, 76, 54, 8).sticker(.tomato.darker(0.06), w)
                rrect(20, 40, 28, 34, 5).sticker(.white, w * 0.7)
                oval(66, 56, 20, 20).sticker(.sun, w * 0.7)
            })
        case "camera":
            return AnyView(ZStack {
                arc((12, 36), (88, 36), via: (50, -20)).line(w * 1.1, .coal)
                rrect(8, 30, 84, 58, 14).sticker(.white, w)
                rrect(8, 30, 84, 14, 7).sticker(.sky, w * 0.8)
                oval(50, 64, 30, 30).sticker(.coal, w)
                oval(50, 64, 14, 14).fill(Color.sky.opacity(0.8))
                rrect(72, 48, 10, 8, 2).fill(Color.tomato)
            })
        case "star_pouch":
            return AnyView(ZStack {
                arc((32, 32), (68, 32), via: (50, 8)).line(w * 1.1, .sunDark)
                UPath { p, pt in
                    p.move(to: pt(30, 30)); p.addLine(to: pt(70, 30))
                    p.addQuadCurve(to: pt(50, 92), control: pt(102, 84))
                    p.addQuadCurve(to: pt(30, 30), control: pt(-2, 84))
                }.sticker(.grapeDark, w)
                star(50, 62, 14).sticker(.sun, w * 0.7)
                oval(30, 50, 4, 4).fill(.white)
                oval(70, 72, 4, 4).fill(.white)
            })
        case "postie_bag":
            return AnyView(ZStack {
                arc((14, 40), (86, 40), via: (50, -16)).line(w * 1.4, .tomato.darker(0.2))
                rrect(8, 34, 84, 54, 8).sticker(.tomato, w)
                poly([(8, 38), (50, 64), (92, 38)], closed: false).line(w, .tomato.darker(0.2))
                rrect(36, 66, 28, 14, 3).sticker(.white, w * 0.7)
            })

        // MARK: Shoes (one shoe, toe to the right)
        case "rain_boots":
            return AnyView(ZStack {
                rrect(20, 4, 48, 66, 10).sticker(.sun, w)
                rrect(10, 46, 82, 32, 16).sticker(.sun, w)
                rrect(8, 72, 86, 10, 5).sticker(.sunDark, w)
                rrect(28, 10, 8, 30, 4).fill(.white.opacity(0.45))
            })
        case "trail_boots":
            return AnyView(ZStack {
                rrect(20, 14, 46, 56, 10).sticker(Color(hex: 0x8C7A5B), w)
                rrect(10, 46, 82, 30, 15).sticker(Color(hex: 0x8C7A5B), w)
                ForEach([24.0, 36.0, 48.0], id: \.self) { y in poly([(30, y), (56, y)], closed: false).line(w * 0.8, .tomato) }
                rrect(8, 70, 86, 14, 6).sticker(.coal, w)
                ForEach([20.0, 40.0, 60.0, 80.0], id: \.self) { x in rrect(x, 80, 8, 6, 2).fill(Color.coal) }
            })
        case "cloud_slippers":
            return AnyView(ZStack {
                oval(26, 54, 34, 30).sticker(.white, w)
                oval(50, 50, 38, 34).sticker(.white, w)
                oval(74, 56, 34, 30).sticker(.white, w)
                rrect(8, 60, 86, 20, 10).sticker(.white, w)
                rrect(8, 72, 86, 10, 5).sticker(.sky, w * 0.8)
            })
        case "loafers":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(10, 74)); p.addLine(to: pt(14, 46))
                    p.addQuadCurve(to: pt(40, 46), control: pt(26, 40))
                    p.addQuadCurve(to: pt(92, 62), control: pt(84, 42))
                    p.addLine(to: pt(92, 74)); p.closeSubpath()
                }.sticker(.choco, w)
                rrect(44, 50, 22, 8, 3).sticker(.choco.darker(0.12), w * 0.7)
                oval(55, 54, 5, 5).fill(Color.sun)
                rrect(8, 72, 86, 8, 4).fill(Color.coal)
            })
        case "high_tops":
            return AnyView(ZStack {
                rrect(16, 10, 48, 60, 12).sticker(.grape, w)
                rrect(10, 42, 82, 32, 16).sticker(.grape, w)
                oval(36, 30, 14, 14).sticker(.white, w * 0.7)
                star(36, 30, 5).fill(Color.grape)
                rrect(6, 66, 88, 16, 8).sticker(.white, w)
                ForEach([18.0, 30.0], id: \.self) { y in poly([(46, y), (58, y)], closed: false).line(w * 0.8, .white) }
            })
        case "garden_clogs":
            return AnyView(ZStack {
                UPath { p, pt in
                    p.move(to: pt(8, 76)); p.addLine(to: pt(14, 42))
                    p.addQuadCurve(to: pt(94, 60), control: pt(88, 28))
                    p.addLine(to: pt(94, 76)); p.closeSubpath()
                }.sticker(.grass, w)
                ForEach([(54.0, 48.0), (68.0, 52.0), (62.0, 62.0), (78.0, 62.0)], id: \.0) { x, y in oval(x, y, 6, 6).fill(Color.grassDark) }
                arc((14, 44), (34, 58), via: (16, 58)).line(w, .grassDark)
            })
        case "roller_skates":
            return AnyView(ZStack {
                rrect(20, 4, 46, 60, 12).sticker(.bubble, w)
                rrect(12, 40, 78, 32, 16).sticker(.bubble, w)
                rrect(10, 66, 82, 8, 4).fill(Color.coal)
                oval(26, 84, 16, 16).sticker(.sun, w * 0.8)
                oval(74, 84, 16, 16).sticker(.sun, w * 0.8)
                oval(92, 64, 10, 10).sticker(.tomato, w * 0.7)
            })

        // MARK: Suits
        case let suit where suit.hasPrefix("suit_"):
            let c = tint ?? .sky
            let onesie = poly([(30, 20), (42, 16), (50, 24), (58, 16), (70, 20), (92, 38), (82, 52), (72, 46),
                               (72, 92), (28, 92), (28, 46), (18, 52), (8, 38)])
            return AnyView(ZStack {
                if suit == "suit_panda" || suit == "suit_lamb" {
                    oval(32, 16, 18, 18).sticker(suit == "suit_panda" ? .coal : c, w)
                    oval(68, 16, 18, 18).sticker(suit == "suit_panda" ? .coal : c, w)
                }
                onesie.sticker(c, w)
                SuitOverlay(id: suit).frame(width: 44 * t, height: 70 * t).offset(y: 14 * t)
            })
        default:
            return nil
        }
    }
}

/// Pattern drawn over the torso (and in the icon) for `suit_` outfits.
struct SuitOverlay: View {
    let id: String

    var body: some View {
        let w: CGFloat = 2.4
        ZStack {
            switch id {
            case "suit_hoodie":
                rrect(26, 56, 48, 22, 8).sticker(.skyDark, w)
                poly([(40, 6), (40, 30)], closed: false).line(w, .white)
                poly([(60, 6), (60, 30)], closed: false).line(w, .white)
            case "suit_raincoat":
                ForEach([30.0, 52.0, 74.0], id: \.self) { y in oval(50, y, 9, 9).sticker(.white, w * 0.6) }
                poly([(30, 4), (50, 20), (70, 4)], closed: false).line(w, .sunDark)
            case "suit_overalls":
                rrect(22, 30, 56, 62, 10).sticker(Color(hex: 0x5C7FA8), w)
                poly([(28, 32), (24, 0)], closed: false).line(w * 1.6, Color(hex: 0x5C7FA8))
                poly([(72, 32), (76, 0)], closed: false).line(w * 1.6, Color(hex: 0x5C7FA8))
                oval(32, 36, 7, 7).fill(Color.sun)
                oval(68, 36, 7, 7).fill(Color.sun)
                rrect(38, 48, 24, 16, 4).line(w * 0.7, .white.opacity(0.6))
            case "suit_sweater":
                ForEach([26.0, 50.0, 74.0], id: \.self) { y in
                    poly([(10, y), (24, y - 8), (38, y), (50, y - 8), (62, y), (76, y - 8), (90, y)], closed: false).line(w, .white.opacity(0.8))
                }
            case "suit_tracksuit":
                poly([(50, 0), (50, 100)], closed: false).line(w * 0.8, .white.opacity(0.7))
                poly([(10, 10), (10, 90)], closed: false).line(w * 1.5, .white)
                poly([(90, 10), (90, 90)], closed: false).line(w * 1.5, .white)
                rrect(44, 0, 12, 8, 3).fill(Color.sun)
            case "suit_puffer":
                ForEach([22.0, 46.0, 70.0], id: \.self) { y in
                    arc((6, y), (94, y), via: (50, y + 10)).line(w, .white.opacity(0.6))
                }
                poly([(50, 0), (50, 100)], closed: false).line(w * 0.8, .skyDark)
            case "suit_panda":
                oval(50, 60, 56, 54).fill(.white.opacity(0.8))
            case "suit_lamb":
                ForEach(Array([(30.0, 30.0), (50.0, 24.0), (70.0, 30.0), (36.0, 56.0), (64.0, 56.0), (50.0, 76.0)].enumerated()), id: \.offset) { _, f in
                    oval(f.0, f.1, 18, 16).fill(.white.opacity(0.7))
                }
            default:
                EmptyView()
            }
        }
    }
}
