import SwiftUI
import AppKit

// MARK: - Inpaint Mode View
/// Full-screen inpainting interface with image, mask canvas, and toolbar

struct InpaintModeView: View {
    let sourceImage: NSImage
    var onComplete: (NSImage) -> Void
    var onCancel: () -> Void

    @State private var maskState = MaskCanvasState()
    @State private var selectedModel: AIModel = .briaEraser  // Best for removing objects/text
    @State private var prompt = ""
    @State private var isGenerating = false
    @State private var error: String?
    @State private var resultImage: NSImage?

    private let inpaintingService = InpaintingService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Main canvas area
            ZStack {
                // Background
                LogoForgeTheme.canvas
                    .ignoresSafeArea()

                // Image + mask overlay
                canvasArea
            }

            // Toolbar at bottom
            InpaintToolbar(
                maskState: maskState,
                selectedModel: $selectedModel,
                prompt: $prompt,
                onApply: performInpaint,
                onCancel: handleCancel
            )
        }
        .background(LogoForgeTheme.canvas)
        .alert("Inpainting Failed", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            if let error {
                Text(error)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("INPAINT MODE")
                .font(LogoForgeTheme.body(11, weight: .medium))
                .foregroundStyle(LogoForgeTheme.textSecondary)
                .tracking(1.5)

            Spacer()

            // Instructions
            Text("Paint over areas to modify")
                .font(LogoForgeTheme.body(12))
                .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.8))

            Spacer()

            // Keyboard shortcuts hint
            HStack(spacing: 12) {
                shortcutHint("B", "Brush")
                shortcutHint("E", "Eraser")
                shortcutHint("[/]", "Size")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LogoForgeTheme.surface)
    }

    private func shortcutHint(_ key: String, _ action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(LogoForgeTheme.body(10, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(LogoForgeTheme.hover)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(action)
                .font(LogoForgeTheme.body(10))
                .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.6))
        }
    }

    // MARK: - Canvas Area

    private var canvasArea: some View {
        GeometryReader { geometry in
            let imageSize = sourceImage.size
            let displayImage = resultImage ?? sourceImage

            ZStack {
                // Checkerboard background for transparency
                CheckerboardPattern()
                    .frame(
                        width: min(geometry.size.width - 80, imageSize.width),
                        height: min(geometry.size.height - 80, imageSize.height)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(0.3)

                // Source/result image
                Image(nsImage: displayImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        maxWidth: geometry.size.width - 80,
                        maxHeight: geometry.size.height - 80
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Mask canvas overlay (only when not showing result)
                if resultImage == nil {
                    MaskCanvas(
                        state: maskState,
                        imageSize: imageSize
                    )
                    .frame(
                        width: min(geometry.size.width - 80, imageSize.width * scaleFactor(geometry: geometry)),
                        height: min(geometry.size.height - 80, imageSize.height * scaleFactor(geometry: geometry))
                    )
                }

                // Loading overlay
                if isGenerating {
                    loadingOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onKeyPress(.init("b")) {
            maskState.isErasing = false
            return .handled
        }
        .onKeyPress(.init("e")) {
            maskState.isErasing = true
            return .handled
        }
        .onKeyPress(.init("[")) {
            maskState.brushSize = max(5, maskState.brushSize - 5)
            return .handled
        }
        .onKeyPress(.init("]")) {
            maskState.brushSize = min(100, maskState.brushSize + 5)
            return .handled
        }
    }

    private func scaleFactor(geometry: GeometryProxy) -> CGFloat {
        let maxWidth = geometry.size.width - 80
        let maxHeight = geometry.size.height - 80
        return min(maxWidth / sourceImage.size.width, maxHeight / sourceImage.size.height)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                    .tint(LogoForgeTheme.paper)

                Text("Inpainting...")
                    .font(LogoForgeTheme.body(14))
                    .foregroundStyle(LogoForgeTheme.paper)

                Text("This may take 30-60 seconds")
                    .font(LogoForgeTheme.body(11))
                    .foregroundStyle(LogoForgeTheme.paperMuted)
            }
            .padding(32)
            .background(LogoForgeTheme.surface.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Actions

    private func performInpaint() {
        guard maskState.hasMask else { return }
        // Only require prompt if model needs it
        guard !prompt.isEmpty || !selectedModel.requiresPrompt else { return }

        isGenerating = true
        error = nil

        Task {
            do {
                // Get actual pixel dimensions from the image representation
                let pixelSize = sourceImage.pixelSize ?? sourceImage.size

                // Strokes were recorded in logical point coordinates (sourceImage.size)
                // Scale them to actual pixel dimensions
                guard let maskImage = maskState.generateMaskImage(
                    size: pixelSize,
                    sourceSize: sourceImage.size
                ) else {
                    throw AppError.generationFailed("Failed to generate mask")
                }

                // Call inpainting service
                let result = try await inpaintingService.inpaint(
                    image: sourceImage,
                    mask: maskImage,
                    prompt: prompt,
                    model: selectedModel
                )

                await MainActor.run {
                    resultImage = result
                    isGenerating = false
                }
            } catch let appError as AppError {
                await MainActor.run {
                    error = appError.localizedDescription
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func handleCancel() {
        if resultImage != nil {
            // If we have a result, ask if they want to keep it
            onComplete(resultImage!)
        } else {
            onCancel()
        }
    }
}

// MARK: - Checkerboard Pattern

struct CheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 10
            let rows = Int(ceil(size.height / squareSize))
            let cols = Int(ceil(size.width / squareSize))

            for row in 0..<rows {
                for col in 0..<cols {
                    let isEven = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )

                    context.fill(
                        Path(rect),
                        with: .color(isEven ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Create a sample image for preview
    let image = NSImage(size: NSSize(width: 512, height: 512))
    image.lockFocus()
    NSColor.blue.setFill()
    NSRect(origin: .zero, size: image.size).fill()
    image.unlockFocus()

    return InpaintModeView(
        sourceImage: image,
        onComplete: { _ in },
        onCancel: { }
    )
    .frame(width: 800, height: 600)
}
