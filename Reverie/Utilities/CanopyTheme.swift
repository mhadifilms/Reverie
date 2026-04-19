//
//  CanopyTheme.swift
//  Reverie
//
//  Design tokens from the Canopy.html spec — a quieter music app.
//  Paper-white daily surfaces with natural green accents; a silky-blue
//  immersive gradient reserved for the full-screen player and onboarding.
//

import SwiftUI

/// The single source of truth for Reverie's palette, typography, spacing,
/// radii, and shared gradients. Every screen pulls from here so the visual
/// language stays coherent and the spec is easy to re-tune in one place.
enum CanopyTheme {

    // MARK: - Colors

    enum Palette {
        // Neutrals — warm paper in light, deep ink in dark.
        static let paper = Color("canopy.paper",
                                 light: Color(hex: 0xFAF9F7),
                                 dark: Color(hex: 0x0F1511))
        static let paperAlt = Color("canopy.paperAlt",
                                    light: Color(hex: 0xF0EEE9),
                                    dark: Color(hex: 0x14170F))
        static let surface = Color("canopy.surface",
                                   light: Color(hex: 0xFFFFFF),
                                   dark: Color(hex: 0x1C201C))
        static let surfaceSunken = Color("canopy.surfaceSunken",
                                         light: Color(hex: 0xF2EFE9),
                                         dark: Color(hex: 0x0B0F0B))
        static let ink = Color("canopy.ink",
                               light: Color(hex: 0x0F1511),
                               dark: Color(hex: 0xF3EFE8))
        static let muted = Color("canopy.muted",
                                 light: Color(white: 0.09, opacity: 0.56),
                                 dark: Color(white: 0.92, opacity: 0.56))
        static let faint = Color("canopy.faint",
                                 light: Color(white: 0.09, opacity: 0.28),
                                 dark: Color(white: 0.92, opacity: 0.32))
        static let hair = Color("canopy.hair",
                                light: Color(white: 0.09, opacity: 0.08),
                                dark: Color(white: 1.0, opacity: 0.10))

        // Greens — brand accent ramp per the spec (CC namespace).
        static let greenInk = Color(hex: 0x0F2D22)
        static let greenDeep = Color(hex: 0x1A5140)
        static let green = Color(hex: 0x2A8F6A)
        static let mint = Color(hex: 0x8FCFAE)
        static let mintSoft = Color(hex: 0xC6E5D2)
        static let mintVeil = Color("canopy.mintVeil",
                                    light: Color(hex: 0xE8F4EC),
                                    dark: Color(hex: 0x1A3A30))

        // Blues — immersive player / splash.
        static let blueDeep = Color(hex: 0x083D48)
        static let blueMid = Color(hex: 0x1C617B)
        static let blueSoft = Color(hex: 0x84A8BE)
        static let blueMist = Color(hex: 0xD2ECF2)

        // Warm tones (dune) for sand-family gradients + placeholder covers.
        static let sandDeep = Color(hex: 0x8A6A4B)
        static let sand = Color(hex: 0xC6A87B)
        static let sandSoft = Color(hex: 0xE8DFC9)

        // Semantic
        static let success = green
        static let warning = Color(hex: 0xC88A2E)
        static let danger = Color(hex: 0xB0412B)
        static let info = blueMid
    }

    // MARK: - Typography

    /// Paired SF Pro Display (titles, track names) + SF Pro Text (body).
    /// `heroItalic` picks up New York serif where available for the spec's
    /// italic hero accents ("for the rain.").
    enum Typography {
        static let displayLarge = Font.system(size: 40, weight: .bold).leading(.tight)
        static let displayHero = Font.system(size: 34, weight: .bold).leading(.tight)
        static let displayTitle = Font.system(size: 28, weight: .bold).leading(.tight)
        static let heroItalic = Font.system(size: 32, weight: .medium, design: .serif).italic()
        static let largeTitle = Font.system(size: 26, weight: .bold).leading(.tight)
        static let title = Font.system(size: 22, weight: .bold)
        static let title2 = Font.system(size: 18, weight: .semibold)
        static let trackTitle = Font.system(size: 16, weight: .semibold)
        static let headline = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let bodyEmphasized = Font.system(size: 15, weight: .medium)
        static let caption = Font.system(size: 13, weight: .regular)
        static let captionEmphasized = Font.system(size: 13, weight: .medium)
        static let micro = Font.system(size: 11, weight: .medium)
        static let tab = Font.system(size: 10, weight: .medium)
    }

    // MARK: - Spacing

    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 28
        static let xxxl: CGFloat = 40
    }

    // MARK: - Radius

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Gradients

    /// Silky blue immersive gradient — onboarding splash + full-screen player.
    static let silkyBlue = LinearGradient(
        colors: [Palette.blueDeep, Palette.blueMid, Palette.blueSoft, Palette.blueMist],
        startPoint: UnitPoint(x: 0.2, y: 0),
        endPoint: UnitPoint(x: 0.8, y: 1)
    )

    /// Deep forest gradient — hero cards, curated mix callouts.
    static let canopyGreen = LinearGradient(
        colors: [Palette.greenDeep, Palette.green, Palette.mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warm dune gradient — for "acoustic hush" style tiles.
    static let duneWarm = LinearGradient(
        colors: [Palette.sandDeep, Palette.sand, Palette.sandSoft],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color helpers

extension Color {
    /// Build a color from a 0xRRGGBB literal (alpha 1.0).
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Named color with light/dark variants resolved at draw time. Keeps us
    /// from needing an asset catalog entry for every token.
    init(_ name: String, light: Color, dark: Color) {
        #if canImport(UIKit)
        let ui = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        }
        self.init(uiColor: ui)
        _ = name
        #elseif canImport(AppKit)
        let ns = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        }
        self.init(nsColor: ns)
        _ = name
        #else
        self = light
        _ = name
        _ = dark
        #endif
    }
}

// MARK: - Canopy wordmark

/// The "C + leaf arc" wordmark from the Canopy.html spec, drawn inline so
/// we don't ship an extra asset. Tints follow `color`.
struct CanopyMark: View {
    var size: CGFloat = 28
    var color: Color = CanopyTheme.Palette.greenDeep

    var body: some View {
        Canvas { ctx, _ in
            let s = size
            let center = CGPoint(x: s / 2, y: s / 2)
            let radius = s * 0.42

            var arc = Path()
            arc.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-55),
                endAngle: .degrees(55),
                clockwise: true
            )
            ctx.stroke(
                arc,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.6 * (s / 32), lineCap: .round)
            )

            var leaf = Path()
            leaf.move(to: CGPoint(x: center.x, y: center.y + s * 0.02))
            leaf.addCurve(
                to: CGPoint(x: center.x + s * 0.38, y: center.y - s * 0.04),
                control1: CGPoint(x: center.x + s * 0.18, y: center.y - s * 0.10),
                control2: CGPoint(x: center.x + s * 0.30, y: center.y - s * 0.10)
            )
            leaf.addCurve(
                to: CGPoint(x: center.x, y: center.y + s * 0.02),
                control1: CGPoint(x: center.x + s * 0.20, y: center.y + s * 0.14),
                control2: CGPoint(x: center.x + s * 0.06, y: center.y + s * 0.12)
            )
            ctx.fill(leaf, with: .color(color.opacity(0.95)))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Reverie")
    }
}

// MARK: - Status / tone pills

struct StatusPill: View {
    enum Tone {
        case active, idle, ended, attention, info, warning, success
    }

    let text: String
    let tone: Tone

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(CanopyTheme.Typography.micro)
                .foregroundStyle(color)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .padding(.horizontal, CanopyTheme.Space.sm)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var color: Color {
        switch tone {
        case .active, .success: return CanopyTheme.Palette.green
        case .idle: return CanopyTheme.Palette.muted
        case .ended: return CanopyTheme.Palette.faint
        case .attention, .warning: return CanopyTheme.Palette.warning
        case .info: return CanopyTheme.Palette.info
        }
    }
}

// MARK: - Liquid-glass pill / circle

/// Reusable liquid-glass surface matching the Canopy.html spec's `CGlass`:
/// 72% white fill + ultraThinMaterial + hairline border + downward shadow.
/// `dark` flips the fill for over-gradient placements (full-screen player).
struct CanopyGlass<Content: View>: View {
    var cornerRadius: CGFloat = CanopyTheme.Radius.pill
    var dark: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(dark ? Color.white.opacity(0.14) : Color.white.opacity(0.72))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        dark ? Color.white.opacity(0.18) : Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: dark
                    ? Color.black.opacity(0.35)
                    : Color(red: 20/255, green: 60/255, blue: 40/255).opacity(0.08),
                radius: 16, x: 0, y: 8
            )
    }
}

// MARK: - Card surfaces

extension View {
    /// Paper-card surface: white fill, 18-pt radius, hairline border, padding.
    func canopyCard(padding: CGFloat = CanopyTheme.Space.lg) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.lg, style: .continuous)
                    .fill(CanopyTheme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.lg, style: .continuous)
                    .strokeBorder(CanopyTheme.Palette.hair, lineWidth: 0.5)
            )
    }
}

// MARK: - Button styles

struct CanopyPrimaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CanopyTheme.Typography.headline)
            .foregroundStyle(Color(hex: 0xFAF9F7))
            .padding(.vertical, 14)
            .padding(.horizontal, CanopyTheme.Space.xl)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.xxl, style: .continuous)
                    .fill(CanopyTheme.Palette.greenDeep)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
    }
}

struct CanopySecondaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CanopyTheme.Typography.headline)
            .foregroundStyle(CanopyTheme.Palette.greenDeep)
            .padding(.vertical, 14)
            .padding(.horizontal, CanopyTheme.Space.xl)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.xxl, style: .continuous)
                    .fill(CanopyTheme.Palette.mintVeil)
                    .opacity(configuration.isPressed ? 0.78 : 1)
            )
    }
}

/// White pill over the silky blue gradient (player, splash CTA).
struct CanopyLightButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CanopyTheme.Typography.headline)
            .foregroundStyle(CanopyTheme.Palette.blueDeep)
            .padding(.vertical, 16)
            .padding(.horizontal, CanopyTheme.Space.xl)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(
                RoundedRectangle(cornerRadius: CanopyTheme.Radius.xxl, style: .continuous)
                    .fill(Color.white)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
    }
}

extension ButtonStyle where Self == CanopyPrimaryButtonStyle {
    static var canopyPrimary: CanopyPrimaryButtonStyle { .init() }
    static func canopyPrimary(fullWidth: Bool) -> CanopyPrimaryButtonStyle { .init(isFullWidth: fullWidth) }
}
extension ButtonStyle where Self == CanopySecondaryButtonStyle {
    static var canopySecondary: CanopySecondaryButtonStyle { .init() }
    static func canopySecondary(fullWidth: Bool) -> CanopySecondaryButtonStyle { .init(isFullWidth: fullWidth) }
}
extension ButtonStyle where Self == CanopyLightButtonStyle {
    static var canopyLight: CanopyLightButtonStyle { .init() }
    static func canopyLight(fullWidth: Bool) -> CanopyLightButtonStyle { .init(isFullWidth: fullWidth) }
}

// MARK: - Downloaded / downloading glyphs

/// The filled green checkmark circle used to mark a track as "on device".
struct DownloadedGlyph: View {
    var size: CGFloat = 14
    var body: some View {
        ZStack {
            Circle().fill(CanopyTheme.Palette.green)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Downloaded")
    }
}

/// Ring-progress glyph used while a track is actively downloading.
struct DownloadingGlyph: View {
    var progress: Double
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Circle()
                .stroke(CanopyTheme.Palette.green.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(CanopyTheme.Palette.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            RoundedRectangle(cornerRadius: 1)
                .fill(CanopyTheme.Palette.green)
                .frame(width: size * 0.18, height: size * 0.4)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Downloading, \(Int(progress * 100)) percent")
    }
}
