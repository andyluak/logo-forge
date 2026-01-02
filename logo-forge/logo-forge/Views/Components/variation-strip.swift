import SwiftUI

// MARK: - Variation Strip
// Horizontal gallery of thumbnails with subtle selection state

struct VariationStrip: View {
    let variations: [GeneratedVariation]
    @Binding var selectedID: UUID?
    var onRegenerate: ((UUID) -> Void)?

    @State private var hoveredID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(variations.enumerated()), id: \.element.id) { index, variation in
                    VariationThumbnail(
                        image: variation.image,
                        isSelected: selectedID == variation.id,
                        isHovered: hoveredID == variation.id,
                        index: index
                    )
                    .onTapGesture {
                        withAnimation(LogoForgeTheme.smoothEase) {
                            selectedID = variation.id
                        }
                    }
                    .onHover { hovering in
                        withAnimation(LogoForgeTheme.quickEase) {
                            hoveredID = hovering ? variation.id : nil
                        }
                    }
                    .contextMenu {
                        if let onRegenerate {
                            Button {
                                onRegenerate(variation.id)
                            } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)
        }
        .background(LogoForgeTheme.canvas)
    }
}

// MARK: - Variation Thumbnail

struct VariationThumbnail: View {
    let image: NSImage
    let isSelected: Bool
    let isHovered: Bool
    let index: Int

    var body: some View {
        VStack(spacing: 10) {
            // Thumbnail
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                // Dynamic shadow based on state
                .shadow(
                    color: .black.opacity(isSelected ? 0.5 : 0.25),
                    radius: isSelected ? 20 : 10,
                    y: isSelected ? 10 : 5
                )
                // Scale on selection/hover
                .scaleEffect(isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))

            // Selection indicator
            Circle()
                .fill(isSelected ? LogoForgeTheme.paper : .clear)
                .stroke(
                    isSelected ? LogoForgeTheme.paper : LogoForgeTheme.border,
                    lineWidth: 1.5
                )
                .frame(width: 8, height: 8)
        }
        .animation(LogoForgeTheme.smoothEase, value: isSelected)
        .animation(LogoForgeTheme.quickEase, value: isHovered)
        // Staggered entrance animation
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9))
                .animation(LogoForgeTheme.stagger(index: index)),
            removal: .opacity
        ))
    }
}

// MARK: - Preview

#Preview {
    VariationStrip(
        variations: [],
        selectedID: .constant(nil)
    )
    .frame(height: 140)
    .background(LogoForgeTheme.canvas)
}
