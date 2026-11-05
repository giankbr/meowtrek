import SwiftUI
import Charts

/// The walk journal: one page that reads like a diary of your steps rather than a dashboard.
struct StatsView: View {
    @Environment(AppState.self) private var state

    enum Range: String, CaseIterable {
        case day = "Today", week = "This week", month = "This month", year = "This year"
    }

    private struct Point: Identifiable {
        let id: Int
        let steps: Int
        let hit: Bool
        var future = false
        var current = false
    }

    @State private var range: Range = .week
    @State private var month = Self.monthStart(.now)
    @State private var selectedDay: Date?
    @State private var pickedX: Double?
    @State private var showReview = false

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
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: loc("Walk journal")) { streakTag }
                reviewCard
                journal
                stickerCalendar
                notes
                bests
                sourceNote
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .foregroundStyle(Color.ink)
        .paperBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showReview) { YearReviewView() }
    }

    private var reviewCard: some View {
        let year = cal.component(.year, from: today)
        return Button { showReview = true } label: {
            HStack(spacing: 12) {
                CatView(outfit: state.outfit, size: 46, mood: .happy, animated: false).frame(width: 46, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your \(String(year)) in review").font(.story(18, .bold))
                    Text("A year of walks with \(state.petName)").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.game(15, .bold)).foregroundStyle(Color.inkSoft)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(PaperShape(radius: 18, wobble: 1, seed: 19).fill(Color.sun.opacity(0.18)))
            .overlay(PaperShape(radius: 18, wobble: 1, seed: 19).stroke(Color.sun.opacity(0.5), lineWidth: 1.4))
        }
        .buttonStyle(SquishStyle())
    }

    private var streakTag: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill").foregroundStyle(Color.pumpkin)
            Text("\(state.streak)-day streak").font(.story(14, .semibold))
        }
        .padding(.horizontal, 10).padding(.top, 9).padding(.bottom, 6)
        .background(PaperShape(radius: 4, seed: 31).fill(Color.paper))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1.5)
        .taped(.top, angle: -5, color: .pumpkin, width: 34)
        .rotationEffect(.degrees(3))
    }

    // MARK: Journal page

    private func days(from start: Date, count: Int) -> [Date] {
        (0..<count).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    private var rangeDays: [Date] {
        switch range {
        case .day: return [today]
        case .week: return days(from: cal.dateInterval(of: .weekOfYear, for: today)!.start, count: 7)
        case .month: return days(from: Self.monthStart(today), count: cal.range(of: .day, in: .month, for: today)!.count)
        case .year:
            let year = cal.dateInterval(of: .year, for: today)!
            return days(from: year.start, count: cal.range(of: .day, in: .year, for: today)!.count)
        }
    }

    private var points: [Point] {
        let goal = state.goal
        if range == .day {
            let now = cal.component(.hour, from: .now)
            var run = 0
            return state.steps.hourly.enumerated().map { h, s in
                run += h > now ? 0 : s
                return Point(id: h + 1, steps: run, hit: run >= goal, future: h > now, current: h == now)
            }
        }
        if range == .year {
            let elapsed = rangeDays.filter { $0 <= today }
            let thisMonth = cal.component(.month, from: today)
            return (1...12).map { m in
                let ds = elapsed.filter { cal.component(.month, from: $0) == m }
                let avg = ds.reduce(0) { $0 + state.steps.steps(on: $1) } / max(1, ds.count)
                return Point(id: m, steps: avg, hit: avg >= goal, future: m > thisMonth, current: m == thisMonth)
            }
        }
        return rangeDays.enumerated().map { i, d in
            let s = d <= today ? state.steps.steps(on: d) : 0
            return Point(id: i + 1, steps: s, hit: s >= goal, future: d > today, current: d == today)
        }
    }

    private var journal: some View {
        let elapsed = rangeDays.filter { $0 <= today }
        let perDay = elapsed.map { state.steps.steps(on: $0) }
        let total = perDay.reduce(0, +)
        let avg = total / max(1, elapsed.count)
        let hits = perDay.filter { $0 >= state.goal }.count
        let meters = elapsed.reduce(0.0) { $0 + state.steps.meters(on: $1) }
        let kcal = Int(elapsed.reduce(0.0) { $0 + state.steps.kcal(on: $1) })
        let flights = elapsed.reduce(0) { $0 + (state.steps.flights[$1] ?? 0) }

        return VStack(alignment: .leading, spacing: 0) {
            folderTabs.zIndex(1)
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead).font(.story(15, .regular)).italic().foregroundStyle(Color.inkSoft)
                    Text("\(total.formatted()) steps").font(.story(38, .bold)).contentTransition(.numericText())
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(sentence(avg: avg, hits: hits, days: elapsed.count, meters: meters))
                        .font(.game(14, .medium)).foregroundStyle(Color.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                chart
                Rectangle().fill(Color.sky.opacity(0.35)).frame(height: 1)
                numbers(meters: meters, steps: total, kcal: kcal, flights: flights)
            }
            .card(padding: 18)
        }
    }

    private var folderTabs: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Range.allCases, id: \.self) { r in
                let on = range == r
                Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { range = r } } label: {
                    Text(L(r.rawValue))
                        .font(.story(13, on ? .bold : .medium))
                        .foregroundStyle(on ? Color.ink : Color.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .padding(.top, on ? 10 : 7).padding(.bottom, on ? 10 : 6)
                        .frame(maxWidth: .infinity)
                        .background(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous)
                            .fill(on ? Color.paper : Color(hex: 0xEAE0CB)))
                        .offset(y: on ? 4 : 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
    }

    private var lead: String {
        switch range {
        case .day: loc("So far today")
        case .week: loc("This week, together we walked")
        case .month: loc("In \(today.formatted(.dateTime.month(.wide))) we walked")
        case .year: loc("In \(today.formatted(.dateTime.year())) we walked")
        }
    }

    private func sentence(avg: Int, hits: Int, days: Int, meters: Double) -> String {
        if range == .day {
            return state.remaining == 0
                ? loc("Goal reached, about \(state.distanceText(meters)) on foot. \(state.petName) is purring.")
                : loc("\(state.remaining.formatted()) more to reach the goal, about \(state.distanceText(meters)) so far.")
        }
        if range == .year {
            return loc("A usual day this year was \(avg.formatted()) steps.")
        }
        return loc("A usual day was \(avg.formatted()) steps, and \(hits) of \(days) days reached the goal.")
    }

    private var chart: some View {
        let data = points
        let shown = data.filter { !$0.future }
        let top = Double(max(shown.map(\.steps).max() ?? 0, state.goal, 1)) * 1.2
        let picked = pickedX.map { Int($0.rounded()) }
        return Chart {
            ForEach(shown) { p in
                AreaMark(x: .value("When", Double(p.id)), y: .value("Steps", p.steps))
                    .foregroundStyle(LinearGradient(colors: [Color.grass.opacity(0.28), Color.grass.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("When", Double(p.id)), y: .value("Steps", p.steps))
                    .foregroundStyle(Color.grassDark)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                if range != .day || p.current {
                    PointMark(x: .value("When", Double(p.id)), y: .value("Steps", p.steps))
                        .symbol {
                            if p.hit && range != .day {
                                Image(systemName: "pawprint.fill").font(.system(size: data.count > 20 ? 8 : 11))
                                    .foregroundStyle(Color.grassDark)
                            } else {
                                Circle().fill(p.current ? Color.sun : Color.paper)
                                    .overlay(Circle().stroke(Color.grassDark, lineWidth: 1.5))
                                    .frame(width: data.count > 20 ? 6 : 9)
                            }
                        }
                }
            }
            RuleMark(y: .value("Goal", state.goal))
                .foregroundStyle(Color.tomato.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [2, 4]))
                .annotation(position: .top, alignment: .leading, spacing: 2) {
                    Text("goal \(shortSteps(state.goal))").font(.story(11, .medium)).italic().foregroundStyle(Color.tomato)
                }
            if let p = picked, let b = data.first(where: { $0.id == p }), !b.future {
                RuleMark(x: .value("When", Double(p)))
                    .foregroundStyle(Color.ink.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 1) {
                            Text(calloutLabel(p)).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
                            Text(b.steps.formatted()).font(.story(15, .bold)).foregroundStyle(Color.ink)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(PaperShape(radius: 6, seed: 9).fill(Color.paper))
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
            }
        }
        .chartXScale(domain: 0.5...(Double(data.count) + 0.5))
        .chartYScale(domain: 0...top)
        .chartXSelection(value: $pickedX)
        .chartXAxis {
            AxisMarks(values: xMarks.map(Double.init)) { v in
                AxisValueLabel {
                    if let i = v.as(Double.self) { Text(xLabel(Int(i))).font(.game(11, .medium)).foregroundStyle(Color.inkSoft) }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 190)
        .sensoryFeedback(.selection, trigger: picked)
        .onChange(of: range) { pickedX = nil }
    }

    private var xMarks: [Int] {
        switch range {
        case .day: [1, 7, 13, 19, 24]
        case .week: Array(1...7)
        case .month: [1, 8, 15, 22, 29]
        case .year: Array(1...12)
        }
    }

    private func xLabel(_ i: Int) -> String {
        switch range {
        case .week: cal.veryShortWeekdaySymbols[i % 7]
        case .year: cal.veryShortMonthSymbols[i - 1]
        case .day: "\(i - 1)h"
        default: "\(i)"
        }
    }

    private func calloutLabel(_ i: Int) -> String {
        switch range {
        case .day: return loc("by \(String(format: "%02d:00", i))")
        case .year: return loc("\(cal.shortMonthSymbols[i - 1]) · usual day")
        default:
            guard i - 1 < rangeDays.count else { return "" }
            return rangeDays[i - 1].formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
    }

    private func numbers(meters: Double, steps: Int, kcal: Int, flights: Int) -> some View {
        let est = state.steps.source == .health ? "" : loc(" (est.)")
        let minutes = steps / 110
        let active = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        return LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 12) {
            numberLine("map", .skyDark, state.distanceText(meters), loc("covered"))
            numberLine("timer", .grapeDark, active, loc("on the move\(est)"))
            numberLine("flame", .tomato, kcal.formatted(), loc("kcal burned\(est)"))
            numberLine("stairs", .grassDark, state.steps.source == .health ? "\(flights)" : "–", loc("floors climbed"))
        }
    }

    private func numberLine(_ symbol: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.story(18, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.game(11, .medium)).foregroundStyle(Color.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: Sticker calendar

    private var stickerCalendar: some View {
        let first = month
        let offset = (cal.component(.weekday, from: first) + 5) % 7
        let count = cal.range(of: .day, in: .month, for: first)!.count
        let isCurrent = first == Self.monthStart(.now)
        let goalDays = (0..<count).map { cal.date(byAdding: .day, value: $0, to: first)! }.filter { $0 <= today && state.hitGoal($0) }.count
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 8) {
                    StoryHeading(text: loc("Sticker book"), size: 22, color: .grass)
                    Text("\(goalDays) paw stickers in \(first.formatted(.dateTime.month(.wide)))")
                        .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                }
                Spacer()
                HStack(spacing: 6) {
                    RoundIconButton(symbol: "chevron.left", size: 32) { shiftMonth(-1) }
                    RoundIconButton(symbol: "chevron.right", size: 32) { shiftMonth(1) }.disabled(isCurrent)
                }
            }
            VStack(spacing: 8) {
                Text(first.formatted(.dateTime.month(.wide).year())).font(.story(16, .semibold)).italic()
                    .frame(maxWidth: .infinity)
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(100..<107, id: \.self) { i in
                        Text(cal.veryShortWeekdaySymbols[(i - 99) % 7]).font(.game(11, .semibold)).foregroundStyle(Color.inkSoft)
                    }
                    ForEach(200..<(200 + offset), id: \.self) { _ in Color.clear.frame(height: 40) }
                    ForEach(0..<count, id: \.self) { i in
                        let d = cal.date(byAdding: .day, value: i, to: first)!
                        Button { withAnimation(.snappy) { selectedDay = selectedDay == d ? nil : d } } label: { sticker(d) }
                            .buttonStyle(SquishStyle())
                            .disabled(d > today)
                    }
                }
                if let d = selectedDay { dayDetail(d) }
            }
            .card(padding: 14)
        }
    }

    private func sticker(_ d: Date) -> some View {
        let day = cal.component(.day, from: d)
        let future = d > today
        let s = state.steps.steps(on: d)
        let hit = !future && state.hitGoal(d)
        let frozen = hit && s < state.goal
        let tilt = Double((day * 37) % 26) - 13
        return ZStack {
            if future {
                Circle().strokeBorder(Color.inkSoft.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                Text("\(day)").font(.game(12, .medium)).foregroundStyle(Color.inkSoft.opacity(0.5))
            } else if hit {
                Circle().fill(frozen ? Color.sky : Color.grass)
                    .overlay(Circle().strokeBorder(Color.paper, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                Image(systemName: frozen ? "snowflake" : "pawprint.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .rotationEffect(.degrees(tilt))
            } else {
                Circle().fill(Color.grass.opacity(s == 0 ? 0 : 0.1 + 0.4 * min(1, Double(s) / Double(max(1, state.goal)))))
                Text("\(day)").font(.game(12, .semibold)).foregroundStyle(Color.ink)
            }
        }
        .frame(width: 36, height: 36)
        .overlay(Circle().stroke(d == selectedDay ? Color.sunDark : d == today ? Color.ink.opacity(0.5) : .clear,
                                 style: StrokeStyle(lineWidth: 1.5, dash: d == today ? [3, 2] : [])).padding(-3))
        .frame(height: 40)
    }

    private func dayDetail(_ d: Date) -> some View {
        let s = state.steps.steps(on: d)
        let pct = Int(Double(s) / Double(max(1, state.goal)) * 100)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(d.formatted(.dateTime.weekday(.wide).day().month())).font(.story(15, .semibold))
                Text("\(s.formatted()) steps · \(state.distanceText(state.steps.meters(on: d))) · \(Int(state.steps.kcal(on: d))) kcal")
                    .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            if state.hitGoal(d) && s >= state.goal {
                Stamp(text: loc("Goal"), color: .grassDark, size: 40)
            } else if state.hitGoal(d) {
                Stamp(text: loc("Frozen"), color: .skyDark, size: 40)
            } else {
                Text("\(pct)%").font(.story(16, .bold)).foregroundStyle(Color.inkSoft)
            }
        }
        .padding(10)
        .background(SketchSquare())
        .transition(.opacity)
    }

    private func shiftMonth(_ by: Int) {
        withAnimation(.snappy) {
            month = cal.date(byAdding: .month, value: by, to: month)!
            selectedDay = nil
        }
    }

    // MARK: Notes

    private var weekly: [Point] {
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: today)!.start
        return (0..<12).reversed().map { w in
            let start = cal.date(byAdding: .weekOfYear, value: -w, to: thisWeek)!
            let elapsed = days(from: start, count: 7).filter { $0 <= today }
            let avg = elapsed.reduce(0) { $0 + state.steps.steps(on: $1) } / max(1, elapsed.count)
            return Point(id: 12 - w, steps: avg, hit: avg >= state.goal)
        }
    }

    private var notes: some View {
        let data = weekly
        let now = data.last?.steps ?? 0, before = data.dropLast().last?.steps ?? 0
        let change = before == 0 ? 0 : Int((Double(now - before) / Double(before) * 100).rounded())

        return VStack(alignment: .leading, spacing: 12) {
            StoryHeading(text: loc("Notes from \(state.petName)"), size: 22, color: .bubble)
            InsightCard()
            VStack(alignment: .leading, spacing: 8) {
                Text("A usual day, week by week").font(.story(16, .semibold))
                Text(change >= 0 ? "\(change)% more than the week before" : "\(-change)% less than the week before")
                    .font(.game(12, .medium))
                    .foregroundStyle(change >= 0 ? Color.grassDark : Color.tomato)
                Chart {
                    ForEach(data) { b in
                        LineMark(x: .value("Week", b.id), y: .value("Usual day", b.steps))
                            .foregroundStyle(Color.grape)
                            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Week", b.id), y: .value("Usual day", b.steps))
                            .symbol { Circle().fill(b.hit ? Color.grape : Color.paper).overlay(Circle().stroke(Color.grape, lineWidth: 1.5)).frame(width: 8) }
                    }
                    RuleMark(y: .value("Goal", state.goal))
                        .foregroundStyle(Color.tomato.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: Double(min(data.map(\.steps).min() ?? 0, state.goal)) * 0.85...Double(max(data.map(\.steps).max() ?? 1, state.goal)) * 1.08)
                .frame(height: 110)
            }
            .card()
        }
    }

    // MARK: Personal bests

    private var bests: some View {
        let daily = state.steps.daily.filter { $0.key <= today }
        let best = daily.max { $0.value < $1.value }
        let weeks = Dictionary(grouping: daily) { cal.dateInterval(of: .weekOfYear, for: $0.key)!.start }
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        let bestWeek = weeks.max { $0.value < $1.value }
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return VStack(alignment: .leading, spacing: 12) {
            StoryHeading(text: loc("Proudest moments"), size: 22, color: .sun)
            LazyVGrid(columns: cols, spacing: 12) {
                best1("star.fill", .sunDark, loc("Biggest day"), best.map { $0.value.formatted() } ?? "–",
                      best.map { $0.key.formatted(.dateTime.day().month(.abbreviated)) } ?? "", 0)
                best1("calendar", .skyDark, loc("Biggest week"), bestWeek.map { $0.value.formatted() } ?? "–",
                      bestWeek.map { loc("from \($0.key.formatted(.dateTime.day().month(.abbreviated)))") } ?? "", 1)
                best1("flame.fill", .pumpkin, loc("Longest streak"), loc("\(state.longestStreak) days"),
                      loc("\(state.streakFreezes) freezes saved"), 2)
                best1("globe.asia.australia.fill", .grassDark, loc("Since we met"), daily.values.reduce(0, +).formatted(),
                      loc("steps over \(daily.count) days"), 3)
            }
            Text("Badges").font(.story(18, .bold)).padding(.top, 6)
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(state.content.achievements) { a in badge(a) }
            }
        }
    }

    private func best1(_ symbol: String, _ tint: Color, _ title: String, _ value: String, _ detail: String, _ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle().stroke(tint.opacity(0.8), lineWidth: 1.6)
                Circle().inset(by: 3.5).stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            }
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(i.isMultiple(of: 2) ? -10 : 8))
            Text(title).font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
            Text(value).font(.story(20, .bold)).lineLimit(1).minimumScaleFactor(0.6)
            Text(detail).font(.game(11, .medium)).foregroundStyle(Color.inkSoft).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
        .rotationEffect(.degrees(i.isMultiple(of: 2) ? -0.8 : 0.8))
    }

    private func badge(_ a: Achievement) -> some View {
        let v = state.value(a), unlocked = state.isUnlocked(a), claimed = state.isClaimed(a)
        return VStack(spacing: 6) {
            GameIcon(symbol: a.icon, tint: Color(hexString: a.tint), size: 48, muted: !unlocked)
            Text(a.title).font(.story(15, .bold)).multilineTextAlignment(.center)
            Text(a.detail).font(.game(11, .medium)).foregroundStyle(Color.inkSoft).multilineTextAlignment(.center).lineLimit(2)
            if claimed {
                Stamp(text: loc("Earned"), color: .grassDark, size: 44)
            } else if unlocked {
                Button("Collect") { withAnimation { state.claim(a) } }.buttonStyle(.chunky(.sun, radius: 12, padH: 12, padV: 5))
            } else {
                ProgressBar(value: Double(v) / Double(a.value), color: Color(hexString: a.tint), height: 8)
                Text("\(shortSteps(min(v, a.value))) / \(shortSteps(a.value))").font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .card(padding: 12)
    }

    // MARK: Source

    private var sourceNote: some View {
        let connected = state.steps.source == .health
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: connected ? "heart.text.square" : "exclamationmark.circle")
                .font(.system(size: 18)).foregroundStyle(connected ? Color.tomato : Color.sunDark)
            VStack(alignment: .leading, spacing: 4) {
                Text(connected
                     ? "Steps and floors come from Apple Health. Distance, time on the move and kcal are worked out from your steps."
                     : "These pages use sample steps until Apple Health shares yours. Allow it in Settings › Health › Data Access & Devices › Meowtrek.")
                    .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Refresh steps") { Task { await state.steps.load() } }
                    .font(.story(13, .semibold)).foregroundStyle(Color.grassDark)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Year in review

/// A cozy end-of-year recap of the walking year, with a shareable card.
struct YearReviewView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?

    private var cal: Calendar { Calendar.current }
    private var year: Int { cal.component(.year, from: .now) }

    private struct Recap {
        var total = 0, bestDay = 0, goalDays = 0, activeDays = 0
        var bestDate: Date?
        var meters: Double { Double(total) * 0.72 }
    }

    private var recap: Recap {
        var r = Recap()
        let todayStart = cal.startOfDay(for: .now)
        for (day, steps) in state.steps.daily where cal.component(.year, from: day) == year && day <= todayStart {
            r.total += steps
            if steps > r.bestDay { r.bestDay = steps; r.bestDate = day }
            if steps >= state.goal { r.goalDays += 1 }
            if steps > 0 { r.activeDays += 1 }
        }
        return r
    }

    var body: some View {
        let r = recap
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    card(r)
                    if let shareImage {
                        ShareLink(item: shareImage,
                                  preview: SharePreview("My \(String(year)) with \(state.petName)", image: shareImage)) {
                            Label("Share my year", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.chunky(.grass, text: .white, radius: 16, padV: 13))
                    }
                }
                .padding(16)
            }
            .foregroundStyle(Color.ink)
            .paperBackground()
            .navigationTitle(loc("Year in review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(loc("Close")) { dismiss() } } }
            .task { renderShare(r) }
        }
    }

    /// The recap card — also what we render to an image for sharing.
    private func card(_ r: Recap) -> some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                CatView(outfit: state.outfit, size: 86, mood: .happy, animated: false).frame(width: 86, height: 100)
                Text("Our \(String(year))").font(.story(26, .bold))
                Text("\(state.petName) & you").font(.game(13, .semibold)).foregroundStyle(Color.inkSoft)
            }
            VStack(spacing: 0) {
                Text(r.total.formatted()).font(.story(44, .heavy)).contentTransition(.numericText())
                Text("steps this year").font(.game(13, .semibold)).foregroundStyle(Color.inkSoft)
            }
            let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            LazyVGrid(columns: cols, spacing: 10) {
                tile("figure.walk", .grassDark, state.distanceText(r.meters), loc("walked"))
                tile("star.fill", .sunDark, r.bestDay.formatted(), loc("biggest day"))
                tile("flag.checkered", .skyDark, "\(r.goalDays)", loc("goal days"))
                tile("calendar", .grape, "\(r.activeDays)", loc("active days"))
                tile("flame.fill", .pumpkin, "\(state.longestStreak)", loc("longest streak"))
                tile("tshirt.fill", .bubble, "\(state.owned.count)", loc("items collected"))
            }
            Text("\(state.daysTogether) days on the trail together 🐾")
                .font(.game(12, .bold)).foregroundStyle(Color.inkSoft)
                .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(PaperShape(radius: 24, wobble: 1.4, seed: 23).fill(Color.paper))
        .overlay(PaperShape(radius: 24, wobble: 1.4, seed: 23).stroke(Color.choco.opacity(0.14), lineWidth: 1.2))
    }

    private func tile(_ symbol: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            GameIcon(symbol: symbol, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.story(17, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
            }
            Spacer(minLength: 2)
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cream))
    }

    @MainActor private func renderShare(_ r: Recap) {
        let renderer = ImageRenderer(content:
            card(r).padding(18).background(Color.cream).frame(width: 360)
                .environment(state)
        )
        renderer.scale = 3
        if let ui = renderer.uiImage { shareImage = Image(uiImage: ui) }
    }
}
