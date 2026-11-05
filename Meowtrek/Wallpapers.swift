import SwiftUI
import UIKit

enum WallpaperTarget: String, CaseIterable, Identifiable {
    case watch, phone
    var id: String { rawValue }
    var title: String { self == .watch ? loc("Apple Watch") : loc("iPhone") }
    /// Point size; rendered at 2x for the watch (410×502 px) and 3x for iPhone (1290×2796 px).
    var size: CGSize { self == .watch ? CGSize(width: 205, height: 251) : CGSize(width: 430, height: 932) }
    var scale: CGFloat { self == .watch ? 2 : 3 }
}

enum WallpaperDesign: String, CaseIterable, Identifiable {
    case meadow, night, pastel, sunset, minimal, seasonal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .meadow: loc("Meadow")
        case .night: loc("Night sky")
        case .pastel: loc("Pastel")
        case .sunset: loc("Sunset")
        case .minimal: loc("Minimal")
        case .seasonal: loc("Seasonal")
        }
    }
    var plus: Bool { self == .sunset || self == .seasonal }
}

struct Wallpaper: View {
    let design: WallpaperDesign
    let target: WallpaperTarget
    let outfit: [Slot: Item]
    let decor: [String]

    var body: some View {
        let s = target.size
        let k = s.width / 205
        let catSize = target == .watch ? 120 * k : 250 * k * 0.62
        let catY = target == .watch ? s.height * 0.6 : s.height * 0.66
        ZStack {
            background(s, k)
            Ellipse().fill(.black.opacity(design == .night ? 0.2 : 0.08))
                .frame(width: catSize * 0.8, height: catSize * 0.14)
                .position(x: s.width / 2, y: catY + catSize * 0.58)
            CatView(outfit: outfit, size: catSize, mood: design == .night ? .sleepy : .happy, animated: false)
                .position(x: s.width / 2, y: catY)
        }
        .frame(width: s.width, height: s.height)
        .clipped()
    }

    @ViewBuilder private func background(_ s: CGSize, _ k: CGFloat) -> some View {
        switch design {
        case .meadow:
            LinearGradient(colors: [Color(hex: 0x9FD6F5), Color(hex: 0xE3F3FB)], startPoint: .top, endPoint: .bottom)
            hills(s, back: Color(hex: 0x9BD67A), front: Color(hex: 0x7FBF5E))
            ArtView(id: "deco_cloud", size: 60 * k).position(x: s.width * 0.22, y: s.height * 0.16)
            ArtView(id: "deco_tree", size: 70 * k).position(x: s.width * 0.14, y: s.height * 0.66)
            Circle().fill(Color.sun).frame(width: 34 * k).position(x: s.width * 0.82, y: s.height * 0.14)
        case .night:
            LinearGradient(colors: [Color(hex: 0x1E1B4B), Color(hex: 0x4A3F8C)], startPoint: .top, endPoint: .bottom)
            ForEach(0..<18, id: \.self) { i in
                Circle().fill(.white.opacity(0.75)).frame(width: CGFloat(1.5 + Double(i % 3)) * k)
                    .position(x: s.width * CGFloat((i * 37) % 100) / 100, y: s.height * CGFloat((i * 53) % 55) / 100)
            }
            Circle().fill(Color(hex: 0xFFF3C4)).frame(width: 36 * k).position(x: s.width * 0.8, y: s.height * 0.15)
            hills(s, back: Color(hex: 0x2F5E45), front: Color(hex: 0x3F7A4A))
        case .pastel:
            LinearGradient(colors: [Color(hex: 0xF9D9E8), Color(hex: 0xE4DDFA), Color(hex: 0xD6EEF8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.45)).frame(width: s.width * 0.9).position(x: s.width * 0.15, y: s.height * 0.2)
            Circle().fill(.white.opacity(0.35)).frame(width: s.width * 0.7).position(x: s.width * 0.9, y: s.height * 0.75)
        case .sunset:
            LinearGradient(colors: [Color(hex: 0xFF9E7A), Color(hex: 0xFFC98E), Color(hex: 0xFFE7C2)], startPoint: .top, endPoint: .bottom)
            Circle().fill(Color(hex: 0xFF8A5B)).frame(width: 60 * k).position(x: s.width / 2, y: s.height * 0.42)
            hills(s, back: Color(hex: 0x98B877), front: Color(hex: 0x7A9A5B))
        case .minimal:
            Color(hex: 0xF7F4EC)
            Circle().fill(Color.grassLight).frame(width: s.width * 0.75).position(x: s.width / 2, y: target == .watch ? s.height * 0.58 : s.height * 0.64)
        case .seasonal:
            LinearGradient(colors: [Color(hex: 0x2E2447), Color(hex: 0x5E4F9A)], startPoint: .top, endPoint: .bottom)
            hills(s, back: Color(hex: 0x3F5E47), front: Color(hex: 0x4F7F3E))
            ForEach(Array(decor.prefix(3).enumerated()), id: \.offset) { i, id in
                ArtView(id: id, size: (i == 0 ? 54 : 38) * k)
                    .position(x: s.width * [0.16, 0.86, 0.8][i], y: s.height * [0.8, 0.84, 0.2][i])
            }
        }
    }

    private func hills(_ s: CGSize, back: Color, front: Color) -> some View {
        ZStack {
            Ellipse().fill(back).frame(width: s.width * 1.3, height: s.height * 0.5).position(x: s.width * 0.2, y: s.height * 0.9)
            Ellipse().fill(front).frame(width: s.width * 1.4, height: s.height * 0.45).position(x: s.width * 0.85, y: s.height * 0.98)
        }
    }
}

struct WallpapersView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var target: WallpaperTarget = .watch
    @State private var design: WallpaperDesign = .meadow
    @State private var paywall = false

    private var decor: [String] { state.activeEvent?.event.decor ?? ["deco_tree", "deco_bush", "deco_cloud"] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        ForEach(WallpaperTarget.allCases) { t in
                            Button(t.title) { withAnimation(.snappy) { target = t } }
                                .buttonStyle(StoryChipStyle(on: target == t))
                        }
                    }
                    preview
                    Text("Pick a backdrop for \(state.petName)").font(.story(15, .regular)).italic().foregroundStyle(Color.inkSoft)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(WallpaperDesign.allCases) { d in
                            let i = WallpaperDesign.allCases.firstIndex(of: d) ?? 0
                            Button { withAnimation(.snappy) { design = d } } label: {
                                VStack(spacing: 5) {
                                    Wallpaper(design: d, target: .watch, outfit: state.outfit, decor: decor)
                                        .scaleEffect(0.38)
                                        .frame(width: 205 * 0.38, height: 251 * 0.38)
                                        .clipShape(Rectangle())
                                    Text(d.title).font(.story(12, design == d ? .bold : .medium))
                                        .foregroundStyle(design == d ? Color.grassDark : Color.inkSoft)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                }
                                .padding(.horizontal, 6).padding(.top, 6).padding(.bottom, 4)
                                .background(Rectangle().fill(Color.paper).shadow(color: .black.opacity(design == d ? 0.16 : 0.08), radius: design == d ? 6 : 3, y: 2))
                                .overlay(alignment: .top) { if design == d { Tape(color: .sun, width: 40).rotationEffect(.degrees(i.isMultiple(of: 2) ? -6 : 5)).offset(y: -8) } }
                                .overlay(alignment: .topTrailing) {
                                    if d.plus && !state.isPlus {
                                        Image(systemName: "crown.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.sunDark)
                                            .padding(4).background(Circle().fill(Color.paper)).offset(x: 5, y: -5)
                                    }
                                }
                                .rotationEffect(.degrees(design == d ? 0 : [-2.5, 1.5, -1, 2, -1.5, 1][i % 6]))
                            }
                            .buttonStyle(SquishStyle())
                        }
                    }
                    Button { save() } label: { Label("Save to Photos", systemImage: "arrow.down.to.line").font(.story(17, .bold)).frame(maxWidth: .infinity) }
                        .buttonStyle(.chunky(.grass, text: .white, radius: 14, padV: 14))
                    Text(target == .watch
                         ? "On your iPhone open Watch › Face Gallery › Photos, then choose this image."
                         : "Open Photos, pick the image, tap Share › Use as Wallpaper.")
                        .font(.game(12, .medium)).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                    WatchFacesSection()
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .storyNavTitle(loc("Wallpapers"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.font(.story(15, .bold)) } }
            .sheet(isPresented: $paywall) { PaywallView() }
        }
        .presentationBackground(Color.cream)
    }

    private var preview: some View {
        let s = target.size
        let scale = min(220 / s.width, 360 / s.height)
        return Wallpaper(design: design, target: target, outfit: state.outfit, decor: decor)
            .scaleEffect(scale)
            .frame(width: s.width * scale, height: s.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: target == .watch ? 34 : 30, style: .continuous))
            .padding(target == .watch ? 8 : 6)
            .background(RoundedRectangle(cornerRadius: target == .watch ? 40 : 36, style: .continuous).fill(Color(hex: 0x1E1B18)))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .taped(.top, angle: -4, color: .bubble, width: 64)
            .padding(.top, 12)
            .animation(.snappy, value: design)
    }

    private func save() {
        guard !design.plus || state.isPlus else { paywall = true; return }
        let r = ImageRenderer(content: Wallpaper(design: design, target: target, outfit: state.outfit, decor: decor))
        r.scale = target.scale
        guard let img = r.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        Telemetry.track("wallpaper_saved")
        state.show(loc("Saved to Photos"), art: "deco_cloud")
    }
}

/// Ready-made Apple Watch faces with Meowtrek complications, shipped as .watchface files in the app bundle.
struct WatchFacesSection: View {
    @State private var faces: [URL] = Bundle.main.urls(forResourcesWithExtension: "watchface", subdirectory: nil) ?? []

    var body: some View {
        if !faces.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                StoryHeading(text: loc("Ready-made watch faces"), size: 20)
                ForEach(faces, id: \.self) { url in
                    ShareLink(item: url) {
                        HStack {
                            GameIcon(symbol: "applewatch", tint: .grassDark, size: 36)
                            Text(url.deletingPathExtension().lastPathComponent).font(.story(15, .semibold))
                            Spacer()
                            Image(systemName: "plus.circle.fill").foregroundStyle(Color.grass)
                        }
                        .card(padding: 10)
                    }
                    .buttonStyle(SquishStyle())
                }
                Text("Opens the Watch app so you can add the face, complications and all.")
                    .font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
