import SwiftUI

// MARK: - Hero Area
// The centerpiece - selected logo displayed large with subtle depth effects

struct HeroArea: View {
    let image: NSImage?
    let editorState: EditorState?
    let isGenerating: Bool
    let progress: GenerationState.Status

    @State private var isHovering = false

    /// Apply editor transformations for live preview
    /// When cropping, show original image so crop matches what's displayed
    private var displayImage: NSImage? {
        guard let image = image else { return nil }

        // When actively cropping, show ORIGINAL image - no transforms
        // This ensures what user draws matches what gets cropped
        if isCropping {
            return image
        }

        guard let state = editorState, state.hasChanges else { return image }
        return ImageProcessor.process(image, with: state)
    }

    /// Whether crop mode is active
    private var isCropping: Bool {
        editorState?.isCropping ?? false
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Subtle radial glow
                LogoForgeTheme.heroGlow

                if let displayImage = displayImage {
                    // The logo - commanding presence
                    Image(nsImage: displayImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            maxWidth: geo.size.width * 0.6,
                            maxHeight: geo.size.height * 0.75
                        )
                        // Dramatic shadow for depth (disabled during crop)
                        .shadow(
                            color: .black.opacity(isCropping ? 0 : 0.4),
                            radius: 40,
                            y: 20
                        )
                        // Subtle hover lift (disabled during crop)
                        .scaleEffect(isHovering && !isCropping ? 1.02 : 1.0)
                        .animation(LogoForgeTheme.smoothEase, value: isHovering)
                        .onHover { isHovering = $0 }
                        // Crop overlay on top of image frame
                        .overlay {
                            if isCropping, let state = editorState {
                                GeometryReader { imageGeo in
                                    CropOverlay(
                                        cropRect: Binding(
                                            get: { state.cropRect },
                                            set: { state.cropRect = $0 }
                                        ),
                                        imageSize: displayImage.size,
                                        containerSize: imageGeo.size,
                                        onConfirm: {
                                            state.isCropping = false
                                        }
                                    )
                                }
                            }
                        }

                } else if isGenerating {
                    // Generation in progress
                    GeneratingState(progress: progress)
                } else {
                    // Empty state
                    EmptyHeroState()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(LogoForgeTheme.canvas)
    }
}

// MARK: - Empty Hero State

struct EmptyHeroState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.3))

            Text("Your logo will appear here")
                .font(LogoForgeTheme.displayFallback(18))
                .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.5))
        }
    }
}

// MARK: - Generating State

struct GeneratingState: View {
    let progress: GenerationState.Status

    @State private var rotation: Double = 0

    private var progressText: String {
        switch progress {
        case .generating(let completed, let total):
            return "Generating \(completed)/\(total)..."
        case .preparing:
            return "Preparing..."
        default:
            return "Generating..."
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Custom spinner
            Circle()
                .stroke(LogoForgeTheme.border, lineWidth: 2)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(LogoForgeTheme.paper, lineWidth: 2)
                        .rotationEffect(.degrees(rotation))
                )
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text(progressText)
                .font(LogoForgeTheme.body(14))
                .foregroundStyle(LogoForgeTheme.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        HeroArea(image: nil, editorState: nil, isGenerating: false, progress: GenerationState.Status.idle)
            .frame(height: 300)

        HeroArea(image: nil, editorState: nil, isGenerating: true, progress: GenerationState.Status.generating(completed: 2, total: 4))
            .frame(height: 300)
    }
}
