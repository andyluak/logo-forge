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
        // 1. Rotation (changes dimensions if 90° or 270°)
        // 2. Flip (mirrors the rotated image)
        // 3. Padding (adds space around)
        // 4. Background (fills behind everything)

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
