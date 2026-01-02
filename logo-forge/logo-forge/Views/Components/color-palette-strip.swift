import SwiftUI
import AppKit

struct ColorPaletteStrip: View {
    let palette: ColorPalette?

    @State private var copiedColorID: UUID?

    var body: some View {
        if let palette, !palette.colors.isEmpty {
            HStack(spacing: 16) {
                // Label
                Text("PALETTE")
                    .font(LogoForgeTheme.body(11, weight: .medium))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
                    .tracking(1.5)

                // Color swatches
                HStack(spacing: 8) {
                    ForEach(Array(palette.colors.enumerated()), id: \.element.id) { index, color in
                        ColorSwatch(
                            color: color,
                            isCopied: copiedColorID == color.id
                        ) {
                            copyToClipboard(color.hex)
                            showCopiedFeedback(for: color.id)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                Spacer()

                // Copy all button
                Button {
                    let allHex = palette.colors.map(\.hex).joined(separator: ", ")
                    copyToClipboard(allHex)
                } label: {
                    Text("Copy All")
                        .font(LogoForgeTheme.body(12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(LogoForgeTheme.canvas)
        }
    }

    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func showCopiedFeedback(for id: UUID) {
        copiedColorID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedColorID == id {
                copiedColorID = nil
            }
        }
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    let color: ExtractedColor
    let isCopied: Bool
    var onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.color)
                    .frame(width: 24, height: 24)
                    .shadow(
                        color: .black.opacity(0.2),
                        radius: isHovered ? 4 : 2,
                        y: isHovered ? 2 : 1
                    )

                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .help(color.hex)
    }
}

#Preview {
    VStack {
        ColorPaletteStrip(palette: ColorPalette(colors: [
            ExtractedColor(r: 255, g: 87, b: 51, coverage: 0.3),
            ExtractedColor(r: 51, g: 87, b: 255, coverage: 0.25),
            ExtractedColor(r: 87, g: 255, b: 51, coverage: 0.2),
            ExtractedColor(r: 255, g: 255, b: 51, coverage: 0.15)
        ]))

        ColorPaletteStrip(palette: nil)
    }
    .frame(width: 500)
    .padding()
}
