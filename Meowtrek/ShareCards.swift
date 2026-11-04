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

struct ShareCard: View {
    let kind: ShareKind
    let data: ShareData

    private var colors: [Color] {
        switch kind {
        case .today: [Color(hex: 0xFCE3C4), Color(hex: 0xDDEBCF)]
        case .streak: [Color(hex: 0xFFD6B0), Color(hex: 0xF7B5A0)]
        case .outfit: [Color(hex: 0xE9E1FA), Color(hex: 0xFCE3EC)]
        case .journey: [Color(hex: 0xD6ECF7), Color(hex: 0xDDEBCF)]
        case .trek: [Color(hex: 0xFFE3D3), Color(hex: 0xD6ECF7)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            Circle().fill(.white.opacity(0.35)).frame(width: 300).offset(x: -120, y: -230)
            Circle().fill(.white.opacity(0.25)).frame(width: 220).offset(x: 140, y: 250)

            VStack(spacing: 14) {
                (Text("Meow").foregroundStyle(Color.ink) + Text("trek").foregroundStyle(Color.grassDark))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .padding(.top, 34)
                Spacer(minLength: 0)
                headline
                if kind == .trek, let t = data.trek {
                    RouteShape(points: t.route)
                        .stroke(t.kind.tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .padding(22)
                        .frame(height: 220)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(.white.opacity(0.75)))
                        .overlay(alignment: .bottomTrailing) {
                            CatView(outfit: data.outfit, size: 70, mood: .happy, animated: false).offset(x: 10, y: 20)
                        }
                }
                if kind != .trek {
                CatView(outfit: data.outfit, size: kind == .outfit ? 210 : 170, mood: kind == .streak ? .happy : data.mood, animated: false)
                    .background(Ellipse().fill(.black.opacity(0.07)).frame(width: 150, height: 22).offset(y: kind == .outfit ? 125 : 100))
                }
                detail
                Spacer(minLength: 0)
                Text("walking with \(data.petName) · day \(data.days)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink.opacity(0.55))
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 28)
        }
        .frame(width: 360, height: 640)
        .foregroundStyle(Color.ink)
    }

    @ViewBuilder private var headline: some View {
        switch kind {
        case .today:
            VStack(spacing: 2) {
                Text(data.steps.formatted()).font(.system(size: 64, weight: .bold, design: .rounded))
                Text(data.steps >= data.goal ? "steps · goal smashed!" : "steps today")
                    .font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.6))
            }
        case .streak:
            VStack(spacing: 2) {
                Image(systemName: "flame.fill").font(.system(size: 44)).foregroundStyle(Color.tomato)
                Text("\(data.streak) day\(data.streak == 1 ? "" : "s")").font(.system(size: 56, weight: .bold, design: .rounded))
                Text("walking streak").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.6))
            }
        case .outfit:
            VStack(spacing: 2) {
                Text("\(data.petName)'s look").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("of the day").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.6))
            }
        case .trek:
            VStack(spacing: 2) {
                Text(data.trekDistance).font(.system(size: 54, weight: .bold, design: .rounded))
                Text(data.trek.map { "\($0.kind.title.lowercased()) · \(durationText($0.moving))" } ?? "")
                    .font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.6))
            }
        case .journey:
            VStack(spacing: 2) {
                Text(data.journey.formatted()).font(.system(size: 52, weight: .bold, design: .rounded))
                Text("steps walked together").font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.6))
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
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.6))
            }
            .padding(.horizontal, 20)
        case .streak:
            Text("\(data.petName) hasn't missed a walk. Neither have I.")
                .font(.system(size: 16, weight: .semibold, design: .rounded)).multilineTextAlignment(.center)
                .foregroundStyle(Color.ink.opacity(0.65))
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
                    VStack { Text(paceText(t.pace)).font(.system(size: 22, weight: .bold, design: .rounded)); Text("avg pace").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.55)) }
                    VStack { Text("\(Int(t.climb))m").font(.system(size: 22, weight: .bold, design: .rounded)); Text("climb").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.55)) }
                    VStack { Text("\(t.kcal)").font(.system(size: 22, weight: .bold, design: .rounded)); Text("kcal").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.55)) }
                }
            }
        case .journey:
            VStack(spacing: 4) {
                Text("Level \(data.level)").font(.system(size: 20, weight: .bold, design: .rounded))
                if let next = data.nextStop {
                    Text("next stop: \(next)").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.6))
                }
            }
        }
    }
}

enum ShareOut {
    @MainActor
    static func render(_ kind: ShareKind, _ data: ShareData) -> UIImage? {
        let r = ImageRenderer(content: ShareCard(kind: kind, data: data))
        r.scale = 3
        return r.uiImage
    }

    /// Opens Instagram's story composer with the card as background. Needs a Meta (Facebook) App ID.
    @MainActor
    static func instagramStory(_ image: UIImage) -> Bool {
        let appID = AppConfig.facebookAppID
        guard !appID.isEmpty,
              let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
              UIApplication.shared.canOpenURL(url),
              let png = image.pngData() else { return false }
        UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": png]],
                                      options: [.expirationDate: Date().addingTimeInterval(300)])
        UIApplication.shared.open(url)
        return true
    }
}

struct ShareCardsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State var kind: ShareKind = .today
    var trek: Trek? = nil
    @State private var image: UIImage?
    @State private var saved = false

    var body: some View {
        let data = ShareData(state, trek: trek)
        let kinds = ShareKind.allCases.filter { $0 != .trek || trek != nil }
        NavigationStack {
            VStack(spacing: 16) {
                TabView(selection: $kind) {
                    ForEach(kinds) { k in
                        ShareCard(kind: k, data: data)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .scaleEffect(0.78)
                            .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                            .tag(k)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 520)

                HStack(spacing: 6) {
                    ForEach(kinds) { k in
                        Button(k.title) { withAnimation(.snappy) { kind = k } }
                            .buttonStyle(.chunky(kind == k ? .grass : .paper, text: kind == k ? .white : .ink, radius: 20, padH: 12, padV: 7))
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        guard let img = ShareOut.render(kind, data) else { return }
                        if !ShareOut.instagramStory(img) { image = img }
                    } label: {
                        Label("Share to Instagram Story", systemImage: "camera.circle.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.chunky(Color(hex: 0xD9488F), text: .white, radius: 18, padV: 13))

                    HStack(spacing: 10) {
                        if let img = ShareOut.render(kind, data) {
                            ShareLink(item: Image(uiImage: img), preview: SharePreview("Meowtrek", image: Image(uiImage: img))) {
                                Label("More apps", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.chunky(.paper, radius: 18, padV: 12))
                            Button {
                                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
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
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .foregroundStyle(Color.ink)
            .background(Color.cream)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .sheet(item: Binding(get: { image.map(IdentifiedImage.init) }, set: { image = $0?.image })) { item in
                ActivitySheet(items: [item.image]).presentationDetents([.medium, .large])
            }
            .onChange(of: kind) { saved = false }
        }
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
