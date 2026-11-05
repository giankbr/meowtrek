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
                    Text(s.stepsToday.formatted()).font(.page(26)).minimumScaleFactor(0.7)
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
                        Text(s.stepsToday.formatted()).font(.page(32))
                        Text("of \(s.goal.formatted()) steps").font(.page(12, .regular)).italic().foregroundStyle(Color.inkSoft)
                        bar
                    }
                }
                Text("\(s.petName)'s errands").font(.page(16))
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
                Text(s.stepsToday.formatted()).font(.page(26))
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
        CrayonBar(value: s.progress)
    }

    private func action<I: AppIntent>(_ intent: I, art: String, title: String, tint: Color, enabled: Bool = true) -> some View {
        Button(intent: intent) {
            HStack(spacing: 6) {
                ArtView(id: art, size: 20, line: 1.4)
                Text(title).font(.page(13)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(PencilBox(tint: tint, enabled: enabled))
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
                Text(q.title).font(.page(13, .semibold)).lineLimit(1).strikethrough(q.claimed, color: Color.inkSoft)
                CrayonBar(value: Double(q.value) / Double(max(1, q.target)), color: Color(hexString: q.tint), height: 5)
            }
            if q.claimed {
                InkStamp(text: loc("Done"))
            } else {
                Button(intent: ClaimQuestIntent(questID: q.id)) {
                    HStack(spacing: 3) {
                        ArtView(id: "coin", size: 14, line: 1.1)
                        Text(q.done ? loc("Collect") : "\(q.reward)").font(.page(12))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(PencilBox(tint: .honey, enabled: q.done))
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
                .containerBackground(for: .widget) { WidgetPaperBackground() }
                .widgetURL(URL(string: "meowtrek://home"))
        }
        .configurationDisplayName("Meowtrek")
        .description("Today's page with your cat. Tap to sip water, collect coins, share a snack or give a pat.")
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
                    Text(String(format: "%.2f km", ctx.state.meters / 1000)).font(.page(28))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    timer(ctx.state).font(.page(20))
                    Text("\(pace(ctx.state.pace)) /km").font(.caption.weight(.semibold)).foregroundStyle(Color.inkSoft)
                }
            }
            .padding(14)
            .foregroundStyle(Color.ink)
            .background(WidgetPaperBackground())
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
                    Text("\(ctx.attributes.petName) is right beside you · \(pace(ctx.state.pace)) /km")
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
