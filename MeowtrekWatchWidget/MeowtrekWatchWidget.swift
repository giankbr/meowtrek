import SwiftUI
import WidgetKit

struct WatchEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry { WatchEntry(date: .now, snap: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: .now, snap: WidgetBridge.read() ?? .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let entry = WatchEntry(date: .now, snap: WidgetBridge.read() ?? .sample)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct MeowtrekComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WatchEntry
    private var s: WidgetSnapshot { entry.snap }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: s.progress) {
                Image(systemName: "pawprint.fill")
            } currentValueLabel: {
                Text(short(s.stepsToday)).font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        case .accessoryCorner:
            Text(short(s.stepsToday))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .widgetCurvesContent()
                .widgetLabel {
                    Gauge(value: s.progress) { Text("Steps") }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
        case .accessoryInline:
            Label("\(s.stepsToday.formatted()) steps with \(s.petName)", systemImage: "pawprint.fill")
        default:
            HStack(spacing: 6) {
                CatView(outfit: s.outfit, size: 40, mood: s.progress >= 1 ? .happy : CatMood(s.mood), animated: false)
                    .frame(width: 42, height: 50)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.petName).font(.system(size: 13, weight: .semibold, design: .serif)).italic().widgetAccentable()
                    Text(s.stepsToday.formatted()).font(.system(size: 21, weight: .bold, design: .serif))
                    ProgressView(value: s.progress).tint(.green)
                }
            }
        }
    }

    private func short(_ n: Int) -> String { n >= 1000 ? String(format: "%.1fK", Double(n) / 1000) : "\(n)" }
}

@main
struct MeowtrekComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MeowtrekComplication", provider: WatchProvider()) { entry in
            MeowtrekComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Meowtrek")
        .description("Today's page of steps, with your cat.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
