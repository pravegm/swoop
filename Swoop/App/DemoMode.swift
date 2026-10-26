#if DEBUG
import SwiftUI
import UIKit

// MARK: - Demo mode (CI screenshots, design review). DEBUG builds only: Release ships none of this.
//
// Launch argument: `-swoopDemo "key=value;key;key=value"` (ci/scenarios.txt, ci/duo-scenarios.txt, ci/duo.sh).
// Values can't contain `;`. Unknown keys are ignored. Every line CI greps starts with `SWOOP-` (never rename them).
//
// Keys (design/ROUND-1.md)
// - `screen=home|play|results|goals|birds|settings|pose|icon|badges`
//     home      Home over the attract loop (mode .attract, perfect autopilot).
//     play      play `mode` (implied when `mode=` is given without `screen`).
//     results   the results card for `mode`: a REAL run of it played headless at launch by the autopilot (`autopilot=`,
//               default casual) and recorded into the demo progress, so best, goals and rank-up are all true.
//     goals     the Flocks screen.  birds  the Birds screen.  settings  the Settings screen.
//     pose      force the "Turn your Duo sideways" card (over the attract loop, or over `mode` if given).
//     icon      render AppIconArt to Documents/AppIcon-1024.png (`SWOOP-T icon ok|failed`) and show it on black.
//     badges    render every achievement badge to Documents/badges/<id>.png (`SWOOP-T badges done <n>`); Home shows.
// - `mode=flight|daily|attract`   start that run at once (`daily` = today's scored Daily; `attract` never finishes).
// - `seed=<n>`                    the sea seed (default 7, so frames are stable).
// - `autopilot=novice|casual|expert|perfect`   FlightPilot drives the tuck.
// - `touch`                       touch input even on a Duo.
// - `duo`                         treat the canvas as having a fold (crease + Duo layout on a regular simulator).
// - `mirror`                      Bird on the other side.
// - `skipCountdown`               start flying at once.
// - `freezeOn=launch|perfect|splash|tailwind|lighthouse|stormclose|caught|finished|flying` (`splash` is extra)
//     stop stepping the session 0.25 s (session time) after the first such event once `freezeAfter` s of flight have
//     passed (default 4); print `SWOOP-T freeze <x> t=… m=…`. `stormclose` also takes a lead already under 15 %
//     (a `lead=` seed fires the event headless). `flying` = soaring high (altitude ≥ 120 pt) after `freezeAfter`, or
//     10 s later at the latest. `finished` freezes at once and shows the results card without its delay.
// - `freezeAfter=<s>`             see freezeOn.
// - `freezeAt=<s>`                freeze at that flight time, printing `SWOOP-T freeze time`.
// - `progress=fresh|mid|late`     seeded in-memory progress (demo runs never write UserDefaults).
// - `bird=<BirdID>`, `sky=<SkyID>`   the cosmetics for this run (and the Home loop).
// - `best=<m>`                    the personal best marker for the session.
// - `chain=<n>`                   the run is really PLAYED headless (perfect pilot) up to an n-Perfect chain.
//                                 Logs `SWOOP-T chain seeded <got> (asked <n>)`.
// - `hints=fresh`                 first-run hints on (default in demo: off).
// - `lead=<0…1>`                  after any chain seed, glide headless (wings spread) until the storm gap is at most
//                                 that fraction of a full lead. Logs `SWOOP-T lead seeded <lead>`.
// - `skipTo=<m>` (extra)          play headless (perfect pilot) to that distance first, e.g. just short of the first
//                                 lighthouse (4 km) for `freezeOn=lighthouse`. Logs `SWOOP-T skipped to <m>`.
//
// Log lines: `SWOOP-T demo '<args>' starts`, `SWOOP-T frame 120`, `SWOOP-T canvas <W>x<H> fold=<0|1> mirrored=<0|1>`,
// `SWOOP-T input hinge|touch|autopilot`, `SWOOP-T event <name> …`, `SWOOP-T tuck <u> angle <θ>`, `SWOOP-T paused closing`,
// `SWOOP-T resumed`, `SWOOP-T freeze <x>`, `SWOOP-T run meters=<m> perfects=<n> seconds=<s>`, `SWOOP-T screen <route>`,
// `SWOOP-T icon ok|failed`, `SWOOP-T badges done <n>`. (`SWOOP-H` hinge samples come from Input's HingeReader.)

struct DemoConfig: Equatable {
    enum Screen: String, Equatable { case home, play, results, goals, birds, settings, pose, icon, badges }
    enum ModeKey: String, Equatable { case flight, daily, attract }
    enum Freeze: String, Equatable { case launch, perfect, splash, tailwind, lighthouse, stormclose, caught, finished, flying }
    enum ProgressPreset: String, Equatable { case fresh, mid, late }

    static let defaultFreezeAfter: Double = 4
    static let defaultSeed: UInt64 = 7

    var raw: String
    var screen: Screen?
    var mode: ModeKey?
    var seed: UInt64?
    var autopilot: PilotSkill?
    var touch = false
    var duo = false
    var mirror = false
    var skipCountdown = false
    var freezeOn: Freeze?
    var freezeAfter: Double = DemoConfig.defaultFreezeAfter
    var freezeAt: Double?
    var progress: ProgressPreset?
    var bird: BirdID?
    var sky: SkyID?
    var best: Double?
    var chain: Int?
    var hintsFresh = false
    var lead: Double?
    var skipTo: Double?

    init(raw: String) { self.raw = raw }

    var badges: Bool { screen == .badges }

    /// The screen the app opens on.
    var effectiveScreen: Screen {
        if let screen { return screen }
        return mode == nil ? .home : .play
    }

    /// The run `mode=` asks for (`daily` = today's scored try). Nil without `mode=`.
    func runMode(today: Int) -> RunMode? {
        guard let mode else { return nil }
        switch mode {
        case .flight: return .flight
        case .daily: return .daily(day: today, scored: true)
        case .attract: return .attract
        }
    }

    private static func flag(_ value: String) -> Bool {
        value.isEmpty || value == "on" || value == "1" || value == "true"
    }

    private static func number(_ value: String) -> Double? {
        guard let d = Double(value), d.isFinite else { return nil }
        return d
    }

    /// Parses `key=value;key` (pure; tested).
    static func parse(_ raw: String) -> DemoConfig {
        var config = DemoConfig(raw: raw)
        for part in raw.split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let key = pieces.first, !key.isEmpty else { continue }
            let value = pieces.count > 1 ? pieces[1] : ""
            switch key {
            case "screen": config.screen = Screen(rawValue: value)
            case "mode": config.mode = ModeKey(rawValue: value)
            case "seed": config.seed = UInt64(value)
            case "autopilot": config.autopilot = PilotSkill(rawValue: value)
            case "touch": config.touch = flag(value)
            case "duo": config.duo = flag(value)
            case "mirror": config.mirror = flag(value)
            case "skipCountdown": config.skipCountdown = flag(value)
            case "freezeOn": config.freezeOn = Freeze(rawValue: value.lowercased())
            case "freezeAfter":
                if let s = number(value) { config.freezeAfter = max(s, 0) }
            case "freezeAt":
                if let s = number(value) { config.freezeAt = max(s, 0) }
            case "progress": config.progress = ProgressPreset(rawValue: value)
            case "bird": config.bird = BirdID(rawValue: value)
            case "sky": config.sky = SkyID(rawValue: value)
            case "best":
                if let m = number(value) { config.best = max(m, 0) }
            case "chain": config.chain = Int(value).map { max($0, 0) }
            case "hints": config.hintsFresh = value == "fresh"
            case "lead":
                if let x = number(value) { config.lead = min(max(x, 0), 1) }
            case "skipTo":
                if let m = number(value) { config.skipTo = max(m, 0) }
            default: break
            }
        }
        return config
    }

    /// The scenario for this launch: DEBUG builds with `-swoopDemo` only; nil otherwise.
    static let current: DemoConfig? = {
        guard let raw = UserDefaults.standard.string(forKey: "swoopDemo") else { return nil }
        // CI redirects stdout to a file (fully buffered); line-buffer it so the scripts see SWOOP- lines on time.
        setvbuf(stdout, nil, _IOLBF, 0)
        return DemoConfig.parse(raw)
    }()
}

// MARK: - Seeded progress (`progress=`)

enum DemoPresets {
    static func progress(_ preset: DemoConfig.ProgressPreset?, today: Int) -> ProgressData {
        var data = ProgressData()
        switch preset ?? .fresh {
        case .fresh:
            return data
        case .mid:
            data.rank = min(5, GoalCatalog.maxRank)
            data.bestMeters = 6_420
            data.bestScore = 7_310
            data.bestChain = 9
            data.bestPerfectsInRun = 31
            data.bestLighthousesInRun = 1
            data.bestTailwindsInRun = 4
            data.bestLastLighthouse = Lighthouses.name(index: 0, seed: DemoConfig.defaultSeed)
            data.lifetimeMeters = 48_300
            data.runs = 37
            data.totalPerfects = 412
            data.totalTailwinds = 38
            data.totalLighthouses = 9
            data.totalCloudTouches = 3
            data.hintsLearned = true
            let goals = GoalCatalog.goals(forRank: data.rank)
            let partial: [Double] = [1.0, 0.55, 0.2]
            for (i, goal) in goals.enumerated() where i < partial.count {
                data.goalProgress[goal.id] = partial[i]
            }
            addDailies(&data, today: today, days: [1, 2], meters: [5_200, 3_900])
        case .late:
            data.rank = min(12, GoalCatalog.maxRank)
            data.bestMeters = 18_240
            data.bestScore = 21_400
            data.bestChain = 23
            data.bestPerfectsInRun = 96
            data.bestLighthousesInRun = 3
            data.bestTailwindsInRun = 17
            data.bestLastLighthouse = Lighthouses.name(index: 2, seed: DemoConfig.defaultSeed)
            data.lifetimeMeters = 412_000
            data.runs = 161
            data.totalPerfects = 3_904
            data.totalTailwinds = 611
            data.totalLighthouses = 88
            data.totalCloudTouches = 54
            data.hintsLearned = true
            let goals = GoalCatalog.goals(forRank: data.rank)
            let partial: [Double] = [1.0, 1.0, 0.7]
            for (i, goal) in goals.enumerated() where i < partial.count {
                data.goalProgress[goal.id] = partial[i]
            }
            addDailies(&data, today: today, days: [1, 2, 3, 4, 5], meters: [12_100, 9_800, 14_300, 8_700, 11_200])
            if let bird = BirdCatalog.all.filter({ $0.unlockRank <= data.rank }).last { data.bird = bird.id }
            if let sky = SkyCatalog.all.filter({ $0.unlockRank <= data.rank }).last { data.sky = sky.id }
        }
        data.bestDailyStreak = max(data.bestDailyStreak, data.dailyStreak(today: today))
        return data
    }

    private static func addDailies(_ data: inout ProgressData, today: Int, days: [Int], meters: [Double]) {
        for (i, back) in days.enumerated() {
            let day = today - back
            let m = i < meters.count ? meters[i] : 4_000
            data.daily[day] = DailyRecord(meters: m, perfects: Int(m / 180), lighthouses: m >= 4_000 ? 1 : 0,
                                          lastLighthouseName: m >= 4_000 ? Lighthouses.name(index: 0, seed: 1) : "",
                                          finished: true)
            data.dailyAttempted.insert(day)
        }
    }
}

// MARK: - App icon render (`screen=icon`)

@MainActor
enum IconExport {
    static let side: CGFloat = 1024

    /// Renders AppIconArt at 1024 × 1024 px, opaque, to Documents/AppIcon-1024.png.
    static func render() {
        let renderer = ImageRenderer(content: AppIconArt().frame(width: side, height: side))
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        renderer.scale = 1
        renderer.isOpaque = true
        guard let cgImage = renderer.cgImage else {
            AppTrace.t("SWOOP-T icon failed: renderer returned no image")
            return
        }
        guard let data = opaquePNG(cgImage, side: side),
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppTrace.t("SWOOP-T icon failed: no PNG data")
            return
        }
        do {
            try data.write(to: directory.appendingPathComponent("AppIcon-1024.png"))
            AppTrace.t("SWOOP-T icon ok \(cgImage.width)x\(cgImage.height)")
        } catch {
            AppTrace.t("SWOOP-T icon failed: \(error.localizedDescription)")
        }
    }

    /// Redraws into an opaque 1× context so the PNG carries no alpha channel (App Store requirement).
    static func opaquePNG(_ cgImage: CGImage, side: CGFloat) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return image.pngData()
    }
}

// MARK: - Achievement badges render (`screen=badges`)

@MainActor
enum BadgeExport {
    static let side: CGFloat = 1024

    /// Renders every AchievementBadge at 1024 × 1024 px, opaque, to Documents/badges/<id>.png.
    static func renderAll() {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            AppTrace.t("SWOOP-T badges done 0 (no Documents directory)")
            return
        }
        let directory = documents.appendingPathComponent("badges", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var written = 0
        for id in GameCenterManager.achievementIDs {
            let renderer = ImageRenderer(content: AchievementBadge(id: id).frame(width: side, height: side))
            renderer.proposedSize = ProposedViewSize(width: side, height: side)
            renderer.scale = 1
            renderer.isOpaque = true
            guard let cgImage = renderer.cgImage, let data = IconExport.opaquePNG(cgImage, side: side) else {
                AppTrace.t("SWOOP-T badges failed \(id): no image")
                continue
            }
            do {
                try data.write(to: directory.appendingPathComponent("\(id).png"))
                written += 1
            } catch {
                AppTrace.t("SWOOP-T badges failed \(id): \(error.localizedDescription)")
            }
        }
        AppTrace.t("SWOOP-T badges done \(written)")
    }
}
#endif
