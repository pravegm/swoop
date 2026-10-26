import SwiftUI

/// The look: a dark sea-blue night with gold accents (the clear sky ahead of the storm). SF Pro Rounded everywhere,
/// heavy for numbers, sized to read at arm's length on a Duo held in two hands. Every screen takes colour, type and
/// motion from here.
enum SwoopTheme {
    // Sea, darkest → lightest
    static let abyss = Color(swoopHex: 0x04121F)
    static let deep = Color(swoopHex: 0x0A2238)
    static let sea = Color(swoopHex: 0x10334F)
    static let tide = Color(swoopHex: 0x1B4B6E)
    static let swell = Color(swoopHex: 0x2C6A8F)
    // Text on the sea
    static let foam = Color(swoopHex: 0xF2F7FA)
    static let mist = Color(swoopHex: 0xB6CCDA)
    static let haze = Color(swoopHex: 0x7896AB)
    // Gold: the clear sky, Perfects, the primary action
    static let gold = Color(swoopHex: 0xF7C75B)
    static let goldDeep = Color(swoopHex: 0xD89A2E)
    static let goldLight = Color(swoopHex: 0xFFE6A8)
    static let ember = Color(swoopHex: 0xF39A4B)
    // The storm
    static let slate = Color(swoopHex: 0x5B6976)
    static let storm = Color(swoopHex: 0x2E3A45)
    static let coral = Color(swoopHex: 0xFF7B6E)
    // A Perfect skim
    static let perfect = Color(swoopHex: 0x9BE7FF)
    /// Text on gold.
    static let ink = Color(swoopHex: 0x0E2438)

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    /// Heavy rounded with monospaced digits (the distance never jitters as it counts).
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded).monospacedDigit()
    }

    static let cardRadius: CGFloat = 26
    static let buttonRadius: CGFloat = 20

    /// Springy by default; Reduce Motion turns movement into a short crossfade.
    static func pop(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.68)
    }

    static func settle(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.86)
    }

    /// The night-sea backdrop for full screens (over the attract loop, which stays faintly visible).
    static var backdrop: LinearGradient {
        LinearGradient(colors: [abyss.opacity(0.94), deep.opacity(0.9), sea.opacity(0.86)],
                       startPoint: .top, endPoint: .bottom)
    }
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

// MARK: - Buttons

/// A big, warm slab: gold for the main action, sea glass for the rest. Presses down with a spring.
struct SwoopButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, danger }
    var kind: Kind = .primary
    var height: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(SwoopTheme.text(19, .heavy))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: max(height, AppCanvas.minTap))
            .padding(.horizontal, 12)
            .background(SwoopButtonBackground(kind: kind, pressed: pressed))
            .contentShape(RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius, style: .continuous))
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: pressed)
    }

    private var textColor: Color {
        switch kind {
        case .primary: return SwoopTheme.ink
        case .secondary, .quiet: return SwoopTheme.foam
        case .danger: return Color.white
        }
    }
}

struct SwoopButtonBackground: View {
    let kind: SwoopButtonStyle.Kind
    let pressed: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: SwoopTheme.buttonRadius, style: .continuous)
        ZStack {
            switch kind {
            case .primary:
                shape.fill(SwoopTheme.goldDeep).offset(y: pressed ? 1 : 4)
                shape.fill(LinearGradient(colors: [SwoopTheme.goldLight, SwoopTheme.gold],
                                          startPoint: .top, endPoint: .bottom))
                    .offset(y: pressed ? 3 : 0)
            case .secondary:
                shape.fill(SwoopTheme.abyss.opacity(0.7)).offset(y: pressed ? 1 : 4)
                shape.fill(LinearGradient(colors: [SwoopTheme.tide, SwoopTheme.sea],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay(shape.stroke(SwoopTheme.gold.opacity(0.35), lineWidth: 1.5))
                    .offset(y: pressed ? 3 : 0)
            case .quiet:
                shape.fill(SwoopTheme.deep.opacity(0.85))
                    .overlay(shape.stroke(SwoopTheme.foam.opacity(0.16), lineWidth: 1.5))
                    .offset(y: pressed ? 2 : 0)
            case .danger:
                shape.fill(Color(swoopHex: 0xB8473D)).offset(y: pressed ? 1 : 4)
                shape.fill(SwoopTheme.coral).offset(y: pressed ? 3 : 0)
            }
        }
    }
}

/// A button that ticks the UI sound/haptic (FeedbackDirector.uiTap) before acting.
struct SwoopButton<Content: View>: View {
    var kind: SwoopButtonStyle.Kind = .primary
    var height: CGFloat = 60
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            label()
        }
        .buttonStyle(SwoopButtonStyle(kind: kind, height: height))
    }
}

/// A round icon button (pause, settings, back), 56 pt.
struct SwoopIconButton: View {
    let systemName: String
    var size: CGFloat = AppCanvas.minTap
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            FeedbackDirector.shared.uiTap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                .foregroundStyle(SwoopTheme.foam)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(SwoopTheme.deep.opacity(0.82))
                        .overlay(Circle().stroke(SwoopTheme.foam.opacity(0.18), lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(0.3), radius: 6, y: 3)
                )
                .contentShape(Circle())
        }
        .buttonStyle(SwoopPressStyle())
        .accessibilityLabel(label)
    }
}

struct SwoopPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Cards and small pieces

extension View {
    /// A deep-sea glass card with a faint gold rim.
    func swoopCard(padding: CGFloat = 20, radius: CGFloat = SwoopTheme.cardRadius) -> some View {
        self.padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [SwoopTheme.deep.opacity(0.94), SwoopTheme.abyss.opacity(0.94)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(SwoopTheme.gold.opacity(0.18), lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(0.35), radius: 18, y: 8)
            )
    }

    /// Text over the live scene: a soft dark halo keeps it readable on bright sky and dark storm alike.
    func swoopLegible() -> some View {
        self.shadow(color: Color.black.opacity(0.55), radius: 6, y: 2)
    }
}

/// "Swoop" in heavy rounded type with a gold swash under it.
struct SwoopWordmark: View {
    var size: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.02) {
            Text("Swoop")
                .font(SwoopTheme.display(size))
                .foregroundStyle(SwoopTheme.foam)
                .kerning(-size * 0.015)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            HStack(spacing: size * 0.12) {
                Capsule()
                    .fill(LinearGradient(colors: [SwoopTheme.gold, SwoopTheme.ember], startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(width: size * 1.1, height: max(3, size * 0.07))
                    .shadow(color: SwoopTheme.gold.opacity(0.7), radius: size * 0.1)
                Text("TUCK & SOAR")
                    .font(SwoopTheme.text(max(size * 0.22, 11), .heavy))
                    .kerning(size * 0.03)
                    .foregroundStyle(SwoopTheme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swoop: Tuck and Soar")
    }
}

/// A rounded pill label.
struct SwoopPill: View {
    let text: String
    var fill: Color = SwoopTheme.gold
    var foreground: Color = SwoopTheme.ink
    var fontSize: CGFloat = 15

    var body: some View {
        Text(text)
            .font(SwoopTheme.text(fontSize, .heavy))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
    }
}

/// A thin progress bar, slate → gold.
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
                    .fill(LinearGradient(colors: done ? [SwoopTheme.gold, SwoopTheme.goldLight]
                                                      : [SwoopTheme.swell, SwoopTheme.gold],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * v, v > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }
}

/// A small lighthouse (HUD card, Flocks ladder).
struct LighthouseGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        // Tower (tapered)
        p.move(to: CGPoint(x: x + w * 0.34, y: y + h))
        p.addLine(to: CGPoint(x: x + w * 0.40, y: y + h * 0.34))
        p.addLine(to: CGPoint(x: x + w * 0.60, y: y + h * 0.34))
        p.addLine(to: CGPoint(x: x + w * 0.66, y: y + h))
        p.closeSubpath()
        // Lamp room
        p.addRect(CGRect(x: x + w * 0.38, y: y + h * 0.18, width: w * 0.24, height: h * 0.13))
        // Roof
        p.move(to: CGPoint(x: x + w * 0.35, y: y + h * 0.18))
        p.addLine(to: CGPoint(x: x + w * 0.50, y: y + h * 0.04))
        p.addLine(to: CGPoint(x: x + w * 0.65, y: y + h * 0.18))
        p.closeSubpath()
        return p
    }
}
