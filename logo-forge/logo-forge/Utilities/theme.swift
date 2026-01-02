import SwiftUI

// MARK: - Logo Forge Theme
// Studio/Atelier aesthetic - the work is the interface

enum LogoForgeTheme {
    // MARK: - Core Palette

    /// Deep charcoal - the canvas everything sits on
    static let canvas = Color(hex: "1A1A1A")

    /// Slightly elevated surfaces (sidebar, cards)
    static let surface = Color(hex: "242424")

    /// Warm paper white - primary foreground, CTAs
    static let paper = Color(hex: "FAF8F5")

    /// Muted warm gray - secondary text
    static let paperMuted = Color(hex: "A8A4A0")

    /// Subtle warm accent for borders, dividers
    static let accent = Color(hex: "E8E4DF")

    // MARK: - Semantic Colors

    static let textPrimary = paper
    static let textSecondary = paperMuted
    static let selected = Color(hex: "3D3D3D")
    static let hover = Color(hex: "2A2A2A")
    static let border = Color(hex: "333333")

    // MARK: - Status Colors

    static let success = Color(hex: "4ADE80").opacity(0.9)
    static let warning = Color(hex: "FBBF24").opacity(0.9)
    static let error = Color(hex: "F87171").opacity(0.9)

    // MARK: - Gradients

    /// Subtle radial glow behind hero image
    static let heroGlow = RadialGradient(
        colors: [surface.opacity(0.4), canvas],
        center: .center,
        startRadius: 50,
        endRadius: 400
    )

    // MARK: - Animations

    /// Primary easing - confident, smooth
    static let smoothEase = Animation.easeOut(duration: 0.4)

    /// Quick interactions - hover, tap feedback
    static let quickEase = Animation.easeOut(duration: 0.2)

    /// Staggered reveals - for variation strip
    static func stagger(index: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(index) * 0.08)
    }

    // MARK: - Typography

    /// Display font - editorial feel
    static func display(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: .title)
    }

    /// Fallback if custom font unavailable
    static func displayFallback(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    /// UI font
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
