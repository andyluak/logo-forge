import SwiftUI
import AppKit

// MARK: - Mask Canvas State
/// Tracks the mask painting state including brush settings and stroke data

@Observable
final class MaskCanvasState {
    /// All strokes painted on the canvas
    var strokes: [MaskStroke] = []

    /// Currently active stroke (while dragging)
    var currentStroke: MaskStroke?

    /// Brush size in points
    var brushSize: CGFloat = 40

    /// Whether eraser mode is active
    var isErasing: Bool = false

    /// Whether soft edges are enabled
    var softEdges: Bool = true

    /// Mask visibility (0-1)
    var maskOpacity: Double = 0.5

    /// Whether the mask has any content
    var hasMask: Bool {
        !strokes.isEmpty || currentStroke != nil
    }

    /// Clear all strokes
    func clear() {
        strokes.removeAll()
        currentStroke = nil
    }

    /// Undo last stroke
    func undoLastStroke() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
    }
}

// MARK: - Mask Stroke
/// A single continuous brush stroke

struct MaskStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    let brushSize: CGFloat
    let isEraser: Bool
    let softEdges: Bool

    init(point: CGPoint, brushSize: CGFloat, isEraser: Bool, softEdges: Bool) {
        self.points = [point]
        self.brushSize = brushSize
        self.isEraser = isEraser
        self.softEdges = softEdges
    }

    mutating func addPoint(_ point: CGPoint) {
        points.append(point)
    }
}

// MARK: - Mask Canvas View
/// Canvas overlay for painting the inpaint mask

struct MaskCanvas: View {
    @Bindable var state: MaskCanvasState
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / imageSize.width,
                geometry.size.height / imageSize.height
            )
            let scaledSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )
            let offset = CGPoint(
                x: (geometry.size.width - scaledSize.width) / 2,
                y: (geometry.size.height - scaledSize.height) / 2
            )

            ZStack {
                // Mask overlay
                MaskOverlayView(
                    strokes: state.strokes + (state.currentStroke.map { [$0] } ?? []),
                    opacity: state.maskOpacity,
                    scale: scale
                )
                .frame(width: scaledSize.width, height: scaledSize.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Brush cursor
                BrushCursor(
                    size: state.brushSize * scale,
                    isErasing: state.isErasing
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(
                            location: value.location,
                            offset: offset,
                            scale: scale,
                            size: scaledSize
                        )
                    }
                    .onEnded { _ in
                        finishStroke()
                    }
            )
        }
    }

    private func handleDrag(location: CGPoint, offset: CGPoint, scale: CGFloat, size: CGSize) {
        // Convert to image coordinates
        let imageX = (location.x - offset.x) / scale
        let imageY = (location.y - offset.y) / scale
        let point = CGPoint(x: imageX, y: imageY)

        // Clamp to image bounds
        guard imageX >= 0, imageX <= imageSize.width,
              imageY >= 0, imageY <= imageSize.height else {
            return
        }

        if var current = state.currentStroke {
            current.addPoint(point)
            state.currentStroke = current
        } else {
            state.currentStroke = MaskStroke(
                point: point,
                brushSize: state.brushSize,
                isEraser: state.isErasing,
                softEdges: state.softEdges
            )
        }
    }

    private func finishStroke() {
        if let stroke = state.currentStroke {
            state.strokes.append(stroke)
            state.currentStroke = nil
        }
    }
}

// MARK: - Mask Overlay View
/// Renders the mask strokes as a semi-transparent overlay

struct MaskOverlayView: View {
    let strokes: [MaskStroke]
    let opacity: Double
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                guard stroke.points.count > 0 else { continue }

                let scaledBrush = stroke.brushSize * scale
                let color: Color = stroke.isEraser ? .clear : .red.opacity(opacity)

                if stroke.points.count == 1 {
                    // Single point - draw circle
                    let point = CGPoint(
                        x: stroke.points[0].x * scale,
                        y: stroke.points[0].y * scale
                    )
                    let rect = CGRect(
                        x: point.x - scaledBrush / 2,
                        y: point.y - scaledBrush / 2,
                        width: scaledBrush,
                        height: scaledBrush
                    )

                    if stroke.isEraser {
                        context.blendMode = .destinationOut
                    }

                    context.fill(
                        Path(ellipseIn: rect),
                        with: stroke.isEraser ? .color(.white) : .color(color)
                    )

                    context.blendMode = .normal
                } else {
                    // Multiple points - draw path with stroke
                    var path = Path()
                    path.move(to: CGPoint(
                        x: stroke.points[0].x * scale,
                        y: stroke.points[0].y * scale
                    ))

                    for point in stroke.points.dropFirst() {
                        path.addLine(to: CGPoint(
                            x: point.x * scale,
                            y: point.y * scale
                        ))
                    }

                    if stroke.isEraser {
                        context.blendMode = .destinationOut
                    }

                    context.stroke(
                        path,
                        with: stroke.isEraser ? .color(.white) : .color(color),
                        style: StrokeStyle(
                            lineWidth: scaledBrush,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                    context.blendMode = .normal
                }
            }
        }
    }
}

// MARK: - Brush Cursor
/// Visual indicator for brush size and mode

struct BrushCursor: View {
    let size: CGFloat
    let isErasing: Bool

    @State private var cursorPosition: CGPoint = .zero

    var body: some View {
        Circle()
            .strokeBorder(
                isErasing ? Color.white : Color.red,
                style: StrokeStyle(lineWidth: 2, dash: isErasing ? [4, 4] : [])
            )
            .frame(width: size, height: size)
            .position(cursorPosition)
            .allowsHitTesting(false)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    cursorPosition = location
                case .ended:
                    break
                }
            }
    }
}

// MARK: - Mask Image Generation
/// Converts strokes to an NSImage mask for the API

extension MaskCanvasState {
    /// Generate a binary mask image from the strokes
    /// White = areas to inpaint, Black = areas to keep
    /// - Parameters:
    ///   - size: Target size in pixels for the mask
    ///   - sourceSize: Optional source size the strokes were recorded in (for scaling)
    func generateMaskImage(size: CGSize, sourceSize: CGSize? = nil) -> NSImage? {
        let pixelWidth = Int(size.width)
        let pixelHeight = Int(size.height)

        // Create bitmap at exact pixel dimensions (not points)
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        // Calculate scale factor if strokes were recorded at different size
        let scale: CGFloat
        if let sourceSize = sourceSize, sourceSize.width > 0 {
            scale = size.width / sourceSize.width
        } else {
            scale = 1.0
        }

        // Draw into the bitmap context
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        // Start with black (keep everything)
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw strokes in white (areas to inpaint)
        for stroke in strokes {
            if stroke.isEraser {
                NSColor.black.setStroke()
            } else {
                NSColor.white.setStroke()
            }

            let scaledBrushSize = stroke.brushSize * scale

            let path = NSBezierPath()
            path.lineWidth = scaledBrushSize
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            guard let first = stroke.points.first else { continue }

            let scaledFirstX = first.x * scale
            let scaledFirstY = first.y * scale

            if stroke.points.count == 1 {
                // Single point - draw filled circle
                let rect = NSRect(
                    x: scaledFirstX - scaledBrushSize / 2,
                    y: size.height - scaledFirstY - scaledBrushSize / 2,
                    width: scaledBrushSize,
                    height: scaledBrushSize
                )
                let circlePath = NSBezierPath(ovalIn: rect)
                if stroke.isEraser {
                    NSColor.black.setFill()
                } else {
                    NSColor.white.setFill()
                }
                circlePath.fill()
            } else {
                path.move(to: NSPoint(x: scaledFirstX, y: size.height - scaledFirstY))

                for point in stroke.points.dropFirst() {
                    let scaledX = point.x * scale
                    let scaledY = point.y * scale
                    path.line(to: NSPoint(x: scaledX, y: size.height - scaledY))
                }

                path.stroke()
            }

            // Apply soft edges if enabled
            if stroke.softEdges && !stroke.isEraser {
                // Draw additional passes with decreasing opacity for feathered edge
                for i in 1...3 {
                    let alpha = 0.3 - Double(i) * 0.1
                    let extraWidth = scaledBrushSize + CGFloat(i * 4) * scale

                    NSColor.white.withAlphaComponent(alpha).setStroke()

                    let softPath = NSBezierPath()
                    softPath.lineWidth = extraWidth
                    softPath.lineCapStyle = .round
                    softPath.lineJoinStyle = .round

                    if stroke.points.count == 1 {
                        continue // Skip soft edges for single points
                    }

                    softPath.move(to: NSPoint(x: scaledFirstX, y: size.height - scaledFirstY))
                    for point in stroke.points.dropFirst() {
                        let scaledX = point.x * scale
                        let scaledY = point.y * scale
                        softPath.line(to: NSPoint(x: scaledX, y: size.height - scaledY))
                    }
                    softPath.stroke()
                }
            }
        }

        NSGraphicsContext.restoreGraphicsState()

        // Create NSImage from bitmap
        let image = NSImage(size: size)
        image.addRepresentation(bitmapRep)
        return image
    }
}

// MARK: - Preview

#Preview {
    let state = MaskCanvasState()

    return ZStack {
        Color.gray

        MaskCanvas(
            state: state,
            imageSize: CGSize(width: 512, height: 512)
        )
    }
    .frame(width: 600, height: 600)
}
