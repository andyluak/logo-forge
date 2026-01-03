import SwiftUI

// MARK: - Hero Area
// The centerpiece - selected logo displayed large with subtle depth effects

struct HeroArea: View {
    let image: NSImage?
    let editorState: EditorState?
    let isGenerating: Bool
    let progress: GenerationState.Status

    @State private var isHovering = false

    /// Whether crop mode is active
    private var isCropping: Bool {
        editorState?.isCropping ?? false
    }

    /// The image to display - original when cropping, processed otherwise
    private var displayImage: NSImage? {
        guard let image = image else { return nil }

        // When cropping, show original so crop selection matches
        if isCropping {
            return image
        }

        guard let state = editorState, state.hasChanges else { return image }
        return ImageProcessor.process(image, with: state)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Subtle radial glow
                LogoForgeTheme.heroGlow

                if let displayImage = displayImage {
                    // Calculate the display size (60% width, 75% height max)
                    let maxWidth = geo.size.width * 0.6
                    let maxHeight = geo.size.height * 0.75
                    let imageSize = displayImage.size
                    let scale = min(maxWidth / imageSize.width, maxHeight / imageSize.height)
                    let displayWidth = imageSize.width * scale
                    let displayHeight = imageSize.height * scale

                    ZStack {
                        // The logo image
                        Image(nsImage: displayImage)
                            .resizable()
                            .frame(width: displayWidth, height: displayHeight)
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

                        // Crop overlay - exact same size as image
                        if isCropping, let state = editorState {
                            CropOverlaySimple(
                                cropRect: Binding(
                                    get: { state.cropRect },
                                    set: { state.cropRect = $0 }
                                ),
                                size: CGSize(width: displayWidth, height: displayHeight)
                            )
                            .frame(width: displayWidth, height: displayHeight)
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

// MARK: - Simple Crop Overlay
// Positioned exactly over the image, no coordinate conversion needed

struct CropOverlaySimple: View {
    @Binding var cropRect: CGRect?
    let size: CGSize

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    private let minSize: CGFloat = 30
    private let handleSize: CGFloat = 14

    // Current selection being drawn or existing crop
    private var activeRect: CGRect? {
        if let start = dragStart, let current = dragCurrent {
            return rectFromPoints(start, current)
        }
        return cropRect
    }

    // Convert normalized rect to display coordinates
    private func toDisplay(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    // Convert display point to normalized
    private func toNormalized(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: max(0, min(1, point.x / size.width)),
            y: max(0, min(1, point.y / size.height))
        )
    }

    // Create rect from two corner points
    private func rectFromPoints(_ p1: CGPoint, _ p2: CGPoint) -> CGRect {
        let minX = min(p1.x, p2.x)
        let minY = min(p1.y, p2.y)
        let maxX = max(p1.x, p2.x)
        let maxY = max(p1.y, p2.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var body: some View {
        ZStack {
            // Dim layer with cutout
            Canvas { context, canvasSize in
                var path = Path()
                path.addRect(CGRect(origin: .zero, size: canvasSize))
                if let rect = activeRect {
                    path.addRect(toDisplay(rect))
                }
                context.fill(path, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
            }

            // Selection box
            if let rect = activeRect {
                let displayRect = toDisplay(rect)

                // Border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: displayRect.width, height: displayRect.height)
                    .position(x: displayRect.midX, y: displayRect.midY)

                // Rule of thirds grid
                Path { path in
                    let x1 = displayRect.minX + displayRect.width / 3
                    let x2 = displayRect.minX + displayRect.width * 2 / 3
                    let y1 = displayRect.minY + displayRect.height / 3
                    let y2 = displayRect.minY + displayRect.height * 2 / 3

                    path.move(to: CGPoint(x: x1, y: displayRect.minY))
                    path.addLine(to: CGPoint(x: x1, y: displayRect.maxY))
                    path.move(to: CGPoint(x: x2, y: displayRect.minY))
                    path.addLine(to: CGPoint(x: x2, y: displayRect.maxY))
                    path.move(to: CGPoint(x: displayRect.minX, y: y1))
                    path.addLine(to: CGPoint(x: displayRect.maxX, y: y1))
                    path.move(to: CGPoint(x: displayRect.minX, y: y2))
                    path.addLine(to: CGPoint(x: displayRect.maxX, y: y2))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)

                // Corner handles
                ForEach(["tl", "tr", "bl", "br"], id: \.self) { corner in
                    let pos = cornerPosition(corner, in: displayRect)
                    Circle()
                        .fill(Color.white)
                        .frame(width: handleSize, height: handleSize)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .position(pos)
                        .gesture(cornerDrag(corner))
                }
            }

            // Instructions
            if activeRect == nil {
                VStack(spacing: 8) {
                    Image(systemName: "crop")
                        .font(.system(size: 36, weight: .thin))
                    Text("Drag to crop")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = toNormalized(value.startLocation)
                    }
                    dragCurrent = toNormalized(value.location)
                }
                .onEnded { _ in
                    if let rect = activeRect {
                        let w = rect.width * size.width
                        let h = rect.height * size.height
                        if w >= minSize && h >= minSize {
                            cropRect = rect
                        }
                    }
                    dragStart = nil
                    dragCurrent = nil
                }
        )
    }

    private func cornerPosition(_ corner: String, in rect: CGRect) -> CGPoint {
        switch corner {
        case "tl": return CGPoint(x: rect.minX, y: rect.minY)
        case "tr": return CGPoint(x: rect.maxX, y: rect.minY)
        case "bl": return CGPoint(x: rect.minX, y: rect.maxY)
        case "br": return CGPoint(x: rect.maxX, y: rect.maxY)
        default: return .zero
        }
    }

    private func cornerDrag(_ corner: String) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard var rect = cropRect else { return }
                let loc = toNormalized(value.location)

                switch corner {
                case "tl":
                    let newW = rect.maxX - loc.x
                    let newH = rect.maxY - loc.y
                    if newW * size.width >= minSize && newH * size.height >= minSize {
                        rect = CGRect(x: loc.x, y: loc.y, width: newW, height: newH)
                    }
                case "tr":
                    let newW = loc.x - rect.minX
                    let newH = rect.maxY - loc.y
                    if newW * size.width >= minSize && newH * size.height >= minSize {
                        rect = CGRect(x: rect.minX, y: loc.y, width: newW, height: newH)
                    }
                case "bl":
                    let newW = rect.maxX - loc.x
                    let newH = loc.y - rect.minY
                    if newW * size.width >= minSize && newH * size.height >= minSize {
                        rect = CGRect(x: loc.x, y: rect.minY, width: newW, height: newH)
                    }
                case "br":
                    let newW = loc.x - rect.minX
                    let newH = loc.y - rect.minY
                    if newW * size.width >= minSize && newH * size.height >= minSize {
                        rect = CGRect(x: rect.minX, y: rect.minY, width: newW, height: newH)
                    }
                default: break
                }

                cropRect = rect
            }
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
