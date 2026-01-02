import SwiftUI

// MARK: - Crop Overlay
/// Interactive crop selection that appears ONLY over the actual image

struct CropOverlay: View {
    @Binding var cropRect: CGRect?
    let imageSize: CGSize
    let containerSize: CGSize
    var onConfirm: () -> Void

    @State private var tempRect: CGRect?

    private let minSize: CGFloat = 30
    private let handleSize: CGFloat = 16

    // Calculate where the image actually renders (aspect fit)
    private var imageFrame: CGRect {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var width: CGFloat
        var height: CGFloat

        if imageAspect > containerAspect {
            // Image is wider - constrained by width
            width = containerSize.width
            height = width / imageAspect
        } else {
            // Image is taller - constrained by height
            height = containerSize.height
            width = height * imageAspect
        }

        let x = (containerSize.width - width) / 2
        let y = (containerSize.height - height) / 2

        return CGRect(x: x, y: y, width: width, height: height)
    }

    // The rect to display (temp while dragging, or saved crop)
    private var activeRect: CGRect? {
        tempRect ?? cropRect
    }

    var body: some View {
        ZStack {
            // Only dim the image area
            if let rect = activeRect {
                DimOverlay(
                    cropRect: normalizedToImage(rect),
                    imageFrame: imageFrame
                )
            } else {
                // Show dim over whole image when no selection
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
            }

            // Crop box with handles (only if selection exists)
            if let rect = activeRect {
                let displayRect = normalizedToImage(rect)

                // White border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: displayRect.width, height: displayRect.height)
                    .position(x: displayRect.midX, y: displayRect.midY)

                // Grid lines
                GridLines(rect: displayRect)

                // Corner handles
                ForEach(Corner.allCases, id: \.self) { corner in
                    HandleView()
                        .frame(width: handleSize, height: handleSize)
                        .position(cornerPosition(corner, in: displayRect))
                        .gesture(handleDrag(for: corner))
                }
            }

            // Instructions when no selection
            if activeRect == nil {
                VStack(spacing: 8) {
                    Image(systemName: "crop")
                        .font(.system(size: 40, weight: .thin))
                    Text("Drag to select crop area")
                        .font(.system(size: 14))
                }
                .foregroundStyle(.white.opacity(0.8))
                .position(x: imageFrame.midX, y: imageFrame.midY)
            }
        }
        // Only accept gestures within the image area
        .contentShape(Path(imageFrame))
        .gesture(newSelectionDrag)
    }

    // MARK: - Coordinate Conversion

    /// Convert normalized rect (0-1) to screen coordinates within image
    private func normalizedToImage(_ normalized: CGRect) -> CGRect {
        CGRect(
            x: imageFrame.origin.x + normalized.origin.x * imageFrame.width,
            y: imageFrame.origin.y + normalized.origin.y * imageFrame.height,
            width: normalized.width * imageFrame.width,
            height: normalized.height * imageFrame.height
        )
    }

    /// Convert screen point to normalized coordinates (0-1)
    private func pointToNormalized(_ point: CGPoint) -> CGPoint? {
        // Check if point is within image bounds
        guard imageFrame.contains(point) else { return nil }

        let x = (point.x - imageFrame.origin.x) / imageFrame.width
        let y = (point.y - imageFrame.origin.y) / imageFrame.height

        return CGPoint(
            x: max(0, min(1, x)),
            y: max(0, min(1, y))
        )
    }

    // MARK: - New Selection Drag

    private var newSelectionDrag: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard let start = pointToNormalized(value.startLocation),
                      let current = pointToNormalized(value.location) else {
                    return
                }

                let minX = min(start.x, current.x)
                let minY = min(start.y, current.y)
                let maxX = max(start.x, current.x)
                let maxY = max(start.y, current.y)

                tempRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }
            .onEnded { _ in
                if let rect = tempRect {
                    let pixelW = rect.width * imageFrame.width
                    let pixelH = rect.height * imageFrame.height
                    if pixelW >= minSize && pixelH >= minSize {
                        cropRect = rect
                    }
                }
                tempRect = nil
            }
    }

    // MARK: - Handle Drag

    private func handleDrag(for corner: Corner) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard var rect = cropRect ?? tempRect,
                      let loc = pointToNormalized(value.location) else { return }

                switch corner {
                case .topLeft:
                    let newW = rect.maxX - loc.x
                    let newH = rect.maxY - loc.y
                    if newW * imageFrame.width >= minSize && newH * imageFrame.height >= minSize {
                        rect = CGRect(x: loc.x, y: loc.y, width: newW, height: newH)
                    }
                case .topRight:
                    let newW = loc.x - rect.minX
                    let newH = rect.maxY - loc.y
                    if newW * imageFrame.width >= minSize && newH * imageFrame.height >= minSize {
                        rect = CGRect(x: rect.minX, y: loc.y, width: newW, height: newH)
                    }
                case .bottomLeft:
                    let newW = rect.maxX - loc.x
                    let newH = loc.y - rect.minY
                    if newW * imageFrame.width >= minSize && newH * imageFrame.height >= minSize {
                        rect = CGRect(x: loc.x, y: rect.minY, width: newW, height: newH)
                    }
                case .bottomRight:
                    let newW = loc.x - rect.minX
                    let newH = loc.y - rect.minY
                    if newW * imageFrame.width >= minSize && newH * imageFrame.height >= minSize {
                        rect = CGRect(x: rect.minX, y: rect.minY, width: newW, height: newH)
                    }
                }

                tempRect = rect
            }
            .onEnded { _ in
                if let rect = tempRect {
                    cropRect = rect
                }
                tempRect = nil
            }
    }

    // MARK: - Corner Positions

    private func cornerPosition(_ corner: Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
}

// MARK: - Corner Enum

private enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - Dim Overlay with Cutout

private struct DimOverlay: View {
    let cropRect: CGRect
    let imageFrame: CGRect

    var body: some View {
        Canvas { context, size in
            // Only dim the image area, with cutout for crop selection
            var path = Path()
            path.addRect(imageFrame)
            path.addRect(cropRect)
            context.fill(path, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - Grid Lines

private struct GridLines: View {
    let rect: CGRect

    var body: some View {
        Path { path in
            // Vertical thirds
            let x1 = rect.minX + rect.width / 3
            let x2 = rect.minX + rect.width * 2 / 3
            path.move(to: CGPoint(x: x1, y: rect.minY))
            path.addLine(to: CGPoint(x: x1, y: rect.maxY))
            path.move(to: CGPoint(x: x2, y: rect.minY))
            path.addLine(to: CGPoint(x: x2, y: rect.maxY))

            // Horizontal thirds
            let y1 = rect.minY + rect.height / 3
            let y2 = rect.minY + rect.height * 2 / 3
            path.move(to: CGPoint(x: rect.minX, y: y1))
            path.addLine(to: CGPoint(x: rect.maxX, y: y1))
            path.move(to: CGPoint(x: rect.minX, y: y2))
            path.addLine(to: CGPoint(x: rect.maxX, y: y2))
        }
        .stroke(Color.white.opacity(0.4), lineWidth: 1)
    }
}

// MARK: - Handle View

private struct HandleView: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.black.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 2)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)

        CropOverlay(
            cropRect: .constant(nil),
            imageSize: CGSize(width: 512, height: 512),
            containerSize: CGSize(width: 400, height: 400),
            onConfirm: {}
        )
    }
    .frame(width: 500, height: 500)
}
