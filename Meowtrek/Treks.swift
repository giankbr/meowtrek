import CoreLocation
import HealthKit
import MapKit
import Observation
import SwiftUI

enum TrekKind: String, Codable, CaseIterable, Identifiable {
    case walk, run, hike
    var id: String { rawValue }
    var title: String { self == .walk ? loc("Walk") : self == .run ? loc("Run") : loc("Hike") }
    var symbol: String {
        switch self {
        case .walk: "figure.walk"
        case .run: "figure.run"
        case .hike: "figure.hiking"
        }
    }
    var tint: Color {
        switch self {
        case .walk: .grass
        case .run: .tomato
        case .hike: .choco
        }
    }
    var coinsPerKm: Int {
        switch self {
        case .walk: 20
        case .run: 40
        case .hike: 30
        }
    }
    var activity: HKWorkoutActivityType {
        switch self {
        case .walk: .walking
        case .run: .running
        case .hike: .hiking
        }
    }
    /// Rough kcal per kg per km, used only when Health isn't available.
    var kcalPerKm: Double { self == .run ? 62 : self == .hike ? 70 : 50 }
}

struct Trek: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: TrekKind
    var start: Date
    var end: Date
    var meters: Double
    var moving: TimeInterval
    var climb: Double
    var splits: [TimeInterval]
    var route: [[Double]]

    var km: Double { meters / 1000 }
    var pace: TimeInterval { meters > 10 ? moving / km : 0 }
    var kcal: Int { Int(km * kind.kcalPerKm) }
    var coins: Int { Int(km * Double(kind.coinsPerKm)) }
    var coordinates: [CLLocationCoordinate2D] { route.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) } }
}

func paceText(_ secondsPerKm: TimeInterval) -> String {
    guard secondsPerKm.isFinite, secondsPerKm > 0, secondsPerKm < 3600 else { return "–" }
    let s = Int(secondsPerKm.rounded())
    return String(format: "%d'%02d\"", s / 60, s % 60)
}

func durationText(_ t: TimeInterval) -> String {
    let s = Int(t)
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - Storage

@Observable
final class TrekStore {
    var treks: [Trek] = []

    @ObservationIgnored private let url = URL.documentsDirectory.appending(path: "treks.json")

    init() {
        if let d = try? Data(contentsOf: url), let t = try? JSONDecoder().decode([Trek].self, from: d) { treks = t }
    }

    func add(_ t: Trek) {
        treks.insert(t, at: 0)
        save()
    }

    func delete(_ t: Trek) {
        treks.removeAll { $0.id == t.id }
        save()
    }

    private func save() {
        try? JSONEncoder().encode(treks).write(to: url, options: .atomic)
    }

    var totalKm: Double { treks.reduce(0) { $0 + $1.km } }
    func longest(_ kind: TrekKind) -> Double { treks.filter { $0.kind == kind }.map(\.km).max() ?? 0 }
}

// MARK: - Recorder

@Observable
final class TrekRecorder: NSObject, CLLocationManagerDelegate {
    enum Phase { case idle, running, paused }

    var phase: Phase = .idle
    var kind: TrekKind = .walk
    var meters = 0.0
    var moving: TimeInterval = 0
    var climb = 0.0
    var splits: [TimeInterval] = []
    var route: [CLLocationCoordinate2D] = []
    var currentPace: TimeInterval = 0
    var denied = false

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var last: CLLocation?
    @ObservationIgnored private var started = Date()
    @ObservationIgnored private var tickStart: Date?
    @ObservationIgnored private var splitStart: TimeInterval = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var recent: [(Date, Double)] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    var elapsed: TimeInterval { moving + (tickStart.map { Date().timeIntervalSince($0) } ?? 0) }
    var avgPace: TimeInterval { meters > 20 ? elapsed / (meters / 1000) : 0 }

    func start(_ kind: TrekKind) {
        self.kind = kind
        meters = 0; moving = 0; climb = 0; splits = []; route = []; last = nil; recent = []; splitStart = 0
        started = .now
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        denied = [.denied, .restricted].contains(manager.authorizationStatus)
        resume()
    }

    func resume() {
        phase = .running
        tickStart = .now
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        Task { @MainActor in TrekLive.update(self) }
    }

    func pause() {
        moving = elapsed
        tickStart = nil
        phase = .paused
        last = nil
        manager.stopUpdatingLocation()
        timer?.invalidate()
        Task { @MainActor in TrekLive.update(self) }
    }

    func finish() -> Trek? {
        if phase == .running { pause() }
        phase = .idle
        manager.allowsBackgroundLocationUpdates = false
        TrekLive.end()
        guard meters > 30 || moving > 60 else { return nil }
        return Trek(kind: kind, start: started, end: .now, meters: meters, moving: moving, climb: climb,
                    splits: splits, route: route.map { [$0.latitude, $0.longitude] })
    }

    func discard() {
        _ = finish()
    }

    private var lastLive = Date.distantPast

    private func tick() {
        if Date().timeIntervalSince(lastLive) > 10 {
            lastLive = .now
            Task { @MainActor in TrekLive.update(self) }
        }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        denied = [.denied, .restricted].contains(m.authorizationStatus)
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard phase == .running else { return }
        for loc in locations where loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy < 25 {
            if let prev = last {
                let d = loc.distance(from: prev)
                guard d < 200 else { last = loc; continue }
                meters += d
                let up = loc.altitude - prev.altitude
                if up > 0.5 && loc.verticalAccuracy >= 0 && loc.verticalAccuracy < 15 { climb += up }
                recent.append((loc.timestamp, d))
                recent.removeAll { loc.timestamp.timeIntervalSince($0.0) > 30 }
                let span = recent.reduce(0) { $0 + $1.1 }
                if span > 15, let first = recent.first { currentPace = loc.timestamp.timeIntervalSince(first.0) / (span / 1000) }
                if Int(meters / 1000) > splits.count {
                    let now = elapsed
                    splits.append(now - splitStart)
                    splitStart = now
                }
            }
            last = loc
            route.append(loc.coordinate)
        }
    }
}

// MARK: - Health

enum TrekHealth {
    static func save(_ t: Trek) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute(),
                                        HKQuantityType(.distanceWalkingRunning), HKQuantityType(.activeEnergyBurned)]
        guard (try? await store.requestAuthorization(toShare: share, read: [])) != nil else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = t.kind.activity
        config.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: t.start)
            let dist = HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                        quantity: HKQuantity(unit: .meter(), doubleValue: t.meters), start: t.start, end: t.end)
            let kcal = HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                        quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(t.kcal)), start: t.start, end: t.end)
            try await builder.addSamples([dist, kcal])
            try await builder.endCollection(at: t.end)
            guard let workout = try await builder.finishWorkout() else { return }
            let locations = t.coordinates.enumerated().map { i, c in
                CLLocation(coordinate: c, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: -1,
                           timestamp: t.start.addingTimeInterval(t.end.timeIntervalSince(t.start) * Double(i) / Double(max(1, t.route.count))))
            }
            guard !locations.isEmpty else { return }
            let route = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            try await route.insertRouteData(locations)
            _ = try await route.finishRoute(with: workout, metadata: nil)
        } catch {}
    }
}

// MARK: - Recording screen

struct TrekRecordView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var rec = TrekRecorder()
    @State private var kind: TrekKind = .walk
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var finished: Trek?
    @State private var confirmStop = false
    @State private var hop = 0

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Map(position: $camera) {
                    UserAnnotation()
                    if rec.route.count > 1 {
                        MapPolyline(coordinates: rec.route).stroke(kind.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                }
                .mapControls { MapUserLocationButton() }
                HStack {
                    Button { rec.phase == .idle ? dismiss() : (confirmStop = true) } label: {
                        Image(systemName: rec.phase == .idle ? "xmark" : "stop.fill").font(.system(size: 15, weight: .bold))
                    }
                    .buttonStyle(.chunky(.paper, radius: 20, padH: 12, padV: 10))
                    Spacer()
                    if rec.phase != .idle {
                        Label(kind.title, systemImage: kind.symbol).font(.game(14, .bold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(Color.paper))
                    }
                }
                .padding(16)
                if rec.denied {
                    Text("Allow location in Settings to draw your route.")
                        .font(.game(13, .semibold)).padding(10).background(Capsule().fill(Color.paper)).padding(.top, 70)
                }
            }

            VStack(spacing: 14) {
                if rec.phase == .idle {
                    HStack(spacing: 10) {
                        ForEach(TrekKind.allCases) { k in
                            Button { withAnimation(.snappy) { kind = k } } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: k.symbol).font(.system(size: 22, weight: .semibold))
                                    Text(k.title).font(.game(13, .bold))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.chunky(kind == k ? k.tint.opacity(0.2) : .paper, text: kind == k ? k.tint.darker(0.1) : .inkSoft, padV: 12))
                        }
                    }
                } else {
                    HStack(alignment: .bottom) {
                        CatView(outfit: state.outfit, size: 70, mood: .happy, hop: hop)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(state.distanceText(rec.meters)).font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                            Text(state.useMiles ? "distance" : "distance").font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
                        }
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        HStack {
                            stat(durationText(rec.elapsed), loc("time"))
                            stat(paceText(rec.currentPace > 0 ? rec.currentPace : rec.avgPace), loc("pace /km"))
                            stat("\(Int(rec.climb))m", loc("climb"))
                        }
                    }
                }

                HStack(spacing: 12) {
                    switch rec.phase {
                    case .idle:
                        Button { rec.start(kind) } label: {
                            Label("Start \(kind.title.lowercased())", systemImage: "play.fill").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.chunky(kind.tint, text: .white, radius: 22, padV: 16))
                    case .running:
                        Button { rec.pause() } label: { Label("Pause", systemImage: "pause.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.chunky(.sun, radius: 22, padV: 16))
                    case .paused:
                        Button { rec.resume() } label: { Label("Resume", systemImage: "play.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.chunky(.grass, text: .white, radius: 22, padV: 16))
                        Button { stop() } label: { Label("Finish", systemImage: "flag.checkered").frame(maxWidth: .infinity) }
                            .buttonStyle(.chunky(.tomato, text: .white, radius: 22, padV: 16))
                    }
                }
            }
            .padding(20)
            .background(Color.cream)
        }
        .foregroundStyle(Color.ink)
        .onChange(of: rec.splits.count) { _, n in
            guard n > 0 else { return }
            hop += 1
            state.show(loc("\(n) km! \(paceText(rec.splits.last ?? 0)) /km"), art: "coin")
        }
        .confirmationDialog("Finish this trek?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Finish and save") { stop() }
            Button("Discard", role: .destructive) { rec.discard(); dismiss() }
            Button("Keep going", role: .cancel) {}
        }
        .fullScreenCover(item: $finished, onDismiss: { dismiss() }) { TrekSummaryView(trek: $0, fresh: true) }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.game(22, .bold)).monospacedDigit()
            Text(l).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private func stop() {
        guard let t = rec.finish() else {
            state.show(loc("Too short to save"))
            dismiss()
            return
        }
        state.treks.add(t)
        state.rewardTrek(t)
        Task { await TrekHealth.save(t) }
        finished = t
    }
}

// MARK: - Summary

struct TrekSummaryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let trek: Trek
    var fresh = false
    @State private var share = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if trek.route.count > 1 {
                        Map(initialPosition: .automatic, interactionModes: []) {
                            MapPolyline(coordinates: trek.coordinates)
                                .stroke(trek.kind.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        }
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    HStack(spacing: 12) {
                        GameIcon(symbol: trek.kind.symbol, tint: trek.kind.tint, size: 48)
                        VStack(alignment: .leading) {
                            Text(fresh ? "Nice \(trek.kind.title.lowercased())!" : trek.kind.title).font(.game(24, .bold))
                            Text(trek.start.formatted(date: .abbreviated, time: .shortened)).font(.game(13, .medium)).foregroundStyle(Color.inkSoft)
                        }
                        Spacer()
                        if fresh {
                            HStack(spacing: 4) {
                                ArtView(id: "coin", size: 22)
                                Text("+\(trek.coins)").font(.game(17, .bold))
                            }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metric(state.distanceText(trek.meters), loc("distance"))
                        metric(durationText(trek.moving), loc("time"))
                        metric(paceText(trek.pace), loc("avg pace"))
                        metric("\(Int(trek.climb))m", loc("climb"))
                        metric("\(trek.kcal)", loc("kcal est."))
                        metric("\(trek.splits.count)", loc("full km"))
                    }
                    .card()
                    if !trek.splits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Splits").font(.game(17, .bold))
                            let best = trek.splits.min() ?? 0
                            ForEach(Array(trek.splits.enumerated()), id: \.offset) { i, s in
                                HStack {
                                    Text("km \(i + 1)").font(.game(14, .semibold)).frame(width: 52, alignment: .leading)
                                    GeometryReader { g in
                                        Capsule().fill(s == best ? trek.kind.tint : trek.kind.tint.opacity(0.35))
                                            .frame(width: g.size.width * min(1, best / max(1, s)))
                                    }
                                    .frame(height: 10)
                                    Text(paceText(s)).font(.game(14, .bold)).monospacedDigit().frame(width: 56, alignment: .trailing)
                                }
                            }
                        }
                        .card()
                    }
                    Button { share = true } label: { Label("Share route", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                        .buttonStyle(.chunky(trek.kind.tint, text: .white, radius: 20, padV: 14))
                }
                .padding(16)
            }
            .foregroundStyle(Color.ink)
            .background(Color.cream)
            .navigationTitle(trek.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .sheet(isPresented: $share) { ShareCardsView(kind: .trek, trek: trek) }
        }
    }

    private func metric(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.game(18, .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(l).font(.game(11, .medium)).foregroundStyle(Color.inkSoft)
        }
    }
}

/// Route drawn as a line normalised into its box — used on share cards and history rows.
struct RouteShape: Shape {
    let points: [[Double]]

    func path(in r: CGRect) -> Path {
        guard points.count > 1 else { return Path() }
        let lats = points.map { $0[0] }, lons = points.map { $0[1] }
        let minLat = lats.min()!, maxLat = lats.max()!, minLon = lons.min()!, maxLon = lons.max()!
        let k = cos(((minLat + maxLat) / 2) * .pi / 180)
        let w = max((maxLon - minLon) * k, 1e-6), h = max(maxLat - minLat, 1e-6)
        let scale = min(r.width / w, r.height / h)
        let ox = r.minX + (r.width - w * scale) / 2, oy = r.minY + (r.height - h * scale) / 2
        var p = Path()
        for (i, pt) in points.enumerated() {
            let c = CGPoint(x: ox + (pt[1] - minLon) * k * scale, y: oy + (maxLat - pt[0]) * scale)
            i == 0 ? p.move(to: c) : p.addLine(to: c)
        }
        return p
    }
}

struct TrekRow: View {
    @Environment(AppState.self) private var state
    let trek: Trek

    var body: some View {
        HStack(spacing: 12) {
            RouteShape(points: trek.route)
                .stroke(trek.kind.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .padding(8)
                .frame(width: 58, height: 58)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(trek.kind.tint.opacity(0.12)))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: trek.kind.symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(trek.kind.tint).padding(4)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.distanceText(trek.meters)) \(trek.kind.title.lowercased())").font(.game(16, .bold))
                Text("\(durationText(trek.moving)) · \(paceText(trek.pace)) /km · \(trek.start.formatted(.dateTime.day().month()))")
                    .font(.game(12, .medium)).foregroundStyle(Color.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.inkSoft.opacity(0.6))
        }
        .card(padding: 10)
    }
}
