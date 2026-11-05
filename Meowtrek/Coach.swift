import Foundation
import FoundationModels
import SwiftUI

struct ChatMessage: Codable, Identifiable, Hashable {
    var id = UUID()
    let role: String
    let content: String

    enum CodingKeys: String, CodingKey { case role, content }
}

struct CoachContext: Codable {
    let petName: String
    let mood: String
    let todaySteps: Int
    let goal: Int
    let streak: Int
    let weekSteps: [Int]
    let level: Int
    let locale: String
}

struct CoachInsight: Codable, Equatable {
    let headline: String
    let summary: String
    let tips: [String]
    let suggestedGoal: Int
}

enum CoachError: LocalizedError {
    case unavailable, limit, server(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: loc("AI isn't available on this device yet.")
        case .limit: loc("You've used today's free chats.")
        case .server(let m): m
        }
    }
}

protocol CoachEngine {
    func chat(_ messages: [ChatMessage], _ ctx: CoachContext) async throws -> String
    func insight(_ ctx: CoachContext, days: [Int]) async throws -> CoachInsight
    func quests(_ ctx: CoachContext) async throws -> [QuestTemplate]
}

enum Coach {
    static var onDeviceAvailable: Bool {
        if #available(iOS 26.0, *) { return OnDeviceCoach.isAvailable }
        return false
    }

    static var cloudAvailable: Bool { AppConfig.apiBase != nil }

    @MainActor
    static func engine(_ state: AppState) -> CoachEngine? {
        var chain: [CoachEngine] = []
        let cloud = CloudCoach(state: state)
        if state.aiEngine != "cloud", #available(iOS 26.0, *), OnDeviceCoach.isAvailable { chain.append(OnDeviceCoach()) }
        if state.aiEngine != "device", cloudAvailable { chain.append(cloud) }
        return FallbackCoach(chain: chain)
    }

    @MainActor
    static func context(_ s: AppState) -> CoachContext {
        let cal = Calendar.current
        let week = (0..<7).reversed().map { s.steps.steps(on: cal.date(byAdding: .day, value: -$0, to: .now)!) }
        return CoachContext(petName: s.petName, mood: s.mood, todaySteps: s.today, goal: s.goal, streak: s.streak,
                            weekSteps: week, level: s.level, locale: Locale.preferredLanguages.first ?? "en")
    }

    @MainActor
    static func last28(_ s: AppState) -> [Int] {
        let cal = Calendar.current
        return (0..<28).reversed().map { s.steps.steps(on: cal.date(byAdding: .day, value: -$0, to: .now)!) }
    }

    static func persona(_ c: CoachContext) -> String {
        """
        You are \(c.petName), a small cartoon cat who walks with your human in the app Meowtrek. Speak as the cat: warm, \
        playful, a little cheeky, short (at most 70 words), one or two cat mannerisms at most. Encourage gentle walking \
        and celebrate progress. Never give medical advice; suggest seeing a professional for pain or health issues. \
        Reply in the language of locale "\(c.locale)" (Indonesian if it starts with "id").
        Today: \(c.todaySteps) of \(c.goal) steps, streak \(c.streak) days, mood \(c.mood), level \(c.level). \
        Last 7 days (oldest first): \(c.weekSteps.map(String.init).joined(separator: ", ")).
        """
    }

    static func clampQuest(title: String, detail: String, kind: String, target: Int, hour: Int?, reward: Int, index: Int, goal: Int) -> QuestTemplate {
        let k = QuestTemplate.Kind(rawValue: kind) ?? .steps
        let h = min(22, max(6, hour ?? 12))
        let t = max(1, target)
        return QuestTemplate(
            id: "ai\(index)", title: String(title.prefix(28)), icon: ["sparkles", "wand.and.stars", "star.fill"][index % 3],
            tint: ["8B7BC8", "F4A3A8", "F6C945"][index % 3], kind: k, reward: min(80, max(10, reward)),
            fraction: k == .steps ? min(1.5, max(0.1, Double(t) / Double(max(1, goal)))) : 0,
            hour: k == .before || k == .after ? h : 0,
            steps: k == .before || k == .after ? min(15000, max(300, t)) : k == .activeHours ? 250 : 0,
            count: k == .activeHours ? min(12, max(2, t)) : 0)
    }
}

// MARK: - On-device (Apple Intelligence)

@available(iOS 26.0, *)
@Generable
struct GenInsight {
    @Guide(description: "A short, upbeat headline under 8 words")
    var headline: String
    @Guide(description: "Two or three sentences summarising the last four weeks of walking")
    var summary: String
    @Guide(description: "Three short practical walking tips", .count(3))
    var tips: [String]
    @Guide(description: "A realistic daily step goal for next week", .range(2000...30000))
    var suggestedGoal: Int
}

@available(iOS 26.0, *)
@Generable
struct GenQuest {
    @Guide(description: "Quest title under 4 words")
    var title: String
    @Guide(description: "One short sentence describing the quest")
    var detail: String
    @Guide(description: "Quest type", .anyOf(["steps", "before", "after", "activeHours"]))
    var kind: String
    @Guide(description: "Steps for steps/before/after quests, or number of active hours for activeHours")
    var target: Int
    @Guide(description: "Hour of day 6-22 for before/after quests, otherwise 12")
    var hour: Int
    @Guide(description: "Coin reward between 10 and 80")
    var reward: Int
}

@available(iOS 26.0, *)
@Generable
struct GenQuests {
    @Guide(description: "Exactly three varied daily quests", .count(3))
    var quests: [GenQuest]
}

@available(iOS 26.0, *)
struct OnDeviceCoach: CoachEngine {
    static var isAvailable: Bool { SystemLanguageModel.default.availability == .available }

    func chat(_ messages: [ChatMessage], _ ctx: CoachContext) async throws -> String {
        let session = LanguageModelSession(instructions: Coach.persona(ctx))
        let transcript = messages.suffix(10).map { "\($0.role == "user" ? "Human" : ctx.petName): \($0.content)" }
            .joined(separator: "\n")
        let reply = try await session.respond(to: transcript + "\n\(ctx.petName):")
        return reply.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func insight(_ ctx: CoachContext, days: [Int]) async throws -> CoachInsight {
        let session = LanguageModelSession(instructions: Coach.persona(ctx))
        let r = try await session.respond(
            to: "Daily steps for the last 28 days, oldest first: \(days.map(String.init).joined(separator: ", ")). Current goal \(ctx.goal). Write my weekly insight.",
            generating: GenInsight.self)
        let g = r.content
        return CoachInsight(headline: g.headline, summary: g.summary, tips: Array(g.tips.prefix(3)),
                            suggestedGoal: min(30000, max(2000, g.suggestedGoal / 500 * 500)))
    }

    func quests(_ ctx: CoachContext) async throws -> [QuestTemplate] {
        let session = LanguageModelSession(instructions: Coach.persona(ctx))
        let r = try await session.respond(
            to: "Create three daily walking quests for me today that fit my recent rhythm and are achievable but a little challenging.",
            generating: GenQuests.self)
        return r.content.quests.prefix(3).enumerated().map { i, q in
            Coach.clampQuest(title: q.title, detail: q.detail, kind: q.kind, target: q.target, hour: q.hour, reward: q.reward, index: i, goal: ctx.goal)
        }
    }
}

// MARK: - Cloud (Meowtrek server → Claude)

private struct ServerError: Decodable { let error: String }

struct CloudCoach: CoachEngine {
    let device: String
    let plusJWS: String?

    @MainActor
    init(state: AppState) {
        device = state.profileID
        plusJWS = state.store.plusJWS
    }

    private func post<T: Decodable>(_ path: String, _ body: some Encodable) async throws -> T {
        guard let base = AppConfig.apiBase else { throw CoachError.unavailable }
        var req = URLRequest(url: base.appending(path: path))
        req.httpMethod = "POST"
        req.timeoutInterval = 40
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(device, forHTTPHeaderField: "X-Meowtrek-Device")
        if let plusJWS { req.setValue(plusJWS, forHTTPHeaderField: "X-Meowtrek-Transaction") }
        req.httpBody = try JSONEncoder().encode(body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 429 { throw CoachError.limit }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONDecoder().decode(ServerError.self, from: data))?.error ?? "server_\(code)"
            throw CoachError.server(msg == "ai_busy" ? loc("The coach is napping, try again in a moment.")
                                    : msg == "ai_not_configured" ? CoachError.unavailable.localizedDescription
                                    : loc("AI coach error (\(msg))"))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private struct ChatBody: Encodable { let messages: [ChatMessage]; let context: CoachContext }
    private struct ChatReply: Decodable { let reply: String }
    private struct InsightBody: Encodable { let context: CoachContext; let last28Days: [Int] }
    private struct QuestsBody: Encodable { let context: CoachContext; let localHour: Int }
    private struct WireQuest: Decodable { let title: String; let detail: String; let kind: String; let target: Int; let hour: Int?; let reward: Int }

    func chat(_ messages: [ChatMessage], _ ctx: CoachContext) async throws -> String {
        let r: ChatReply = try await post("v1/coach/chat", ChatBody(messages: Array(messages.suffix(12)), context: ctx))
        return r.reply
    }

    func insight(_ ctx: CoachContext, days: [Int]) async throws -> CoachInsight {
        try await post("v1/coach/insight", InsightBody(context: ctx, last28Days: days))
    }

    func quests(_ ctx: CoachContext) async throws -> [QuestTemplate] {
        let hour = Calendar.current.component(.hour, from: .now)
        let r: [WireQuest] = try await post("v1/coach/quests", QuestsBody(context: ctx, localHour: hour))
        return r.prefix(3).enumerated().map { i, q in
            Coach.clampQuest(title: q.title, detail: q.detail, kind: q.kind, target: q.target, hour: q.hour, reward: q.reward, index: i, goal: ctx.goal)
        }
    }
}

// MARK: - Chat UI

struct CoachView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var thinking = false
    @State private var error: String?
    @State private var showPaywall = false

    private let starters = [loc("How am I doing this week?"), loc("Plan an evening walk for me"), loc("I'm feeling lazy today"), loc("Motivate me!")]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            VStack(spacing: 6) {
                                CatView(outfit: state.outfit, size: 96, mood: thinking ? .normal : .happy)
                                StoryHeading(text: loc("Notes with \(state.petName)"), size: 22, color: .grass)
                                PaperLabel(text: engineLabel, color: .sky, angle: -2, size: 11).padding(.top, 8)
                            }
                            .padding(.vertical, 10)
                            ForEach(messages) { bubble($0).id($0.id) }
                            if thinking {
                                HStack { typing; Spacer() }.id("typing")
                            }
                            if let error {
                                Text(error).font(.story(13, .regular)).italic().foregroundStyle(Color.tomato).multilineTextAlignment(.center)
                            }
                            if messages.isEmpty {
                                Text("Not sure where to start? Try one of these.")
                                    .font(.story(13, .regular)).italic().foregroundStyle(Color.inkSoft)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                FlowChips(items: starters) { send($0) }
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) {
                        withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                    }
                }
                inputBar
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .navigationTitle("Cat coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                if !state.isPlus {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("\(state.chatsLeft) notes left today").font(.story(12, .regular)).italic().foregroundStyle(Color.inkSoft)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
        .presentationBackground(Color.cream)
    }

    private var engineLabel: String {
        switch (Coach.engine(state) as? FallbackCoach)?.chain.first {
        case is CloudCoach: return loc("AI coach · cloud")
        case nil: return loc("Coach · offline mode")
        default: return loc("AI coach · on this iPhone")
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Write \(state.petName) a note…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .font(.story(16, .regular))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(PaperShape(radius: 12, wobble: 1, seed: 71).fill(Color.paper))
                .overlay(PaperShape(radius: 12, wobble: 1, seed: 71).stroke(Color.ink.opacity(0.08), lineWidth: 1))
                .submitLabel(.send)
                .onSubmit { send(input) }
            Button { send(input) } label: { Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)) }
                .buttonStyle(.chunky(.grass, text: .white, radius: 20, padH: 12, padV: 10))
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background {
            ZStack { Color.cream; PaperGrain() }
                .mask(VStack(spacing: 0) { TornEdge(seed: 29).frame(height: 10); Rectangle() })
                .padding(.top, -10)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func bubble(_ m: ChatMessage) -> some View {
        let mine = m.role == "user"
        return HStack(alignment: .bottom, spacing: 8) {
            if mine { Spacer(minLength: 40) } else {
                CatView(outfit: state.outfit, size: 30, animated: false).frame(width: 32, height: 38)
            }
            let seed = abs(m.id.hashValue % 97)
            Text(m.content)
                .font(.story(16, .regular))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background {
                    if mine {
                        PaperShape(radius: 4, wobble: 1, seed: seed).fill(Color.grassLight)
                            .shadow(color: .black.opacity(0.08), radius: 2, x: 1, y: 2)
                    } else {
                        ZStack {
                            PaperShape(radius: 10, wobble: 1.2, seed: seed).fill(Color.paper)
                            RuledLines(spacing: 22).clipShape(PaperShape(radius: 10, wobble: 1.2, seed: seed))
                        }
                        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
                    }
                }
                .rotationEffect(.degrees(mine ? 1 : -0.6))
            if !mine { Spacer(minLength: 40) }
        }
    }

    private var typing: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle().fill(Color.inkSoft.opacity(0.6)).frame(width: 7)
                    .phaseAnimator([0.3, 1]) { c, v in c.opacity(v) } animation: { _ in .easeInOut(duration: 0.5).delay(Double(i) * 0.15) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(PaperShape(radius: 10, wobble: 1, seed: 3).fill(Color.paper))
        .padding(.leading, 40)
    }

    private func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !thinking else { return }
        guard state.chatsLeft > 0 else { showPaywall = true; return }
        guard let engine = Coach.engine(state) else { error = CoachError.unavailable.localizedDescription; return }
        error = nil
        input = ""
        messages.append(ChatMessage(role: "user", content: t))
        thinking = true
        let ctx = Coach.context(state)
        let history = messages
        Task {
            do {
                let reply = try await engine.chat(history, ctx)
                state.countChat()
                Telemetry.track("chat_sent")
                withAnimation(.spring) { messages.append(ChatMessage(role: "assistant", content: reply)) }
            } catch CoachError.limit {
                showPaywall = true
            } catch {
                self.error = error.localizedDescription
            }
            thinking = false
        }
    }
}

struct FlowChips: View {
    let items: [String]
    let tap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { s in
                Button { tap(s) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.line").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.inkSoft)
                        Text(s).font(.story(15, .regular))
                    }
                }
                .buttonStyle(.chunky(.paper, radius: 12, padH: 14, padV: 9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Insight card

struct InsightCard: View {
    @Environment(AppState.self) private var state
    @State private var insight: CoachInsight?
    @State private var loading = false
    @State private var error: String?
    @State private var showPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                GameIcon(symbol: "envelope.open.fill", tint: .grape, size: 36)
                Text("This week's letter").font(.story(18, .bold))
                Spacer()
                if !state.isPlus { Tag(text: loc("Plus"), color: .sun, textColor: .ink) }
            }
            if let insight {
                Text(insight.headline).font(.story(19, .bold))
                Text(insight.summary).font(.story(15, .regular)).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                InkRule()
                ForEach(insight.tips, id: \.self) { tip in
                    Label(tip, systemImage: "pawprint.fill").font(.story(14, .regular))
                        .labelStyle(TipLabelStyle())
                }
                Text(loc("love, \(state.petName)")).font(.story(14, .semibold)).italic().foregroundStyle(Color.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if insight.suggestedGoal != state.goal {
                    Button("Set goal to \(insight.suggestedGoal.formatted()) steps") {
                        state.goal = insight.suggestedGoal
                        state.save()
                        state.show(loc("Goal updated"), art: "coin")
                    }
                    .buttonStyle(.chunky(.grassLight, text: .grassDark))
                }
            } else {
                Text("\(state.petName) can read back over our last four weeks and write you a little letter about what to try next.")
                    .font(.story(14, .regular)).italic().foregroundStyle(Color.inkSoft)
            }
            if let error { Text(error).font(.game(12, .medium)).foregroundStyle(Color.tomato) }
            Button {
                guard state.isPlus else { showPaywall = true; return }
                generate()
            } label: {
                HStack {
                    if loading { ProgressView().tint(.white) }
                    Text(insight == nil ? "Ask for a letter" : "Write a new one")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.chunky(.grape, text: .white))
            .disabled(loading)
        }
        .card()
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private func generate() {
        guard let engine = Coach.engine(state) else { error = CoachError.unavailable.localizedDescription; return }
        loading = true
        error = nil
        let ctx = Coach.context(state), days = Coach.last28(state)
        Task {
            do {
                insight = try await engine.insight(ctx, days: days)
                Telemetry.track("insight_generated")
            } catch { self.error = error.localizedDescription }
            loading = false
        }
    }
}

private struct TipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon.foregroundStyle(Color.grass).font(.system(size: 12))
            configuration.title
        }
    }
}

// MARK: - Fallback

/// Tries each engine in order; the simulator and devices without Apple Intelligence land on the offline coach.
struct FallbackCoach: CoachEngine {
    let chain: [CoachEngine]

    private func attempt<T>(_ run: (CoachEngine) async throws -> T, offline: () throws -> T) async throws -> T {
        for e in chain {
            do { return try await run(e) } catch CoachError.limit { throw CoachError.limit } catch { continue }
        }
        return try offline()
    }

    func chat(_ m: [ChatMessage], _ c: CoachContext) async throws -> String {
        try await attempt({ try await $0.chat(m, c) }, offline: { OfflineCoach.chat(m.last?.content ?? "", c) })
    }

    func insight(_ c: CoachContext, days: [Int]) async throws -> CoachInsight {
        try await attempt({ try await $0.insight(c, days: days) }, offline: { OfflineCoach.insight(c, days: days) })
    }

    func quests(_ c: CoachContext) async throws -> [QuestTemplate] {
        try await attempt({ try await $0.quests(c) }, offline: { throw CoachError.unavailable })
    }
}

enum OfflineCoach {
    private static func id(_ c: CoachContext) -> Bool { c.locale.hasPrefix("id") }

    static func chat(_ text: String, _ c: CoachContext) -> String {
        let t = text.lowercased(), idn = id(c)
        let left = max(0, c.goal - c.todaySteps)
        let avg = c.weekSteps.reduce(0, +) / max(1, c.weekSteps.count)
        let best = c.weekSteps.max() ?? 0
        if t.contains("week") || t.contains("minggu") {
            return idn
                ? "Minggu ini rata-rata kita \(avg.formatted()) langkah sehari, paling jauh \(best.formatted()). \(avg >= c.goal ? "Keren, di atas target!" : "Sedikit lagi ke target \(c.goal.formatted()). Jalan sore bareng, yuk?") Meow."
                : "This week we averaged \(avg.formatted()) steps a day, best day \(best.formatted()). \(avg >= c.goal ? "That's above goal, proud of you!" : "A little short of \(c.goal.formatted()). Evening stroll together?") Meow."
        }
        if t.contains("tip") || t.contains("saran") || t.contains("how") || t.contains("gimana") {
            return idn
                ? "Coba jalan 10 menit habis makan, naik tangga, atau telepon sambil jalan. Langkah kecil, kumpul jadi banyak!"
                : "Try a 10 minute walk after meals, take the stairs, or pace during calls. Little steps add up!"
        }
        if left == 0 {
            return idn ? "Target hari ini sudah tercapai! \(c.streak) hari beruntun. Aku bangga, purr." : "Goal done today! \(c.streak) days in a row. I'm so proud, purr."
        }
        return idn
            ? "Hari ini \(c.todaySteps.formatted()) langkah, kurang \(left.formatted()) lagi. Sekitar \(max(1, left / 100)) menit jalan santai. Ayo!"
            : "We're at \(c.todaySteps.formatted()) steps, \(left.formatted()) to go. About \(max(1, left / 100)) minutes of easy walking. Let's go!"
    }

    static func insight(_ c: CoachContext, days: [Int]) -> CoachInsight {
        let idn = id(c)
        let week = Array(days.suffix(7)), prev = Array(days.dropLast(7).suffix(7))
        let avg = week.reduce(0, +) / max(1, week.count), pAvg = prev.reduce(0, +) / max(1, prev.count)
        let hit = week.filter { $0 >= c.goal }.count
        let up = avg >= pAvg
        let goal = min(30000, max(2000, (avg + (hit >= 5 ? 1000 : 0)) / 500 * 500))
        return CoachInsight(
            headline: idn ? (up ? "Langkahmu naik minggu ini" : "Minggu yang lebih santai") : (up ? "You stepped it up this week" : "A gentler week"),
            summary: idn
                ? "Rata-rata \(avg.formatted()) langkah sehari (minggu lalu \(pAvg.formatted())). Target tercapai \(hit) dari 7 hari."
                : "You averaged \(avg.formatted()) steps a day (last week \(pAvg.formatted())). Goal hit on \(hit) of 7 days.",
            tips: idn
                ? ["Jalan 10 menit setelah makan siang", "Pilih tangga daripada lift", "Ajak teman jalan sore"]
                : ["Walk 10 minutes after lunch", "Take the stairs over the lift", "Invite a friend for an evening walk"],
            suggestedGoal: goal)
    }
}
