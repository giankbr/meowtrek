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

struct PawstepWidgetView: View {
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
                Text("\(s.petName) · \(s.mood)").font(.caption2.weight(.semibold))
                Text("\(s.stepsToday.formatted()) steps").font(.headline)
                ProgressView(value: s.progress)
            }
        case .systemMedium:
            HStack(spacing: 14) {
                CatView(outfit: s.outfit, size: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(s.petName) · \(s.mood)").font(.caption.weight(.semibold)).foregroundStyle(Color.inkSoft)
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

struct PawstepWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PawstepWidget", provider: Provider()) { entry in
            PawstepWidgetView(entry: entry)
                .foregroundStyle(Color.ink)
                .fontDesign(.rounded)
                .containerBackground(for: .widget) { Color.cream }
                .widgetURL(URL(string: "pawstep://home"))
        }
        .configurationDisplayName("Pawstep")
        .description("Today's steps with your cat.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct PawstepWidgetBundle: WidgetBundle {
    var body: some Widget { PawstepWidget() }
}

private func shortSteps(_ n: Int) -> String {
    n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)"
}
