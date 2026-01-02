import AppKit
import SwiftUI

// MARK: - Image Processor
// Applies editing operations to images using Core Graphics
// All operations are non-destructive - we always start from the original

struct ImageProcessor {

    // MARK: - Main Processing

    /// Apply all edits from EditorState to an image
    /// Returns a new NSImage with all transformations applied
    static func process(_ image: NSImage, with state: EditorState) -> NSImage {
        var result = image

        // Order matters! Apply in this sequence:
        // 1. Crop (reduces the image area first)
        // 2. Rotation (changes dimensions if 90° or 270°)
        // 3. Flip (mirrors the rotated image)
        // 4. Padding (adds space around)
        // 5. Background (fills behind everything)

        if let cropRect = state.cropRect {
            result = crop(result, to: cropRect)
        }

        if state.rotation != .none {
            result = rotate(result, by: state.rotation)
        }

        if state.flipHorizontal {
            result = flip(result, horizontal: true)
        }

        if state.flipVertical {
            result = flip(result, horizontal: false)
        }

        if state.padding > 0 {
            result = addPadding(result, amount: state.padding)
        }

        if state.backgroundColor != .clear {
            result = addBackground(result, color: state.backgroundColor)
        }

        return result
    }

    // MARK: - Individual Operations

    /// Crop image to a normalized rect (0-1 coordinates, SwiftUI coordinate system)
    /// Uses CGImage for pixel-accurate cropping (NSImage.size is in points, not pixels)
    /// SwiftUI: Y=0 at top, Y=1 at bottom
    /// CGImage: Y=0 at top, Y=1 at bottom (same as SwiftUI!)
    static func crop(_ image: NSImage, to normalizedRect: CGRect) -> NSImage {
        // Get CGImage for pixel-accurate cropping
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }

        // Get actual pixel dimensions (not points!)
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)

        // Convert normalized coordinates to pixel coordinates
        // CGImage has Y=0 at top (same as SwiftUI), so NO flip needed
        let cropRect = CGRect(
            x: normalizedRect.origin.x * pixelWidth,
            y: normalizedRect.origin.y * pixelHeight,
            width: normalizedRect.width * pixelWidth,
            height: normalizedRect.height * pixelHeight
        )

        // Clamp to valid bounds
        let imageBounds = CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        let clampedRect = cropRect.intersection(imageBounds)
        guard !clampedRect.isEmpty else { return image }

        // Crop the CGImage
        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            return image
        }

        // Create NSImage with correct pixel dimensions
        // Set size to match pixels for 1:1 display
        let newSize = NSSize(width: croppedCGImage.width, height: croppedCGImage.height)
        let newImage = NSImage(cgImage: croppedCGImage, size: newSize)

        return newImage
    }

    /// Rotate image by 90° increments
    static func rotate(_ image: NSImage, by rotation: EditorState.Rotation) -> NSImage {
        guard rotation != .none else { return image }

        let size = image.size
        let radians = rotation.degrees * .pi / 180

        // For 90° and 270°, width and height swap
        let newSize: NSSize
        if rotation == .clockwise90 || rotation == .clockwise270 {
            newSize = NSSize(width: size.height, height: size.width)
        } else {
            newSize = size
        }

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()

        // Move origin to center, rotate, then draw
        let transform = NSAffineTransform()
        transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        transform.rotate(byRadians: radians)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()

        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }

    /// Flip image horizontally or vertically
    static func flip(_ image: NSImage, horizontal: Bool) -> NSImage {
        let size = image.size
        let newImage = NSImage(size: size)

        newImage.lockFocus()

        let transform = NSAffineTransform()
        if horizontal {
            // Flip horizontally: scale X by -1, translate to compensate
            transform.translateX(by: size.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
        } else {
            // Flip vertically: scale Y by -1, translate to compensate
            transform.translateX(by: 0, yBy: size.height)
            transform.scaleX(by: 1, yBy: -1)
        }
        transform.concat()

        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }

    /// Add padding around the image
    static func addPadding(_ image: NSImage, amount: CGFloat) -> NSImage {
        let oldSize = image.size
        let newSize = NSSize(
            width: oldSize.width + (amount * 2),
            height: oldSize.height + (amount * 2)
        )

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()

        // Draw original image centered (offset by padding amount)
        let drawRect = NSRect(
            x: amount,
            y: amount,
            width: oldSize.width,
            height: oldSize.height
        )
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: oldSize), operation: .copy, fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }

    /// Add solid background color behind image
    static func addBackground(_ image: NSImage, color: Color) -> NSImage {
        let size = image.size
        let newImage = NSImage(size: size)

        newImage.lockFocus()

        // Fill background
        let nsColor = NSColor(color)
        nsColor.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw image on top
        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1.0)

        newImage.unlockFocus()
        return newImage
    }
}
