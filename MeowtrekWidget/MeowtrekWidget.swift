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
            HStack(spacing: 14) {
                CatView(outfit: s.outfit, size: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(s.petName) · \(L(s.mood))").font(.caption.weight(.semibold)).foregroundStyle(Color.inkSoft)
                    Text(s.stepsToday.formatted()).font(.system(size: 30, weight: .bold))
                    Text("/ \(s.goal.formatted()) steps").font(.caption).foregroundStyle(Color.inkSoft)
                    bar
                    Text(s.stepsToday >= s.goal ? "Goal reached 🎉" : "🔥 \(s.streak) · \(max(0, s.goal - s.stepsToday).formatted()) to go")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Color.leafDark)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    CatView(outfit: s.outfit, size: 58)
                    Spacer()
                    Text("🔥\(s.streak)").font(.caption.weight(.bold))
                }
                Spacer(minLength: 0)
                Text(s.stepsToday.formatted()).font(.system(size: 24, weight: .bold))
                bar
            }
        }
    }

    private var bar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.leafLight.opacity(0.5))
                Capsule().fill(Color.leaf).frame(width: g.size.width * s.progress)
            }
        }
        .frame(height: 7)
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
        .description("Today's steps with your cat.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
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
