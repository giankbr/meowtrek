import AppIntents
import SwiftUI
import WidgetKit

struct StepEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StepEntry { StepEntry(date: .now, snap: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (StepEntry) -> Void) {
        completion(StepEntry(date: .now, snap: WidgetBridge.read() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepEntry>) -> Void) {
        let entry = StepEntry(date: .now, snap: WidgetBridge.read() ?? .sample)
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [entry], policy: .after(min(midnight, .now.addingTimeInterval(1800)))))
    }
}

struct MeowtrekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StepEntry

    private var s: WidgetSnapshot { entry.snap }
    private var mood: CatMood { s.recentlyPetted ? .happy : CatMood(s.mood) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: s.progress) {
                Image(systemName: "pawprint.fill")
            } currentValueLabel: {
                Text(shortSteps(s.stepsToday)).font(.system(size: 11, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(s.petName) · \(L(s.mood))").font(.caption2.weight(.semibold))
                Text("\(s.stepsToday.formatted()) steps").font(.headline)
                ProgressView(value: s.progress)
            }
        case .systemMedium:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    petButton(size: 70)
                    Text(s.stepsToday.formatted()).font(.system(size: 24, weight: .bold, design: .rounded)).minimumScaleFactor(0.7)
                    bar
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 6) {
                    waterButton
                    claimButton
                    feedButton
                }
                .frame(width: 128)
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    petButton(size: 76)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(s.petName) · \(L(s.mood))").font(.caption.weight(.semibold)).foregroundStyle(Color.inkSoft)
                        Text(s.stepsToday.formatted()).font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("of \(s.goal.formatted()) steps").font(.caption).foregroundStyle(Color.inkSoft)
                        bar
                    }
                }
                Text("Today").font(.system(size: 15, weight: .bold, design: .rounded))
                ForEach(s.questsToday.prefix(3)) { q in questRow(q) }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    waterButton
                    claimButton
                    feedButton
                }
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    petButton(size: 58)
                    Spacer()
                    Label("\(s.streak)", systemImage: "flame.fill").font(.caption.weight(.bold)).foregroundStyle(Color.pumpkin)
                }
                Spacer(minLength: 0)
                Text(s.stepsToday.formatted()).font(.system(size: 24, weight: .bold, design: .rounded))
                bar
            }
        }
    }

    private func petButton(size: CGFloat) -> some View {
        Button(intent: PetCatIntent()) {
            CatView(outfit: s.outfit, size: size, mood: mood, animated: false)
                .overlay(alignment: .topTrailing) {
                    if s.recentlyPetted {
                        Image(systemName: "heart.fill").font(.system(size: size * 0.22)).foregroundStyle(Color.tomato)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var bar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.leafLight.opacity(0.6))
                Capsule().fill(Color.leaf).frame(width: g.size.width * s.progress)
            }
        }
        .frame(height: 7)
    }

    private func action<I: AppIntent>(_ intent: I, art: String, title: String, tint: Color, enabled: Bool = true) -> some View {
        Button(intent: intent) {
            HStack(spacing: 6) {
                ArtView(id: art, size: 20, line: 1.4)
                Text(title).font(.system(size: 13, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(enabled ? 0.18 : 0.07)))
            .foregroundStyle(enabled ? Color.ink : Color.inkSoft)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var waterButton: some View {
        action(LogWaterIntent(), art: "water", title: "\(s.waterToday)/\(s.waterGoal ?? 8) +1", tint: .sky)
    }

    private var claimButton: some View {
        action(ClaimCoinsIntent(), art: "coin", title: s.claimableNow > 0 ? "+\(s.claimableNow)" : "\((s.coins ?? 0).formatted())",
               tint: .sun, enabled: s.claimableNow > 0)
    }

    private var feedButton: some View {
        action(FeedCatIntent(), art: "fish", title: "\(s.fullness ?? 0)%", tint: .grass, enabled: (s.treats ?? 0) > 0)
    }

    private func questRow(_ q: WidgetQuest) -> some View {
        HStack(spacing: 8) {
            Image(systemName: q.icon).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hexString: q.tint))
                .frame(width: 26, height: 26).background(Circle().fill(Color(hexString: q.tint).opacity(0.16)))
            VStack(alignment: .leading, spacing: 2) {
                Text(q.title).font(.system(size: 13, weight: .semibold, design: .rounded)).lineLimit(1)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.leafLight.opacity(0.6))
                        Capsule().fill(Color(hexString: q.tint)).frame(width: g.size.width * min(1, Double(q.value) / Double(max(1, q.target))))
                    }
                }
                .frame(height: 5)
            }
            if q.claimed {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.leaf)
            } else {
                Button(intent: ClaimQuestIntent(questID: q.id)) {
                    HStack(spacing: 3) {
                        ArtView(id: "coin", size: 14, line: 1.1)
                        Text(q.done ? "Claim" : "\(q.reward)").font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(q.done ? Color.honey : Color.honey.opacity(0.2)))
                }
                .buttonStyle(.plain)
                .disabled(!q.done)
            }
        }
    }
}

struct MeowtrekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MeowtrekWidget", provider: Provider()) { entry in
            MeowtrekWidgetView(entry: entry)
                .foregroundStyle(Color.ink)
                .fontDesign(.rounded)
                .containerBackground(for: .widget) { Color.cream }
                .widgetURL(URL(string: "meowtrek://home"))
        }
        .configurationDisplayName("Meowtrek")
        .description("Today's steps with your cat. Tap to log water, claim coins, feed and pet your cat.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct MeowtrekWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeowtrekWidget()
        TrekLiveActivity()
    }
}

struct TrekLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrekActivityAttributes.self) { ctx in
            HStack(spacing: 12) {
                CatView(outfit: outfit(ctx.attributes), size: 54, mood: .happy, animated: false)
                VStack(alignment: .leading, spacing: 2) {
                    Label(ctx.attributes.kind, systemImage: ctx.attributes.symbol).font(.caption.weight(.bold)).foregroundStyle(Color.grassDark)
                    Text(String(format: "%.2f km", ctx.state.meters / 1000)).font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    timer(ctx.state).font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("\(pace(ctx.state.pace)) /km").font(.caption.weight(.semibold)).foregroundStyle(Color.inkSoft)
                }
            }
            .padding(14)
            .foregroundStyle(Color.ink)
            .activityBackgroundTint(Color.cream)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(String(format: "%.2f km", ctx.state.meters / 1000), systemImage: ctx.attributes.symbol)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(ctx.state).font(.system(size: 17, weight: .bold, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(ctx.attributes.petName) is walking with you · \(pace(ctx.state.pace)) /km")
                        .font(.caption.weight(.semibold))
                }
            } compactLeading: {
                Image(systemName: ctx.attributes.symbol).foregroundStyle(Color.grass)
            } compactTrailing: {
                Text(String(format: "%.1f", ctx.state.meters / 1000)).font(.caption.weight(.bold)).monospacedDigit()
            } minimal: {
                Image(systemName: ctx.attributes.symbol).foregroundStyle(Color.grass)
            }
        }
    }

    private func outfit(_ a: TrekActivityAttributes) -> [Slot: Item] {
        Dictionary(uniqueKeysWithValues: a.equipped.compactMap { k, v in
            guard let s = Slot(rawValue: k), let it = Catalog.item(v) else { return nil }
            return (s, it)
        })
    }

    @ViewBuilder private func timer(_ s: TrekActivityAttributes.ContentState) -> some View {
        if let start = s.timerStart {
            Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit()
        } else {
            Text(Duration.seconds(s.elapsed).formatted(.time(pattern: .minuteSecond))).monospacedDigit()
        }
    }

    private func pace(_ p: TimeInterval) -> String {
        guard p > 0, p < 3600 else { return "–" }
        return String(format: "%d'%02d\"", Int(p) / 60, Int(p) % 60)
    }
}

private func shortSteps(_ n: Int) -> String {
    n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
}
