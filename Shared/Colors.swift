import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    init(hexString: String) { self.init(hex: UInt32(hexString, radix: 16) ?? 0) }

    static let ink = Color(hex: 0x2B2340)
    static let inkSoft = Color(hex: 0x7A7290)
    static let cream = Color(hex: 0xFFF4E0)
    static let paper = Color(hex: 0xFFFDF8)
    static let grass = Color(hex: 0x6CC24A)
    static let grassDark = Color(hex: 0x3E8E2F)
    static let grassLight = Color(hex: 0xC8EBB0)
    static let sun = Color(hex: 0xFFC93C)
    static let sunDark = Color(hex: 0xE09A00)
    static let tomato = Color(hex: 0xFF6B5B)
    static let grape = Color(hex: 0x8B6CEF)
    static let grapeDark = Color(hex: 0x5B3FC4)
    static let sky = Color(hex: 0x7CC8F2)
    static let skyDark = Color(hex: 0x3D9BD6)
    static let bubble = Color(hex: 0xFF8FB1)
    static let choco = Color(hex: 0x9A6545)
    static let pumpkin = Color(hex: 0xFF9A3C)
    static let night = Color(hex: 0x2E2452)
    static let coal = Color(hex: 0x3A3350)

    static let leaf = grass
    static let leafDark = grassDark
    static let leafLight = grassLight
    static let honey = sun
    static let chestBg = Color(hex: 0xFFE7B0)

    func darker(_ k: Double = 0.18) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(1, s + 0.05), brightness: max(0, b - k), opacity: a)
    }
}
