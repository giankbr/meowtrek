import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    static let cream = Color(hex: 0xF7F4EC)
    static let leaf = Color(hex: 0x7FA86B)
    static let leafDark = Color(hex: 0x4F7F3E)
    static let leafLight = Color(hex: 0xC9DDBA)
    static let ink = Color(hex: 0x2B2622)
    static let inkSoft = Color(hex: 0x8A837A)
    static let honey = Color(hex: 0xF6C945)
    static let night = Color(hex: 0x2E2447)
    static let chestBg = Color(hex: 0xFBF0D3)
}
