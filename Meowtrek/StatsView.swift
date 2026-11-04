import SwiftUI
import Charts

struct StatsView: View {
    @Environment(AppState.self) private var state

    enum Tab: String, CaseIterable {
        case steps = "Steps", trends = "Trends", records = "Records", health = "Health"
        var icon: String {
            switch self {
            case .steps: "shoeprints.fill"
            case .trends: "sparkles"
            case .records: "trophy.fill"
            case .health: "heart.fill"
            }
        }
    }

    enum Range: String, CaseIterable { case day = "Day", week = "Week", month = "Month", year = "Year" }

    private struct Bar: Identifiable {
        let id: Int
        let steps: Int
        let hit: Bool
    }

    @State private var tab: Tab = .steps
    @State private var range: Range = .month
    @State private var month = Self.monthStart(.now)
    @State private var selectedDay: Date?
    @Namespace private var rangeNS

    private static var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }
    private var cal: Calendar { Self.cal }
    private var today: Date { cal.startOfDay(for: .now) }
    private static func monthStart(_ d: Date) -> Date { cal.dateInterval(of: .month, for: d)!.start }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: loc("Stats")) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(Color.pumpkin)
                        Text("\(state.streak)").font(.game(16, .black))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.paper)).overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                }
                tabBar
                switch tab {
                case .steps: stepsTab
                case .trends: trendsTab
                case .records: recordsTab
                case .health: healthTab
                }
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.ink)
        .background(Color.cream)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.self) { t in
                Button { withAnimation(.snappy) { tab = t } } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.icon).font(.system(size: 15, weight: .black))
                        Text(L(t.rawValue)).font(.game(11, .black)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.chunky(tab == t ? .grass : .paper, text: tab == t ? .white : .inkSoft, radius: 14, padH: 4, padV: 7))
            }
        }
    }

    // MARK: Steps

    private func days(from start: Date, count: Int) -> [Date] {
        (0..<count).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    private var rangeDays: [Date] {
        switch range {
        case .day: return [today]
        case .week: return days(from: cal.dateInterval(of: .weekOfYear, for: today)!.start, count: 7)
        case .month: return days(from: month, count: cal.range(of: .day, in: .month, for: month)!.count)
        case .year:
            let year = cal.dateInterval(of: .year, for: today)!
            return days(from: year.start, count: cal.range(of: .day, in: .year, for: today)!.count)
        }
    }

    private var bars: [Bar] {
        let goal = state.goal
        if range == .day {
            return state.steps.hourly.enumerated().map { h, s in Bar(id: h + 1, steps: s, hit: s >= 250) }
        }
        if range == .year {
            let elapsed = rangeDays.filter { $0 <= today }
            return (1...12).map { m in
                let total = elapsed.filter { cal.component(.month, from: $0) == m }
                    .reduce(0) { $0 + state.steps.steps(on: $1) }
                return Bar(id: m, steps: total, hit: false)
            }
        }
        return rangeDays.enumerated().map { i, d in
            let s = d <= today ? state.steps.steps(on: d) : 0
            return Bar(id: i + 1, steps: s, hit: s >= goal)
        }
    }

    private var xMarks: [Int] {
        switch range {
        case .day: [1, 7, 13, 19]
        case .week: Array(1...7)
        case .month: [1, 10, 20, rangeDays.count]
        case .year: Array(1...12)
        }
    }

    private func xLabel(_ i: Int) -> String {
        switch range {
        case .week: ["M", "T", "W", "T", "F", "S", "S"][i - 1]
        case .year: cal.veryShortMonthSymbols[i - 1]
        case .day: "\(i - 1)h"
        default: "\(i)"
        }
    }

    private var subtitle: String {
        switch range {
        case .day: "steps · today"
        case .week: "steps · this week"
        case .month: "steps · \(month.formatted(.dateTime.month(.wide)))"
        case .year: "steps · \(today.formatted(.dateTime.year()))"
        }
    }

    private var stepsTab: some View {
        let elapsed = rangeDays.filter { $0 <= today }
        let perDay = elapsed.map { state.steps.steps(on: $0) }
        let total = perDay.reduce(0, +)
        let avg = total / max(1, elapsed.count)
        let hits = perDay.filter { $0 >= state.goal }.count
        let flights = elapsed.reduce(0) { $0 + (state.steps.flights[$1] ?? 0) }
        let meters = elapsed.reduce(0.0) { $0 + state.steps.meters(on: $1) }
        let kcal = Int(elapsed.reduce(0.0) { $0 + state.steps.kcal(on: $1) })
        let est = state.steps.source == .health ? "" : " · est."

        return VStack(alignment: .leading, spacing: 16) {
            rangePicker

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(total.formatted()).font(.game(38, .black)).contentTransition(.numericText())
                    Text(subtitle).font(.game(14, .bold)).foregroundStyle(Color.inkSoft)
                }
                Text(range == .day ? "\(state.remaining.formatted()) to go today"
                     : "Average \(avg.formatted()) a day · goal hit \(hits) of \(elapsed.count)")
                    .font(.game(13, .black))
                    .foregroundStyle(Color.grassDark)

                if range == .day { ring }
                chart(avg: avg).padding(.top, 8)
            }
            .card()

            HStack {
                metric("map.fill", .sky, state.distanceText(meters), loc("distance\(est)"))
                metric("timer", .grape, activeTime(total), loc("active · est."))
                metric("flame.fill", .tomato, kcal.formatted(), loc("kcal\(est)"))
                metric("stairs", .grass, state.steps.source == .health ? "\(flights)" : "–", loc("flights"))
            }
            .card(padding: 12)

            calendarCard
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(Range.allCases, id: \.self) { r in
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { range = r } } label: {
                    Text(L(r.rawValue)).font(.game(14, .black))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background {
                            if range == r { Capsule().fill(Color.sun).matchedGeometryEffect(id: "range", in: rangeNS) }
                        }
                        .foregroundStyle(range == r ? Color.ink : Color.inkSoft)
                }
                .buttonStyle(SquishStyle())
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.paper))
        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color.leafLight.opacity(0.5), lineWidth: 18)
            Circle().trim(from: 0, to: state.progress)
                .stroke(Color.leaf, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack {
                Text("\(Int(state.progress * 100))%").font(.title.weight(.bold))
                Text("of \(state.goal.formatted())").font(.caption).foregroundStyle(Color.inkSoft)
            }
        }
        .frame(width: 170, height: 170)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func chart(avg: Int) -> some View {
        Chart {
            ForEach(bars) { b in
                BarMark(x: .value("Day", String(b.id)), y: .value("Steps", b.steps), width: .ratio(0.7))
                    .foregroundStyle(b.hit ? Color.leaf : Color.leafLight)
                    .cornerRadius(3)
            }
            if range == .week || range == .month {
                RuleMark(y: .value("Goal", state.goal))
                    .foregroundStyle(Color.inkSoft.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("goal").font(.caption2).foregroundStyle(Color.inkSoft)
                    }
                RuleMark(y: .value("Average", avg))
                    .foregroundStyle(Color.leafDark.opacity(0.5))
                    .annotation(position: .top, alignment: .leading) {
                        Text("avg").font(.caption2).foregroundStyle(Color.leafDark)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: xMarks.map(String.init)) { v in
                AxisValueLabel {
                    if let i = v.as(String.self).flatMap(Int.init) { Text(xLabel(i)) }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200)
    }

    private func activeTime(_ steps: Int) -> String {
        let minutes = steps / 110
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func metric(_ symbol: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            GameIcon(symbol: symbol, tint: tint, size: 34)
            Text(value).font(.game(16, .black)).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.game(10, .bold)).foregroundStyle(Color.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Calendar

    private var calendarCard: some View {
        let first = month
        let offset = (cal.component(.weekday, from: first) + 5) % 7
        let gridStart = cal.date(byAdding: .day, value: -offset, to: first)!
        let count = cal.range(of: .day, in: .month, for: first)!.count
        let weeks = Int(ceil(Double(offset + count) / 7))
        let isCurrent = first == Self.monthStart(.now)

        return VStack(spacing: 10) {
            HStack {
                Text(first.formatted(.dateTime.month(.wide).year())).font(.game(18, .black))
                Spacer()
                Button { shiftMonth(-1) } label: { navIcon("chevron.left") }
                Button { shiftMonth(1) } label: { navIcon("chevron.right") }
                    .disabled(isCurrent).opacity(isCurrent ? 0.3 : 1)
            }
            .buttonStyle(.plain)

            if let d = selectedDay { dayDetail(d) }

            HStack(spacing: 2) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S", "Week"].enumerated()), id: \.offset) { _, d in
                    Text(d).font(.caption2.weight(.semibold)).foregroundStyle(Color.inkSoft).frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<weeks, id: \.self) { w in
                let dates = days(from: cal.date(byAdding: .day, value: w * 7, to: gridStart)!, count: 7)
                let weekTotal = dates.filter { cal.isDate($0, equalTo: first, toGranularity: .month) && $0 <= today }
                    .reduce(0) { $0 + state.steps.steps(on: $1) }
                HStack(spacing: 2) {
                    ForEach(dates, id: \.self) { d in
                        Button { withAnimation(.snappy) { selectedDay = selectedDay == d ? nil : d } } label: {
                            dayCell(d, inMonth: cal.isDate(d, equalTo: first, toGranularity: .month))
                        }
                        .buttonStyle(.plain)
                        .disabled(d > today)
                    }
                    Text(weekTotal > 0 ? shortSteps(weekTotal) : "")
                        .font(.caption2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .card()
    }

    private func navIcon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 13, weight: .black))
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.sun))
            .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
    }

    private func dayDetail(_ d: Date) -> some View {
        let s = state.steps.steps(on: d)
        let pct = Int(Double(s) / Double(max(1, state.goal)) * 100)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(d.formatted(.dateTime.weekday(.wide).day().month())).font(.subheadline.weight(.bold))
                Text("\(s.formatted()) steps · \(state.distanceText(state.steps.meters(on: d))) · \(Int(state.steps.kcal(on: d))) kcal")
                    .font(.caption).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Group {
                if state.hitGoal(d) && s >= state.goal {
                    Label("Goal", systemImage: "checkmark.circle.fill").foregroundStyle(Color.grassDark)
                } else if state.hitGoal(d) {
                    Label("Frozen", systemImage: "snowflake").foregroundStyle(Color.skyDark)
                } else {
                    Text("\(pct)%").foregroundStyle(Color.inkSoft)
                }
            }
            .font(.game(13, .bold))
        }
        .padding(10)
        .background(Color.cream, in: RoundedRectangle(cornerRadius: 12))
        .transition(.opacity)
    }

    private func dayCell(_ d: Date, inMonth: Bool) -> some View {
        let future = d > today
        let s = state.steps.steps(on: d)
        let hit = !future && state.hitGoal(d)
        return VStack(spacing: 2) {
            Text("\(cal.component(.day, from: d))")
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(hit ? Color.grass : Color.cream))
                .foregroundStyle(hit ? .white : Color.ink)
                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
                .overlay(Circle().stroke(d == selectedDay ? Color.honey : d == today ? Color.leafDark : .clear, lineWidth: 2))
            Text(future || s == 0 ? " " : shortSteps(s))
                .font(.system(size: 9))
                .foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .opacity(inMonth ? 1 : 0.3)
    }

    private func shiftMonth(_ by: Int) {
        withAnimation(.snappy) {
            month = cal.date(byAdding: .month, value: by, to: month)!
            range = .month
        }
    }

    // MARK: Trends

    private var weekly: [Bar] {
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: today)!.start
        return (0..<12).reversed().map { w in
            let start = cal.date(byAdding: .weekOfYear, value: -w, to: thisWeek)!
            let elapsed = days(from: start, count: 7).filter { $0 <= today }
            let avg = elapsed.reduce(0) { $0 + state.steps.steps(on: $1) } / max(1, elapsed.count)
            return Bar(id: 12 - w, steps: avg, hit: avg >= state.goal)
        }
    }

    private var trendsTab: some View {
        let data = weekly
        let now = data.last?.steps ?? 0, before = data.dropLast().last?.steps ?? 0
        let change = before == 0 ? 0 : Int((Double(now - before) / Double(before) * 100).rounded())

        return VStack(alignment: .leading, spacing: 16) {
            InsightCard()
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily average, last 12 weeks").font(.headline)
                Text(change >= 0 ? "Up \(change)% vs last week" : "Down \(-change)% vs last week")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(change >= 0 ? Color.leafDark : Color(hex: 0xC0645A))
                Chart {
                    ForEach(data) { b in
                        AreaMark(x: .value("Week", b.id), y: .value("Avg", b.steps))
                            .foregroundStyle(Color.leafLight.opacity(0.5))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Week", b.id), y: .value("Avg", b.steps))
                            .foregroundStyle(Color.leaf)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Week", b.id), y: .value("Avg", b.steps))
                            .foregroundStyle(b.hit ? Color.leafDark : Color.leaf)
                            .symbolSize(30)
                    }
                    RuleMark(y: .value("Goal", state.goal))
                        .foregroundStyle(Color.inkSoft.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartXAxis(.hidden)
                .frame(height: 200)
                .padding(.top, 8)
            }
            .card()
        }
    }

    // MARK: Records

    private var recordsTab: some View {
        let daily = state.steps.daily.filter { $0.key <= today }
        let best = daily.max { $0.value < $1.value }
        let sorted = daily.keys.sorted()
        var longest = 0, run = 0
        for d in sorted {
            run = (daily[d] ?? 0) >= state.goal ? run + 1 : 0
            longest = max(longest, run)
        }
        let weeks = Dictionary(grouping: daily) { cal.dateInterval(of: .weekOfYear, for: $0.key)!.start }
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        let bestWeek = weeks.max { $0.value < $1.value }

        return VStack(spacing: 12) {
            record("trophy.fill", .sun, loc("Best day"), best.map { "\($0.value.formatted()) steps" } ?? "–",
                   best.map { $0.key.formatted(date: .abbreviated, time: .omitted) } ?? "")
            record("calendar", .sky, loc("Best week"), bestWeek.map { "\($0.value.formatted()) steps" } ?? "–",
                   bestWeek.map { "Week of \($0.key.formatted(date: .abbreviated, time: .omitted))" } ?? "")
            record("flame.fill", .pumpkin, loc("Longest streak"), "\(state.longestStreak) days", loc("Current: \(state.streak) days · \(state.streakFreezes) freezes"))
            record("globe.asia.australia.fill", .grass, loc("All time"), "\(daily.values.reduce(0, +).formatted()) steps", loc("\(daily.count) days tracked"))

            Text("Badges").font(.game(22, .black)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(state.content.achievements) { a in badge(a) }
            }
        }
    }

    private func badge(_ a: Achievement) -> some View {
        let v = state.value(a), unlocked = state.isUnlocked(a), claimed = state.isClaimed(a)
        return VStack(spacing: 6) {
            GameIcon(symbol: a.icon, tint: Color(hexString: a.tint), size: 52, muted: !unlocked)
            Text(a.title).font(.game(15, .black))
            Text(a.detail).font(.game(11, .bold)).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center).lineLimit(2)
            if claimed {
                Tag(text: loc("Claimed"), color: .grass)
            } else if unlocked {
                Button("Claim") { withAnimation { state.claim(a) } }.buttonStyle(.chunky(.sun, padH: 12, padV: 5))
            } else {
                ProgressBar(value: Double(v) / Double(a.value), color: Color(hexString: a.tint), height: 10)
                Text("\(shortSteps(min(v, a.value))) / \(shortSteps(a.value))").font(.game(11, .bold)).foregroundStyle(Color.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .card(padding: 12)
    }

    private func record(_ symbol: String, _ tint: Color, _ title: String, _ value: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            GameIcon(symbol: symbol, tint: tint, size: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                Text(value).font(.game(18, .black))
                Text(detail).font(.game(11, .bold)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
        }
        .card()
    }

    // MARK: Health

    private var healthTab: some View {
        let connected = state.steps.source == .health
        return VStack(alignment: .leading, spacing: 10) {
            Label(connected ? "Apple Health connected" : "Showing demo data",
                  systemImage: connected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.headline)
                .foregroundStyle(connected ? Color.leafDark : Color(hex: 0xC08A2A))
            Text(connected
                 ? "Steps and flights come from Apple Health. Distance, active time and calories are estimates from steps."
                 : "No step data from Apple Health yet. Allow access in Settings › Health › Data Access & Devices › Meowtrek.")
                .font(.subheadline)
                .foregroundStyle(Color.inkSoft)
            Button("Refresh") { Task { await state.steps.load() } }
                .buttonStyle(.chunky(.grass, text: .white))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
