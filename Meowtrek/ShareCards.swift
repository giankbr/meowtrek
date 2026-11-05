import PhotosUI
import SwiftUI
import UIKit

enum ShareKind: String, CaseIterable, Identifiable {
    case today, streak, outfit, journey, trek
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: loc("Today")
        case .streak: loc("Streak")
        case .outfit: loc("Outfit")
        case .journey: loc("Journey")
        case .trek: loc("Trek")
        }
    }
}

/// Values captured from AppState so the card renders the same in the preview and in ImageRenderer.
struct ShareData {
    let petName: String
    let outfit: [Slot: Item]
    let mood: CatMood
    let steps: Int
    let goal: Int
    let streak: Int
    let level: Int
    let journey: Int
    let days: Int
    let nextStop: String?
    let km: String
    var trek: Trek?
    var trekDistance = ""

    @MainActor
    init(_ s: AppState, trek: Trek? = nil) {
        self.trek = trek
        trekDistance = trek.map { s.distanceText($0.meters) } ?? ""
        petName = s.petName
        outfit = s.outfit
        mood = CatMood(s.mood)
        steps = s.today
        goal = s.goal
        streak = s.streak
        level = s.level
        journey = s.journeySteps
        days = s.daysTogether
        nextStop = s.content.landmarks.first { $0.steps > s.journeySteps }?.name
        km = s.distanceText(s.steps.meters(on: .now))
    }
}

enum ShareFormat: String, CaseIterable, Identifiable {
    case story, post
    var id: String { rawValue }
    var title: String { self == .story ? loc("Story") : loc("Post") }
    var size: CGSize { self == .story ? CGSize(width: 360, height: 640) : CGSize(width: 360, height: 360) }
}

enum ShareTheme: String, CaseIterable, Identifiable {
    case auto, peach, meadow, lavender, sky, night, photo
    var id: String { rawValue }
    var dark: Bool { self == .night || self == .photo }

    func colors(_ kind: ShareKind) -> [Color] {
        switch self {
        case .auto:
            switch kind {
            case .today: [Color(hex: 0xFCE3C4), Color(hex: 0xDDEBCF)]
            case .streak: [Color(hex: 0xFFD6B0), Color(hex: 0xF7B5A0)]
            case .outfit: [Color(hex: 0xE9E1FA), Color(hex: 0xFCE3EC)]
            case .journey: [Color(hex: 0xD6ECF7), Color(hex: 0xDDEBCF)]
            case .trek: [Color(hex: 0xFFE3D3), Color(hex: 0xD6ECF7)]
            }
        case .peach: [Color(hex: 0xFFE0C7), Color(hex: 0xF9B9A5)]
        case .meadow: [Color(hex: 0xE4F1D3), Color(hex: 0xB8D79E)]
        case .lavender: [Color(hex: 0xEDE5FB), Color(hex: 0xC9B8EE)]
        case .sky: [Color(hex: 0xDDF0FA), Color(hex: 0xA9D4EC)]
        case .night, .photo: [Color(hex: 0x2E2447), Color(hex: 0x4A3F8C)]
        }
    }
}

struct ShareStyle {
    var format: ShareFormat = .story
    var theme: ShareTheme = .auto
    var photo: UIImage?
    var showStats = true
    var showName = true
}

struct ShareCard: View {
    let kind: ShareKind
    let data: ShareData
    var style = ShareStyle()

    private var compact: Bool { style.format == .post }
    private var k: CGFloat { compact ? 0.72 : 1 }
    private var fg: Color { style.theme.dark ? .white : .ink }
    private var sub: Color { fg.opacity(style.theme.dark ? 0.75 : 0.6) }

    var body: some View {
        let size = style.format.size
        ZStack {
            background(size)
            VStack(spacing: compact ? 8 : 14) {
                (Text("Meow").foregroundStyle(fg) + Text("trek").foregroundStyle(style.theme.dark ? Color.grassLight : Color.grassDark))
                    .font(.system(size: 26 * k, weight: .bold, design: .rounded))
                    .padding(.top, compact ? 16 : 34)
                Spacer(minLength: 0)
                if style.showStats { headline }
                if kind == .trek, let t = data.trek {
                    RouteShape(points: t.route)
                        .stroke(t.kind.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .padding(22 * k)
                        .frame(height: 220 * k)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white.opacity(0.75)))
                        .overlay(alignment: .bottomTrailing) {
                            CatView(outfit: data.outfit, size: 70 * k, mood: .happy, animated: false).offset(x: 10, y: 20)
                        }
                } else {
                    CatView(outfit: data.outfit, size: (kind == .outfit ? 210 : 170) * (compact ? 0.66 : 1),
                            mood: kind == .streak ? .happy : data.mood, animated: false)
                        .background(Ellipse().fill(.black.opacity(0.07)).frame(width: 150 * k, height: 22 * k)
                            .offset(y: (kind == .outfit ? 125 : 100) * (compact ? 0.66 : 1)))
                }
                if style.showStats && !compact { detail }
                Spacer(minLength: 0)
                Text(style.showName ? loc("walking with \(data.petName) · day \(data.days)") : "meowtrek")
                    .font(.system(size: 14 * max(k, 0.85), weight: .semibold, design: .rounded))
                    .foregroundStyle(sub)
                    .padding(.bottom, compact ? 14 : 30)
            }
            .padding(.horizontal, 28 * k)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .foregroundStyle(fg)
    }

    @ViewBuilder private func background(_ size: CGSize) -> some View {
        if style.theme == .photo, let photo = style.photo {
            Image(uiImage: photo).resizable().scaledToFill().frame(width: size.width, height: size.height).clipped()
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.05), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        } else {
            LinearGradient(colors: style.theme.colors(kind), startPoint: .top, endPoint: .bottom)
            Circle().fill(.white.opacity(style.theme.dark ? 0.06 : 0.35)).frame(width: 300).offset(x: -120, y: -size.height * 0.36)
            Circle().fill(.white.opacity(style.theme.dark ? 0.05 : 0.25)).frame(width: 220).offset(x: 140, y: size.height * 0.39)
            if style.theme == .night {
                ForEach(0..<10, id: \.self) { i in
                    Circle().fill(.white.opacity(0.7)).frame(width: CGFloat(2 + i % 3))
                        .offset(x: CGFloat((i * 67) % 300) - 150, y: CGFloat((i * 53) % Int(size.height * 0.4)) - size.height * 0.45)
                }
            }
        }
    }

    @ViewBuilder private var headline: some View {
        switch kind {
        case .today:
            VStack(spacing: 2) {
                Text(data.steps.formatted()).font(.system(size: 64 * k, weight: .bold, design: .rounded))
                Text(data.steps >= data.goal ? "steps · goal smashed!" : "steps today")
                    .font(.system(size: 18 * k, weight: .semibold, design: .rounded)).foregroundStyle(sub)
            }
        case .streak:
            VStack(spacing: 2) {
                Image(systemName: "flame.fill").font(.system(size: 44 * k)).foregroundStyle(Color.tomato)
                Text("\(data.streak) day\(data.streak == 1 ? "" : "s")").font(.system(size: 56 * k, weight: .bold, design: .rounded))
                Text("walking streak").font(.system(size: 18 * k, weight: .semibold, design: .rounded)).foregroundStyle(sub)
            }
        case .outfit:
            VStack(spacing: 2) {
                Text("\(data.petName)'s look").font(.system(size: 34 * k, weight: .bold, design: .rounded))
                Text("of the day").font(.system(size: 18 * k, weight: .semibold, design: .rounded)).foregroundStyle(sub)
            }
        case .trek:
            VStack(spacing: 2) {
                Text(data.trekDistance).font(.system(size: 54 * k, weight: .bold, design: .rounded))
                Text(data.trek.map { "\($0.kind.title.lowercased()) · \(durationText($0.moving))" } ?? "")
                    .font(.system(size: 18 * k, weight: .semibold, design: .rounded)).foregroundStyle(sub)
            }
        case .journey:
            VStack(spacing: 2) {
                Text(data.journey.formatted()).font(.system(size: 52 * k, weight: .bold, design: .rounded))
                Text("steps walked together").font(.system(size: 18 * k, weight: .semibold, design: .rounded)).foregroundStyle(sub)
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch kind {
        case .today:
            VStack(spacing: 8) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.7))
                        Capsule().fill(Color.grass).frame(width: g.size.width * min(1, Double(data.steps) / Double(max(1, data.goal))))
                    }
                }
                .frame(height: 14)
                Text("\(data.km) · goal \(data.goal.formatted())")
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(sub)
            }
            .padding(.horizontal, 20)
        case .streak:
            Text("\(data.petName) hasn't missed a walk. Neither have I.")
                .font(.system(size: 16, weight: .semibold, design: .rounded)).multilineTextAlignment(.center)
                .foregroundStyle(sub)
        case .outfit:
            HStack(spacing: 8) {
                ForEach(Slot.allCases.compactMap { data.outfit[$0] }.filter { $0.slot != .fur }.prefix(4), id: \.id) { item in
                    ItemArt(item: item, size: 40)
                        .frame(width: 54, height: 54)
                        .background(Circle().fill(.white.opacity(0.7)))
                }
            }
        case .trek:
            if let t = data.trek {
                HStack(spacing: 22) {
                    stat(paceText(t.pace), "avg pace")
                    stat("\(Int(t.climb))m", "climb")
                    stat("\(t.kcal)", "kcal")
                }
            }
        case .journey:
            VStack(spacing: 4) {
                Text("Level \(data.level)").font(.system(size: 20, weight: .bold, design: .rounded))
                if let next = data.nextStop {
                    Text("next stop: \(next)").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(sub)
                }
            }
        }
    }

    private func stat(_ v: String, _ l: LocalizedStringKey) -> some View {
        VStack {
            Text(v).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(l).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(sub)
        }
    }
}

/// Transparent cut-out for Instagram's sticker layer: the cat and the headline on a white rounded card.
struct ShareSticker: View {
    let kind: ShareKind
    let data: ShareData

    var body: some View {
        VStack(spacing: 6) {
            CatView(outfit: data.outfit, size: 130, mood: .happy, animated: false)
            Group {
                switch kind {
                case .today: Text(loc("\(data.steps.formatted()) steps"))
                case .streak: Text(loc("\(data.streak) day streak"))
                case .outfit: Text(loc("\(data.petName)'s look"))
                case .journey: Text(loc("\(data.journey.formatted()) steps"))
                case .trek: Text(data.trekDistance)
                }
            }
            .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("meowtrek").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Color.inkSoft)
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 26).padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.white))
        .padding(8)
    }
}

enum ShareOut {
    @MainActor
    static func render(_ kind: ShareKind, _ data: ShareData, _ style: ShareStyle) -> UIImage? {
        let r = ImageRenderer(content: ShareCard(kind: kind, data: data, style: style))
        r.scale = 3
        return r.uiImage
    }

    @MainActor
    static func sticker(_ kind: ShareKind, _ data: ShareData) -> UIImage? {
        let r = ImageRenderer(content: ShareSticker(kind: kind, data: data))
        r.scale = 3
        r.isOpaque = false
        return r.uiImage
    }

    /// Opens Instagram's story composer. Needs a Meta (Facebook) App ID; returns false so the caller can fall back.
    @MainActor
    static func instagram(background: UIImage? = nil, sticker: UIImage? = nil, top: String = "#FCE3C4", bottom: String = "#DDEBCF") -> Bool {
        let appID = AppConfig.facebookAppID
        guard !appID.isEmpty,
              let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
              UIApplication.shared.canOpenURL(url) else { return false }
        var item: [String: Any] = [:]
        if let png = background?.pngData() { item["com.instagram.sharedSticker.backgroundImage"] = png }
        if let png = sticker?.pngData() {
            item["com.instagram.sharedSticker.stickerImage"] = png
            if background == nil {
                item["com.instagram.sharedSticker.backgroundTopColor"] = top
                item["com.instagram.sharedSticker.backgroundBottomColor"] = bottom
            }
        }
        UIPasteboard.general.setItems([item], options: [.expirationDate: Date().addingTimeInterval(300)])
        UIApplication.shared.open(url)
        return true
    }
}

struct ShareCardsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State var kind: ShareKind = .today
    var trek: Trek? = nil
    @State private var style = ShareStyle()
    @State private var pick: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var saved = false

    private let swatches: [ShareTheme] = [.auto, .peach, .meadow, .lavender, .sky, .night]

    var body: some View {
        let data = ShareData(state, trek: trek)
        let kinds = ShareKind.allCases.filter { $0 != .trek || trek != nil }
        let size = style.format.size
        let scale = min(250 / size.width, 400 / size.height)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TabView(selection: $kind) {
                        ForEach(kinds) { k in
                            ShareCard(kind: k, data: data, style: style)
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .scaleEffect(scale)
                                .frame(width: size.width * scale, height: size.height * scale)
                                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                                .tag(k)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 420)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(kinds) { k in
                                Button(k.title) { withAnimation(.snappy) { kind = k } }
                                    .buttonStyle(StoryChipStyle(on: kind == k))
                            }
                        }
                        .padding(.horizontal, 20).padding(.vertical, 3)
                    }

                    options

                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Button { shareInstagram(data, sticker: false) } label: {
                                Label("Story", systemImage: "camera.circle.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.chunky(Color(hex: 0xD9488F), text: .white, radius: 18, padV: 13))
                            Button { shareInstagram(data, sticker: true) } label: {
                                Label("Sticker", systemImage: "face.smiling").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.chunky(Color(hex: 0x8B4FD9), text: .white, radius: 18, padV: 13))
                        }
                        Text("Sticker drops \(state.petName) on top of your own photo or video.")
                            .font(.game(11, .medium)).foregroundStyle(Color.inkSoft)

                        HStack(spacing: 10) {
                            if let img = ShareOut.render(kind, data, style) {
                                ShareLink(item: Image(uiImage: img), preview: SharePreview("Meowtrek", image: Image(uiImage: img))) {
                                    Label("More apps", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.chunky(.paper, radius: 18, padV: 12))
                                Button {
                                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                                    Telemetry.track("share_saved")
                                    saved = true
                                    state.show(loc("Saved to Photos"), art: "deco_cloud")
                                } label: {
                                    Label(saved ? "Saved" : "Save", systemImage: saved ? "checkmark" : "arrow.down.to.line")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.chunky(.paper, radius: 18, padV: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .storyNavTitle(loc("Share a page"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.font(.story(15, .bold)) } }
            .sheet(item: Binding(get: { image.map(IdentifiedImage.init) }, set: { image = $0?.image })) { item in
                ActivitySheet(items: [item.image]).presentationDetents([.medium, .large])
            }
            .onChange(of: kind) { saved = false }
            .onChange(of: pick) {
                Task {
                    if let d = try? await pick?.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                        style.photo = img.resized(maxSide: 1600)
                        withAnimation(.snappy) { style.theme = .photo }
                    }
                }
            }
        }
        .presentationBackground(Color.cream)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Shape").font(.story(14, .semibold)).foregroundStyle(Color.inkSoft).lineLimit(1).minimumScaleFactor(0.8).frame(width: 84, alignment: .leading)
                ForEach(ShareFormat.allCases) { f in
                    Button(f.title) { withAnimation(.snappy) { style.format = f } }
                        .buttonStyle(StoryChipStyle(on: style.format == f))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Text("Paper").font(.story(14, .semibold)).foregroundStyle(Color.inkSoft).lineLimit(1).minimumScaleFactor(0.8).frame(width: 84, alignment: .leading)
                ForEach(swatches) { t in
                    Button { withAnimation(.snappy) { style.theme = t } } label: {
                        Circle().fill(LinearGradient(colors: t.colors(kind), startPoint: .top, endPoint: .bottom))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(style.theme == t ? Color.grassDark : Color.black.opacity(0.08), lineWidth: style.theme == t ? 2.5 : 1).padding(-2))
                    }
                    .buttonStyle(SquishStyle())
                    .accessibilityLabel(t.rawValue)
                }
                PhotosPicker(selection: $pick, matching: .images) {
                    Image(systemName: "photo").font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.paper))
                        .overlay(Circle().stroke(style.theme == .photo ? Color.grassDark : Color.black.opacity(0.08), lineWidth: style.theme == .photo ? 2.5 : 1).padding(-2))
                }
                .accessibilityLabel(Text("Use a photo"))
            }
            PencilRule()
            Toggle("Show the numbers", isOn: $style.showStats.animation(.snappy))
            Toggle("Show \(state.petName)'s name", isOn: $style.showName.animation(.snappy))
        }
        .font(.story(15, .medium))
        .tint(.grass)
        .card(padding: 14, radius: 10)
        .taped(.topLeading, angle: -8, color: .sky, x: 18, width: 48)
        .padding(.horizontal, 20)
    }

    private func shareInstagram(_ data: ShareData, sticker: Bool) {
        Telemetry.track(sticker ? "share_sticker" : "share_story")
        if sticker {
            guard let img = ShareOut.sticker(kind, data) else { return }
            let c = style.theme.colors(kind).map { hex($0) }
            if !ShareOut.instagram(sticker: img, top: c[0], bottom: c[1]) { image = img }
        } else {
            var story = style
            story.format = .story
            guard let img = ShareOut.render(kind, data, story) else { return }
            if !ShareOut.instagram(background: img) { image = img }
        }
    }

    private func hex(_ c: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

private struct IdentifiedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Fallback when Instagram isn't installed or no Meta App ID is configured.
private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
