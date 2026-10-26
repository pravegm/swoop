import QuartzCore
import SwiftUI

// R6 (ART-FLIGHT-SCHOOL §1 AP1, §3 AP4): the live phone diagram and the lighthouse icon.

/// The projection of one panel of the diagram (ART §1): a panel rotated about the spine by φ = (180° − θ) / 2 draws at a
/// horizontal scale of cos φ, its outer edge taller by 0.18 sin φ. Pure; tested.
enum DuoDiagramGeometry {
    static func clampAngle(_ angle: Double) -> Double { min(max(angle.isFinite ? angle : 180, 100), 180) }

    static func phi(angle: Double) -> Double { (180 - clampAngle(angle)) / 2 * .pi / 180 }

    static func horizontalScale(angle: Double) -> CGFloat { CGFloat(cos(phi(angle: angle))) }

    static func outerSkew(angle: Double) -> CGFloat { CGFloat(0.18 * sin(phi(angle: angle))) }

    /// The panel's four corners in a box `size`: the spine at the centre, the outer edge at `side` (−1 left, +1 right).
    static func panel(side: CGFloat, angle: Double, in size: CGSize) -> [CGPoint] {
        let spineX = size.width / 2
        let w = size.width / 2 * 0.92 * horizontalScale(angle: angle)
        let h = size.height * 0.80
        let top = (size.height - h) / 2
        let grow = h * outerSkew(angle: angle) / 2
        let outerX = spineX + side * w
        return [CGPoint(x: spineX, y: top), CGPoint(x: outerX, y: top - grow),
                CGPoint(x: outerX, y: top + h + grow), CGPoint(x: spineX, y: top + h)]
    }

    /// The gauge needle's position along the 140° arc for an angle 100…180°, 0…1. Pure; tested.
    static func gaugeFraction(angle: Double) -> Double { (clampAngle(angle) - 100) / 80 }
}

/// A Duo held like a book, folding as the player folds (ART §1): two panels on a spine, a target ghost, mitten hands
/// and an angle gauge. `angle` is the live filtered hinge angle; `target` the pose the step waits for.
struct DuoDiagram: View {
    let angle: Double
    var target: Double?
    /// The half that may soften (drawn soft on the Wing check's mini diagram), or nil.
    var softSide: ScreenSide?
    var showsGauge = true
    var mirrored = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let bodyColor = Color(swoopHex: 0xDCE3EA)
    static let spine = Color(swoopHex: 0x9AA5B1)
    static let rim = Color(swoopHex: 0x0E2438)

    private var matched: Bool {
        guard let target else { return false }
        return abs(DuoDiagramGeometry.clampAngle(angle) - target) <= 6
    }

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || target == nil || matched)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    // Scene's AP1 geometry (`DuoDiagramArt`): both panels and screens as quads, the spine, the mittens.
                    if let target, !matched {
                        // The ghost eases from the live angle to the target and back (1.4 s, 0.3 s hold).
                        let cycle = reduceMotion ? 1.0 : ghostPhase(t)
                        let ghost = angle + (target - angle) * cycle
                        let g = DuoDiagramArt.geometry(angle: ghost, box: size)
                        for quad in [g.leftPanel, g.rightPanel] {
                            context.stroke(Path(DuoDiagramArt.quadPath(quad)), with: .color(SwoopTheme.foam.opacity(0.45)),
                                           style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        }
                    }
                    let flat = angle >= DuoDiagramArt.flatWarning
                    let g = DuoDiagramArt.geometry(angle: angle, box: size)
                    for (side, quad, screenQuad) in [(CGFloat(-1), g.leftPanel, g.leftScreen),
                                                     (CGFloat(1), g.rightPanel, g.rightScreen)] {
                        let path = Path(DuoDiagramArt.quadPath(quad))
                        context.fill(path, with: .color(Self.bodyColor))
                        context.stroke(path, with: .color(Self.rim.opacity(0.4)), lineWidth: 3)
                        let screen = Path(DuoDiagramArt.quadPath(screenQuad))
                        let isSea = (side < 0) != mirrored
                        context.fill(screen, with: .linearGradient(
                            Gradient(colors: [Color(swoopHex: 0x3D6FB0), Color(swoopHex: 0xFFE7C2)]),
                            startPoint: CGPoint(x: size.width / 2, y: quad[0].y),
                            endPoint: CGPoint(x: size.width / 2, y: quad[3].y)))
                        if flat { context.fill(screen, with: .color(Color.white.opacity(0.10))) }
                        if let softSide, (softSide == .left) == (side < 0) {
                            context.fill(screen, with: .color(Color.white.opacity(0.35)))
                        }
                        if !isSea, quad.count == 4 {
                            // The bird's half carries the "you" glyph, facing the flight direction.
                            let c = CGPoint(x: (quad[0].x + quad[1].x) / 2, y: size.height / 2)
                            let box = CGRect(x: c.x - 12, y: c.y - 8, width: 24, height: 15)
                            context.fill(Path(BirdArt.youGlyph(facingLeft: mirrored, in: box)), with: .color(.white))
                        }
                    }
                    context.fill(Path(roundedRect: g.spine, cornerRadius: DuoDiagramArt.spineWidth / 2),
                                 with: .color(Self.spine))
                    // Mitten hands on the outer edges.
                    for (side, quad) in [(CGFloat(-1), g.leftPanel), (CGFloat(1), g.rightPanel)] where quad.count == 4 {
                        let mitten = Path(DuoDiagramArt.mittenPath(outerTop: quad[1], outerBottom: quad[2], outward: side))
                        context.fill(mitten, with: .color(SwoopTheme.mist))
                        context.stroke(mitten, with: .color(Self.rim.opacity(0.3)), lineWidth: 2)
                    }
                    if matched {
                        var tick = Path()
                        tick.move(to: CGPoint(x: size.width / 2 - 8, y: size.height * 0.18))
                        tick.addLine(to: CGPoint(x: size.width / 2 - 2, y: size.height * 0.18 + 6))
                        tick.addLine(to: CGPoint(x: size.width / 2 + 9, y: size.height * 0.18 - 7))
                        context.stroke(tick, with: .color(SwoopTheme.accentOn),
                                       style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .scaleEffect(matched && !reduceMotion ? 1.04 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: matched)
            if showsGauge { AngleGauge(angle: angle).frame(width: 160, height: 56) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your Duo, open about \(Int(DuoDiagramGeometry.clampAngle(angle).rounded())) degrees")
    }

    private func ghostPhase(_ t: Double) -> Double {
        let p = t.truncatingRemainder(dividingBy: 1.7)
        if p < 0.7 { return 0.5 - 0.5 * cos(p / 0.7 * .pi) }
        if p < 1.0 { return 1 }
        return 0.5 + 0.5 * cos((p - 1.0) / 0.7 * .pi)
    }

    private func polygon(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        for q in pts.dropFirst() { p.addLine(to: q) }
        p.closeSubpath()
        return p
    }

    private func inset(_ pts: [CGPoint], by d: CGFloat) -> [CGPoint] {
        guard pts.count == 4 else { return pts }
        let dir: CGFloat = pts[1].x < pts[0].x ? -1 : 1
        return [CGPoint(x: pts[0].x + dir * 3, y: pts[0].y + d), CGPoint(x: pts[1].x - dir * d, y: pts[1].y + d),
                CGPoint(x: pts[2].x - dir * d, y: pts[2].y - d), CGPoint(x: pts[3].x + dir * 3, y: pts[3].y - d)]
    }
}

/// The angle gauge under the diagram (ART §1): a 140° arc, "open" 150–180° in teal, "fold" 100–122° in gold, a foam
/// needle at the live angle, and a coral underline at the flat end at ≥ 174°.
struct AngleGauge: View {
    let angle: Double

    var body: some View {
        Canvas { context, size in
            let c = CGPoint(x: size.width / 2, y: size.height)
            let r = min(size.width / 2 - 6, size.height - 6)
            // Scene's AP1 gauge (`DuoDiagramArt`): 100° at the left end, 180° at the right.
            func arc(_ from: Double, _ to: Double, _ color: Color) {
                let p = Path(DuoDiagramArt.gaugeArc(center: c, radius: r, from: from, to: to))
                context.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
            arc(DuoDiagramArt.minAngle, DuoDiagramArt.maxAngle, Color.white.opacity(0.14))
            arc(DuoDiagramArt.tuckBand.lowerBound, DuoDiagramArt.tuckBand.upperBound, SwoopTheme.rewardGold)
            arc(DuoDiagramArt.openBand.lowerBound, DuoDiagramArt.openBand.upperBound, SwoopTheme.accentOn)
            var needle = Path()
            needle.move(to: c)
            needle.addLine(to: DuoDiagramArt.gaugePoint(center: c, radius: r + 4, hinge: angle))
            context.stroke(needle, with: .color(SwoopTheme.foam), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            if angle >= DuoDiagramArt.flatWarning {
                var line = Path()
                let end = DuoDiagramArt.gaugePoint(center: c, radius: r, hinge: DuoDiagramArt.maxAngle)
                let p = CGPoint(x: end.x, y: end.y + 8)
                line.move(to: CGPoint(x: p.x - 12, y: p.y))
                line.addLine(to: CGPoint(x: p.x + 4, y: p.y))
                context.stroke(line, with: .color(SwoopTheme.coral), lineWidth: 1.5)
            }
        }
        .overlay(alignment: .bottom) {
            HStack {
                Text("fold").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(SwoopTheme.mist)
                Spacer()
                Text("open").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(SwoopTheme.mist)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The touch variant of the diagram (ART §1): a flat iPhone and a finger that presses its lower outer corner.
struct PhoneTouchDiagram: View {
    let pressed: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DuoDiagram.bodyColor)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DuoDiagram.rim.opacity(0.4), lineWidth: 3))
                .frame(width: 180, height: 88)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [Color(swoopHex: 0x3D6FB0), Color(swoopHex: 0xFFE7C2)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 166, height: 74)
            Circle()
                .stroke(SwoopTheme.foam.opacity(0.6), lineWidth: 2)
                .frame(width: pressed ? 60 : 44, height: pressed ? 60 : 44)
                .offset(x: 52, y: 18)
                .opacity(pressed ? 1 : 0)
            Capsule()
                .fill(SwoopTheme.mist)
                .frame(width: 22, height: 36)
                .offset(x: 52, y: pressed ? 34 : 44)
        }
        .animation(.easeOut(duration: 0.2), value: pressed)
        .accessibilityHidden(true)
    }
}

// MARK: - The lighthouse icon (ART §3 AP4)

/// The lighthouse: a tapered tower with a lamp room, a roof cap and a gallery, in a 24 × 32 viewBox.
struct LighthouseShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24
        let sy = rect.height / 32
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var path = Path()
        // Tower.
        path.move(to: p(6, 31))
        path.addLine(to: p(8, 13))
        path.addLine(to: p(16, 13))
        path.addLine(to: p(18, 31))
        path.closeSubpath()
        // Gallery rail.
        path.addRect(CGRect(origin: p(6.5, 11), size: CGSize(width: 11 * sx, height: 2 * sy)))
        // Lamp room.
        path.addRect(CGRect(origin: p(7.5, 6), size: CGSize(width: 9 * sx, height: 5 * sy)))
        // Roof cap.
        path.move(to: p(7, 6))
        path.addLine(to: p(12, 1.5))
        path.addLine(to: p(17, 6))
        path.closeSubpath()
        return path
    }
}

/// The lamp room alone (for the lit / pulsing lamp).
struct LighthouseLampShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24
        let sy = rect.height / 32
        return Path(CGRect(x: rect.minX + 7.5 * sx, y: rect.minY + 6 * sy, width: 9 * sx, height: 5 * sy))
    }
}

/// The two warm bands on the tower (the in-world lighthouse wears the same).
struct LighthouseBandsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24
        let sy = rect.height / 32
        var p = Path()
        p.addRect(CGRect(x: rect.minX + 7.2 * sx, y: rect.minY + 18 * sy, width: 9.6 * sx, height: 3 * sy))
        p.addRect(CGRect(x: rect.minX + 6.6 * sx, y: rect.minY + 25 * sy, width: 10.8 * sx, height: 3 * sy))
        return p
    }
}

/// The lighthouse icon in its three states (ART §3): reached (lit), next (the goal: gold outline, pulsing lamp),
/// unreached (a mist outline).
struct LighthouseIcon: View {
    enum State: Equatable { case reached, next, unreached }

    let state: State
    var size: CGFloat = 22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            switch state {
            case .reached:
                LighthouseShape().fill(SwoopTheme.foam)
                LighthouseBandsShape().fill(Color(swoopHex: 0xD8574A))
                LighthouseLampShape().fill(SwoopTheme.rewardGold)
                    .shadow(color: SwoopTheme.rewardGold.opacity(0.5), radius: size * 0.2)
            case .next:
                LighthouseShape().stroke(SwoopTheme.rewardGold, lineWidth: max(1.5, size / 16))
                LighthouseLampShape().fill(SwoopTheme.rewardGold).opacity(pulse ? 1 : 0.6)
            case .unreached:
                LighthouseShape().stroke(SwoopTheme.mist.opacity(0.6), lineWidth: max(1, size / 21))
            }
        }
        .frame(width: size * 0.75, height: size)
        .onAppear {
            guard state == .next, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.625).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - "You" (Scene SC8)

/// Scene's "you" gull (`BirdArt.youGlyph`): the meter knob, the route pins, the diagram. Face it the flight direction
/// (`facingLeft = mirrored`).
struct YouGlyph: Shape {
    var facingLeft = false

    func path(in rect: CGRect) -> Path { Path(BirdArt.youGlyph(facingLeft: facingLeft, in: rect)) }
}