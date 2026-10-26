import SwiftUI

/// The look (design/ART-DIRECTION.md §6): the world owns saturation; the UI is navy, foam and one gold. SF Pro Rounded,
/// where weight means something (Black for the wordmark and "Perfect", Heavy for numbers and titles, Bold for buttons,
/// Semibold for body, Medium for captions). Every screen takes colour, type, shape and motion from here.
enum SwoopTheme {
    // Sea, darkest → lightest
    static let abyss = Color(swoopHex: 0x04121F)
    static let deep = Color(swoopHex: 0x0A2238)
    static let sea = Color(swoopHex: 0x10334F)
    static let tide = Color(swoopHex: 0x1B4B6E)
    static let swell = Color(swoopHex: 0x2C6A8F)
    // Text: primary / secondary / tertiary
    static let foam = Color(swoopHex: 0xF2F7FA)
    static let mist = Color(swoopHex: 0xB6CCDA)
    static let haze = Color(swoopHex: 0x7896AB)
    // The brand gold (the primary action) never changes
    static let gold = Color(swoopHex: 0xF7C75B)
    static let goldDeep = Color(swoopHex: 0xC98A2A)
    static let goldLight = Color(swoopHex: 0xFFE08A)
    // Reward gold (the same in every sky): earned states only
    static let rewardGold = Color(swoopHex: 0xFFD45E)
    static let rewardHighlight = Color(swoopHex: 0xFFF3C4)
    static let rewardDeep = Color(swoopHex: 0xE8A93A)
    static let ember = Color(swoopHex: 0xF39A4B)
    /// The streak flame (`flame.fill`, never 🔥 in chrome).
    static let flame = Color(swoopHex: 0xF39A4B)
    // UI surfaces (ART §6)
    static let surface = Color(swoopHex: 0x0B2236)
    static let surfaceRaised = Color(swoopHex: 0x143352)
    static let surfacePressed = Color(swoopHex: 0x0F2942)
    static let stroke = Color.white.opacity(0.09)
    /// Toggles and neutral "on" states (not gold: the gold budget).
    static let accentOn = Color(swoopHex: 0x5CC2D6)
    // The storm
    static let slate = Color(swoopHex: 0x5B6976)
    static let storm = Color(swoopHex: 0x2E3A45)
    static let coral = Color(swoopHex: 0xFF7B6E)
    static let perfect = Color(swoopHex: 0x9BE7FF)
    /// Text on gold, and the legibility shadow's base.
    static let ink = Color(swoopHex: 0x0E2438)
    static let shadowBase = Color(swoopHex: 0x04121F)
    /// The pose card's circle (ART A9: never olive).
    static let poseCircle = Color(swoopHex: 0x13304A)

    // MARK: Legacy font helpers (kept for the few raw sizes that are art, e.g. badges)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }

    // MARK: Shapes (concentric: card radius − padding = button radius)

    static func cardRadius(_ compact: Bool) -> CGFloat { compact ? 28 : 32 }
    static let cardPadding: CGFloat = 16
    static func buttonRadius(_ compact: Bool) -> CGFloat { compact ? 12 : 16 }
    static func tileRadius(_ compact: Bool) -> CGFloat { compact ? 16 : 18 }
    static func primaryHeight(_ compact: Bool) -> CGFloat { compact ? 56 : 64 }
    static func secondaryHeight(_ compact: Bool) -> CGFloat { compact ? 48 : 56 }

    // MARK: Motion (ART §5)

    /// UI settle: spring 0.45 / 0.86 (≤ 2 % overshoot). Reduce Motion: a 0.2 s crossfade.
    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.86)
    }

    /// UI pop (chips, ×N, badges): spring 0.28 / 0.62 (8–12 % overshoot).
    static func pop(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.28, dampingFraction: 0.62)
    }

    /// Page change: crossfade + a 24 pt slide toward the new page, 0.32 s ease-out (no 3D rotation).
    static func pageAnimation(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .easeOut(duration: 0.32)
    }

    static func pageTransition(_ reduceMotion: Bool, fromTrailing: Bool = true) -> AnyTransition {
        if reduceMotion { return .opacity }
        let slide = AnyTransition.offset(x: fromTrailing ? 24 : -24, y: 0)
        return slide.combined(with: .opacity)
    }

    /// The night-sea backdrop for full screens (over the attract loop, which stays faintly visible).
    static var backdrop: LinearGradient {
        LinearGradient(colors: [abyss.opacity(0.94), deep.opacity(0.92), sea.opacity(0.88)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The type scale (ART §6). Duo sizes run ~10 % larger: the halves are held at arm's length and seen at an angle.
/// `compact` = an iPhone-sized canvas (`AppCanvas.isCompact`).
enum SwoopType {
    static func wordmark(_ c: Bool) -> Font { .system(size: c ? 52 : 72, weight: .black, design: .rounded) }
    static func hero(_ c: Bool) -> Font { .system(size: c ? 52 : 76, weight: .heavy, design: .rounded).monospacedDigit() }
    static func heroSize(_ c: Bool) -> CGFloat { c ? 52 : 76 }
    static func hud(_ c: Bool) -> Font { .system(size: c ? 36 : 46, weight: .heavy, design: .rounded).monospacedDigit() }
    static func hudUnit(_ c: Bool) -> Font { .system(size: c ? 15 : 18, weight: .bold, design: .rounded) }
    static func countdown(_ c: Bool) -> Font {
        .system(size: c ? 96 : 120, weight: .heavy, design: .rounded).monospacedDigit()
    }
    static func callout(_ c: Bool) -> Font { .system(size: c ? 28 : 32, weight: .black, design: .rounded) }
    static func title(_ c: Bool) -> Font { .system(size: c ? 28 : 34, weight: .heavy, design: .rounded) }
    static func headline(_ c: Bool) -> Font { .system(size: c ? 19 : 22, weight: .bold, design: .rounded) }
    static func button(_ c: Bool) -> Font { .system(size: c ? 18 : 20, weight: .bold, design: .rounded) }
    static func body(_ c: Bool) -> Font { .system(size: c ? 15 : 17, weight: .semibold, design: .rounded) }
    static func caption(_ c: Bool) -> Font { .system(size: c ? 13 : 14, weight: .medium, design: .rounded) }
    static func overline(_ c: Bool) -> Font { .system(size: c ? 11 : 12, weight: .bold, design: .rounded) }
    static func chip(_ c: Bool) -> Font { .system(size: c ? 12 : 13, weight: .heavy, design: .rounded) }
    /// Tracking for overlines (+12 %) and chips (+6 %), in points for the size.
    static func overlineKerning(_ c: Bool) -> CGFloat { (c ? 11 : 12) * 0.12 }
    static func chipKerning(_ c: Bool) -> CGFloat { (c ? 12 : 13) * 0.06 }
    /// The SF Symbol size beside a button label.
    static func iconSize(_ c: Bool) -> CGFloat { c ? 18 : 20 }
}

extension Color {
    /// 0xRRGGBB.
    init(swoopHex hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    /// A catalogue colour (Contracts' platform-neutral RGBA).
    init(swoopRGBA c: RGBA) {
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}

// MARK: - Buttons (ART §6 "Buttons")

struct SwoopButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, danger }
    var kind: Kind = .primary
    /// The visual height (the tap area is never under `AppCanvas.minTap`).
    var height: CGFloat = 64
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let tapHeight = max(height, AppCanvas.minTap)
        return configuration.label
            .font(kind == .primary ? SwoopType.button(compact) : SwoopType.body(compact))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.horizontal, 12)
            .background(SwoopButtonBackground(kind: kind, pressed: pressed, compact: compact)
                            .frame(height: height))
            .frame(minHeight: tapHeight)
            .contentShape(Rectangle())
            .scaleEffect(pressed ? (kind == .primary ? 0.97 : 0.98) : 1)
            .opacity(kind == .quiet && pressed ? 0.6 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: pressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary: return SwoopTheme.ink
        case .secondary: return SwoopTheme.foam
        case .quiet: return SwoopTheme.mist
        case .danger: return SwoopTheme.coral
        }
    }
}

struct SwoopButtonBackground: View {
    let kind: SwoopButtonStyle.Kind
    let pressed: Bool
    var compact: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius(compact), style: .continuous)
        ZStack {
            switch kind {
            case .primary:
                // A 4 pt lip that presses to 1 pt.
                shape.fill(SwoopTheme.goldDeep).offset(y: pressed ? 1 : 4)
                shape.fill(LinearGradient(colors: [SwoopTheme.goldLight, SwoopTheme.gold],
                                          startPoint: .top, endPoint: .bottom))
                    .offset(y: pressed ? 3 : 0)
                    .shadow(color: Color.black.opacity(0.25), radius: 12, y: 6)
            case .secondary:
                shape.fill(pressed ? SwoopTheme.surfacePressed : SwoopTheme.surfaceRaised)
                    .overlay(shape.stroke(SwoopTheme.stroke, lineWidth: 1))
            case .quiet, .danger:
                Color.clear
            }
        }
    }
}

/// A button that ticks the UI sound/haptic (FeedbackDirector.uiTap) before acting.
struct SwoopButton<Content: View>: View {
    var kind: SwoopButtonStyle.Kind = .primary
    var height: CGFloat = 64
    var compact: Bool = false
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            label()
        }
        .buttonStyle(SwoopButtonStyle(kind: kind, height: height, compact: compact))
    }
}

/// A round icon button (pause, settings, back): 48 / 44 pt visual, 56 pt tap. Liquid Glass on iOS 26+.
struct SwoopIconButton: View {
    let systemName: String
    var size: CGFloat = AppCanvas.minTap
    var compact: Bool = false
    let label: String
    let action: () -> Void

    var body: some View {
        let visual: CGFloat = compact ? 44 : 48
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: visual * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(SwoopTheme.foam)
                .frame(width: visual, height: visual)
                .modifier(SwoopGlassCircle())
                .frame(width: max(size, visual), height: max(size, visual))
                .contentShape(Circle())
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel(label)
    }
}

/// ART A11: Liquid Glass for small floating controls on iOS 26+, the deep circle before.
struct SwoopGlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(SwoopTheme.surface.opacity(0.5)), in: Circle())
        } else {
            content
                .background(
                    Circle()
                        .fill(SwoopTheme.surface.opacity(0.82))
                        .overlay(Circle().stroke(SwoopTheme.stroke, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.3), radius: 6, y: 3)
                )
        }
    }
}

struct SwoopPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Cards and small pieces

extension View {
    /// A card (ART §6 "Materials"): solid `surface`, a top-lit hairline, a soft shadow. Gold strokes only for the
    /// selected state, so none here.
    func swoopCard(padding: CGFloat = SwoopTheme.cardPadding, radius: CGFloat = 32) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(SwoopTheme.surface.opacity(0.94))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.30), radius: 18, y: 8)
            )
    }

    /// Text over the live world: no panel, a legibility shadow (`#04121F` at 45 %, r 6).
    func swoopLegible() -> some View {
        self.shadow(color: SwoopTheme.shadowBase.opacity(0.45), radius: 6, y: 1)
    }

    /// A chip over the live world: `surface` at 62 %, capsule.
    func swoopChip(_ compact: Bool, opacity: Double = 0.62) -> some View {
        self.padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(SwoopTheme.surface.opacity(opacity)))
    }
}

/// A section label (caps, tracked, `mist`, never gold).
struct SwoopOverline: View {
    let text: String
    var compact: Bool = false
    var color: Color = SwoopTheme.mist

    var body: some View {
        Text(text.uppercased())
            .font(SwoopType.overline(compact))
            .kerning(SwoopType.overlineKerning(compact))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// "Swoop" in Black rounded type with a gold swash under it.
struct SwoopWordmark: View {
    var size: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.02) {
            Text("Swoop")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(SwoopTheme.foam)
                .kerning(-size * 0.015)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: size * 0.12) {
                Capsule()
                    .fill(LinearGradient(colors: [SwoopTheme.gold, SwoopTheme.ember], startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(width: size * 1.1, height: max(3, size * 0.06))
                Text("TUCK & SOAR")
                    .font(.system(size: max(size * 0.2, 11), weight: .bold, design: .rounded))
                    .kerning(size * 0.03)
                    .foregroundStyle(SwoopTheme.mist)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swoop: Tuck and Soar")
    }
}

/// A capsule chip label (TAILWIND, DAILY #298, "New best!").
struct SwoopPill: View {
    let text: String
    var fill: Color = SwoopTheme.gold
    var foreground: Color = SwoopTheme.ink
    var fontSize: CGFloat = 13

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .kerning(fontSize * 0.06)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
    }
}

/// A thin progress bar, slate → gold (gold only once done: the gold budget).
struct SwoopProgressBar: View {
    let value: Double
    var height: CGFloat = 10
    var done: Bool = false

    var body: some View {
        GeometryReader { geo in
            let v = CGFloat(min(max(value, 0), 1))
            ZStack(alignment: .leading) {
                Capsule().fill(SwoopTheme.abyss.opacity(0.8))
                Capsule()
                    .fill(LinearGradient(colors: done ? [SwoopTheme.rewardDeep, SwoopTheme.rewardGold]
                                                      : [SwoopTheme.swell, SwoopTheme.mist],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * v, v > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}

/// The streak: `flame.fill` in ember with the number (no emoji in chrome).
struct StreakLabel: View {
    let days: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundStyle(SwoopTheme.flame)
            Text("\(days)")
                .font(SwoopType.caption(compact).monospacedDigit())
                .foregroundStyle(SwoopTheme.foam)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days)-day streak")
    }
}

/// A small lighthouse (HUD card, results hook, Flocks ladder).
struct LighthouseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        p.move(to: CGPoint(x: x + w * 0.34, y: y + h))
        p.addLine(to: CGPoint(x: x + w * 0.40, y: y + h * 0.34))
        p.addLine(to: CGPoint(x: x + w * 0.60, y: y + h * 0.34))
        p.addLine(to: CGPoint(x: x + w * 0.66, y: y + h))
        p.closeSubpath()
        p.addRect(CGRect(x: x + w * 0.38, y: y + h * 0.18, width: w * 0.24, height: h * 0.13))
        p.move(to: CGPoint(x: x + w * 0.35, y: y + h * 0.18))
        p.addLine(to: CGPoint(x: x + w * 0.50, y: y + h * 0.04))
        p.addLine(to: CGPoint(x: x + w * 0.65, y: y + h * 0.18))
        p.closeSubpath()
        return p
    }
}
