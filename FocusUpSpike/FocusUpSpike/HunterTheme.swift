import SwiftUI

/// Shared "System" HUD / Fire Aura visual language, ported from the
/// FocusUp design canvas. One place for the palette + reusable pieces
/// (HUD panel, pixel-cut-corner frame, aura glow, segmented bar) so
/// every screen stays visually consistent. Colors mirror the design
/// mockups exactly, not eyeballed.
enum HunterTheme {
    // Cyan = everyday interactive "System" chrome.
    static let cyan = Color(red: 0x3E / 255, green: 0xE6 / 255, blue: 0xFF / 255)
    static let cyanDim = cyan.opacity(0.35)

    // Gold = reserved for the streak/level-up payoff only.
    static let gold = Color(red: 0xFF / 255, green: 0xC9 / 255, blue: 0x4D / 255)

    // Steel = a secondary cool accent (Discipline stat, the Storm cloak).
    static let steel = Color(red: 0x6E / 255, green: 0x8C / 255, blue: 0xA8 / 255)

    // Ember / fire aura.
    static let emberOrange = Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x3D / 255)
    static let emberRed = Color(red: 0xFF / 255, green: 0x6A / 255, blue: 0x2B / 255)

    // Ground.
    static let bg = Color(red: 0x05 / 255, green: 0x07 / 255, blue: 0x08 / 255)
    static let panelFill = Color(red: 0x06 / 255, green: 0x10 / 255, blue: 0x1C / 255).opacity(0.7)
    static let textPrimary = Color(red: 0xE8 / 255, green: 0xF6 / 255, blue: 0xFB / 255)
    static let textMuted = Color(red: 0x5A / 255, green: 0x7A / 255, blue: 0x8C / 255)
    static let danger = Color(red: 0xFF / 255, green: 0x4D / 255, blue: 0x5E / 255)
}

/// The dark ground + a soft cyan ambient corner glow used on every
/// non-payoff screen (Sign In, Home, Tasks, Character). Kept subtle on
/// purpose so gold stays the one payoff on the Streak Celebration screen.
struct HunterBackground: View {
    var topRight = true
    var body: some View {
        ZStack {
            HunterTheme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [HunterTheme.cyan.opacity(0.08), .clear],
                center: topRight ? .topTrailing : .topLeading,
                startRadius: 4, endRadius: 340
            )
            .ignoresSafeArea()
        }
    }
}

/// Tracked, uppercase, cyan label -- the "hud-label" from the mockups.
struct HUDLabel: View {
    let text: String
    var size: CGFloat = 10
    var color: Color = HunterTheme.cyan
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// The bracket-cornered HUD panel background, applied via the
/// `.hudPanel()` modifier so any content can sit inside one.
struct HUDPanelBackground: View {
    var borderColor: Color = HunterTheme.cyanDim
    var cornerAccent: Color = HunterTheme.cyan
    var body: some View {
        ZStack {
            HunterTheme.panelFill
            Rectangle().strokeBorder(borderColor, lineWidth: 1)
            HUDCorners(color: cornerAccent)
        }
    }
}

/// Two small L-shaped brackets at opposing corners -- SwiftUI's answer
/// to the CSS ::before/::after corner accents in the mockups.
private struct HUDCorners: View {
    let color: Color
    var length: CGFloat = 9
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: 0, y: length))
                p.addLine(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: length, y: 0))
            }
            .stroke(color, lineWidth: 2)
            Path { p in
                p.move(to: CGPoint(x: w - length, y: h))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: w, y: h - length))
            }
            .stroke(color, lineWidth: 2)
        }
    }
}

extension View {
    /// Applies the bracket-corner HUD panel look as a background.
    func hudPanel(borderColor: Color = HunterTheme.cyanDim, cornerAccent: Color = HunterTheme.cyan) -> some View {
        background(HUDPanelBackground(borderColor: borderColor, cornerAccent: cornerAccent))
    }
}

/// Octagonal "pixel-cut-corner" frame shape -- the Character screen's
/// distinct chunky chrome (vs. the smooth bracket-corner HUD panels
/// used everywhere else), matching the design mockup's CSS clip-path.
struct PixelFrameShape: Shape {
    var cut: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = min(cut, min(rect.width, rect.height) / 2)
        p.move(to: CGPoint(x: rect.minX + c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.closeSubpath()
        return p
    }
}

/// A warm, flickering flame-colored glow -- the "fire aura" effect,
/// reused everywhere the streak/flame motif shows up (Streak
/// Celebration, Home's streak pill and Hunter Log tile, and as an
/// equippable cosmetic on the Character screen).
struct FireAura: View {
    var diameter: CGFloat = 60
    var withEmbers: Bool = true
    @State private var flicker = false

    private let emberSpecs: [(color: Color, dx: CGFloat, dy: CGFloat, delay: Double)]

    init(diameter: CGFloat = 60, withEmbers: Bool = true) {
        self.diameter = diameter
        self.withEmbers = withEmbers
        let r = diameter / 2
        emberSpecs = [
            (HunterTheme.emberOrange, -r * 0.3, -r * 0.7, 0),
            (HunterTheme.gold, r * 0.75, -r * 0.1, 0.9),
            (HunterTheme.emberRed, -r * 0.85, r * 0.35, 1.6)
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [HunterTheme.emberRed.opacity(0.5), HunterTheme.gold.opacity(0.15), .clear],
                        center: .center, startRadius: 0, endRadius: diameter / 2
                    )
                )
                .frame(width: diameter, height: diameter)
                .blur(radius: 3)
                .scaleEffect(flicker ? 1.08 : 0.94)
                .opacity(flicker ? 1 : 0.65)

            if withEmbers {
                ForEach(0..<emberSpecs.count, id: \.self) { i in
                    let e = emberSpecs[i]
                    Ember(color: e.color, dx: e.dx, dy: e.dy, delay: e.delay)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                flicker = true
            }
        }
        .allowsHitTesting(false)
    }
}

private struct Ember: View {
    let color: Color
    let dx: CGFloat
    let dy: CGFloat
    let delay: Double
    @State private var rise = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .shadow(color: color.opacity(0.9), radius: 4)
            .offset(x: dx, y: rise ? dy - 26 : dy)
            .opacity(rise ? 0 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.3).repeatForever(autoreverses: false).delay(delay)) {
                    rise = true
                }
            }
    }
}

/// Chunky segmented bar -- SwiftUI's equivalent of the mockups' striped
/// CSS "repeating-linear-gradient" bars, used for XP and stats alike.
struct SegmentedBar: View {
    var fraction: Double
    var color: Color
    var segments: Int = 20
    var height: CGFloat = 10

    var body: some View {
        let filled = Int(min(max(fraction, 0), 1) * Double(segments))
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(i < filled ? color : color.opacity(0.14))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(color.opacity(0.08))
        .overlay(Rectangle().strokeBorder(color.opacity(0.4), lineWidth: 2))
    }
}
