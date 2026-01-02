import SwiftUI

// MARK: - Primary Button Style
// Refined presence without screaming

struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LogoForgeTheme.canvas)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(LogoForgeTheme.paper)
                    .shadow(
                        color: LogoForgeTheme.paper.opacity(isHovered ? 0.3 : 0),
                        radius: 16
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(LogoForgeTheme.quickEase, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LogoForgeTheme.textSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(LogoForgeTheme.border, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHovered ? LogoForgeTheme.hover : .clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(LogoForgeTheme.quickEase, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovered ? LogoForgeTheme.textPrimary : LogoForgeTheme.textSecondary)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? LogoForgeTheme.hover : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(LogoForgeTheme.quickEase, value: configuration.isPressed)
            .animation(LogoForgeTheme.quickEase, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Danger Button Style

struct DangerButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LogoForgeTheme.error)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(LogoForgeTheme.error.opacity(0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHovered ? LogoForgeTheme.error.opacity(0.1) : .clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(LogoForgeTheme.quickEase, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
