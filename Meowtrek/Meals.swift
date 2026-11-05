import PhotosUI
import SwiftUI
import UIKit

struct MealEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var reaction: String
    var tags: [String]
    var balance: Int
    var photo: String
}

@Observable
final class MealStore {
    var meals: [MealEntry] = []

    @ObservationIgnored private let dir = URL.documentsDirectory.appending(path: "meals", directoryHint: .isDirectory)
    @ObservationIgnored private var index: URL { dir.appending(path: "meals.json") }

    init() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: index), let m = try? JSONDecoder().decode([MealEntry].self, from: d) { meals = m }
    }

    func add(_ image: UIImage, _ r: MealReply) -> MealEntry {
        let name = UUID().uuidString + ".jpg"
        try? image.resized(maxSide: 600).jpegData(compressionQuality: 0.7)?.write(to: dir.appending(path: name))
        let e = MealEntry(date: .now, reaction: r.reaction, tags: r.tags, balance: r.balance, photo: name)
        meals.insert(e, at: 0)
        try? JSONEncoder().encode(meals).write(to: index, options: .atomic)
        return e
    }

    func exportData() -> Data { (try? JSONEncoder().encode(meals)) ?? Data() }

    /// Photos aren't backed up; restored entries keep their text and score.
    func replace(with data: Data) {
        guard let m = try? JSONDecoder().decode([MealEntry].self, from: data) else { return }
        meals = m
        try? JSONEncoder().encode(meals).write(to: index, options: .atomic)
    }

    func image(_ e: MealEntry) -> UIImage? { UIImage(contentsOfFile: dir.appending(path: e.photo).path) }
}

struct MealReply: Decodable {
    let isFood: Bool
    let reaction: String
    let tags: [String]
    let balance: Int
}

extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}

enum MealAI {
    @MainActor
    static func react(_ image: UIImage, state: AppState) async throws -> MealReply {
        guard let base = AppConfig.apiBase else { throw CoachError.unavailable }
        guard let jpeg = image.resized(maxSide: 1024).jpegData(compressionQuality: 0.7) else { throw CoachError.server("Couldn't read photo") }
        struct Body: Encodable { let context: CoachContext; let image: String; let mediaType: String }
        var req = URLRequest(url: base.appending(path: "v1/coach/meal"))
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(state.profileID, forHTTPHeaderField: "X-Meowtrek-Device")
        if let jws = state.store.plusJWS { req.setValue(jws, forHTTPHeaderField: "X-Meowtrek-Transaction") }
        req.httpBody = try JSONEncoder().encode(Body(context: Coach.context(state), image: jpeg.base64EncodedString(), mediaType: "image/jpeg"))
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 429 { throw CoachError.limit }
        guard code == 200 else { throw CoachError.server("Meal check failed (\(code))") }
        return try JSONDecoder().decode(MealReply.self, from: data)
    }
}

struct MealView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var pick: PhotosPickerItem?
    @State private var camera = false
    @State private var photo: UIImage?
    @State private var reply: MealReply?
    @State private var loading = false
    @State private var error: String?
    @State private var showPaywall = false

    private let tagStyle: [String: (String, Color)] = [
        "veggies": ("leaf.fill", .grass), "fruit": ("apple.logo", .tomato), "protein": ("fish.fill", .skyDark),
        "grains": ("takeoutbag.and.cup.and.straw.fill", .sunDark), "dairy": ("cup.and.saucer.fill", .sky),
        "sweets": ("birthday.cake.fill", .bubble), "fried": ("flame.fill", .pumpkin), "drink": ("drop.fill", .sky),
        "homemade": ("house.fill", .choco),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                            .frame(height: 250).frame(maxWidth: .infinity)
                            .clipped()
                            .padding(10).padding(.bottom, 26)
                            .background(Color.white)
                            .overlay(alignment: .bottom) {
                                Text(Date.now.formatted(.dateTime.weekday(.wide).hour().minute()))
                                    .font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft).padding(.bottom, 8)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                            .rotationEffect(.degrees(-1.5))
                            .taped(.top, angle: -6, color: .pumpkin)
                            .padding(.horizontal, 6).padding(.top, 8)
                    } else {
                        VStack(spacing: 10) {
                            CatView(outfit: state.outfit, size: 110, mood: .happy)
                            StoryHeading(text: loc("What's on your plate?"), size: 22, color: .pumpkin)
                            Text("Snap it and \(state.petName) will have a sniff. No calorie counting, promise.")
                                .font(.story(14, .regular)).italic().foregroundStyle(Color.inkSoft).multilineTextAlignment(.center)
                                .padding(.top, 6)
                        }
                        .padding(.vertical, 20)
                    }

                    if loading {
                        HStack(spacing: 10) { ProgressView(); Text("\(state.petName) is having a sniff…").font(.story(14, .regular)).italic() }
                    }
                    if let reply {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 10) {
                                CatView(outfit: state.outfit, size: 50, mood: .happy, animated: false).frame(width: 52, height: 62)
                                Text(reply.reaction).font(.story(16, .regular))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if reply.isFood {
                                HStack(spacing: 4) {
                                    Text("How balanced").font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft)
                                    ForEach(1...5, id: \.self) { i in
                                        Image(systemName: i <= reply.balance ? "heart.fill" : "heart")
                                            .foregroundStyle(i <= reply.balance ? Color.tomato : Color.inkSoft.opacity(0.4))
                                    }
                                }
                                FlowTags(tags: reply.tags.map { ($0, tagStyle[$0] ?? ("circle.fill", .inkSoft)) })
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(RuledLines(spacing: 26))
                        .background(PaperShape(radius: 12, wobble: 1.2, seed: 61).fill(Color.paper))
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                        .taped(.topTrailing, angle: 8, color: .grass, x: -30)
                    }
                    if let error { Text(error).font(.game(13, .medium)).foregroundStyle(Color.tomato) }

                    HStack(spacing: 10) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button { camera = true } label: { Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                                .buttonStyle(.chunky(.grass, text: .white, radius: 18, padV: 13))
                        }
                        PhotosPicker(selection: $pick, matching: .images) {
                            Label("Library", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.chunky(.paper, radius: 18, padV: 13))
                    }
                    .disabled(loading)

                    if !state.meals.meals.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            StorySection(loc("Snack scrapbook"), subtitle: loc("Everything we've sniffed lately"), color: .pumpkin)
                                .padding(.bottom, 4)
                            ForEach(Array(state.meals.meals.prefix(10).enumerated()), id: \.element.id) { i, m in
                                if i > 0 { InkRule() }
                                HStack(spacing: 12) {
                                    if let img = state.meals.image(m) {
                                        Image(uiImage: img).resizable().scaledToFill().frame(width: 48, height: 48)
                                            .clipped()
                                            .padding(4).padding(.bottom, 6)
                                            .background(Color.white)
                                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                            .rotationEffect(.degrees(i.isMultiple(of: 2) ? -4 : 3))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.reaction).font(.story(14, .regular)).lineLimit(2)
                                        Text(m.date.formatted(.dateTime.weekday().hour().minute())).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
                                    }
                                    Spacer()
                                    Label("\(m.balance)", systemImage: "heart.fill").font(.game(13, .bold)).foregroundStyle(Color.tomato)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }
                }
                .padding(16)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .navigationTitle("Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .onChange(of: pick) {
                Task {
                    if let data = try? await pick?.loadTransferable(type: Data.self), let img = UIImage(data: data) { analyze(img) }
                }
            }
            .fullScreenCover(isPresented: $camera) { CameraPicker { analyze($0) }.ignoresSafeArea() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
        .presentationBackground(Color.cream)
    }

    private func analyze(_ img: UIImage) {
        photo = img
        reply = nil
        error = nil
        loading = true
        Task {
            do {
                let r = try await MealAI.react(img, state: state)
                withAnimation(.spring) { reply = r }
                if r.isFood {
                    _ = state.meals.add(img, r)
                    state.shareMeal()
                }
            } catch CoachError.limit {
                showPaywall = true
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}

private struct FlowTags: View {
    let tags: [(String, (String, Color))]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.0) { name, style in
                Label(name.capitalized, systemImage: style.0)
                    .font(.game(12, .semibold))
                    .foregroundStyle(style.1.darker(0.1))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill(style.1.opacity(0.16)))
            }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let done: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.done(img) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
