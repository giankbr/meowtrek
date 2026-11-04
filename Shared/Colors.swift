import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    init(hexString: String) { self.init(hex: UInt32(hexString, radix: 16) ?? 0) }

    static let ink = Color(hex: 0x2B2622)
    static let inkSoft = Color(hex: 0x8A837A)
    static let cream = Color(hex: 0xF6F0E4)
    static let paper = Color(hex: 0xFFFDF8)
    static let grass = Color(hex: 0x7FA86B)
    static let grassDark = Color(hex: 0x4F7F3E)
    static let grassLight = Color(hex: 0xDDEBCF)
    static let sun = Color(hex: 0xF6C945)
    static let sunDark = Color(hex: 0xC9962A)
    static let tomato = Color(hex: 0xE5707A)
    static let grape = Color(hex: 0x8B7BC8)
    static let grapeDark = Color(hex: 0x5E4F9A)
    static let sky = Color(hex: 0x8CC4DE)
    static let skyDark = Color(hex: 0x4F93B8)
    static let bubble = Color(hex: 0xF4A3A8)
    static let choco = Color(hex: 0x9A6B4F)
    static let pumpkin = Color(hex: 0xF2A65A)
    static let night = Color(hex: 0x2E2447)
    static let coal = Color(hex: 0x45404F)

    static let leaf = grass
    static let leafDark = grassDark
    static let leafLight = grassLight
    static let honey = sun
    static let chestBg = Color(hex: 0xFBF0D3)

    func darker(_ k: Double = 0.18) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: h, saturation: min(1, s + 0.05), brightness: max(0, b - k), opacity: a)
    }
}
