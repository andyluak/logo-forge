import SwiftUI
import AppKit

// MARK: - Editor State
// Tracks all editing operations applied to an image
// Uses @Observable so SwiftUI automatically updates when values change

@Observable
final class EditorState {
    // MARK: - Edit Properties

    /// Background color behind the logo (for transparent PNGs)
    var backgroundColor: Color = .clear

    /// Padding around the image in pixels (0-100)
    var padding: CGFloat = 0

    /// Rotation in 90° increments (0, 90, 180, 270)
    var rotation: Rotation = .none

    /// Horizontal flip
    var flipHorizontal: Bool = false

    /// Vertical flip
    var flipVertical: Bool = false

    // MARK: - State

    /// The original image before any edits
    var originalImage: NSImage?

    /// Whether any edits have been made
    var hasChanges: Bool {
        backgroundColor != .clear ||
        padding != 0 ||
        rotation != .none ||
        flipHorizontal ||
        flipVertical
    }

    // MARK: - Rotation Enum

    enum Rotation: Int, CaseIterable {
        case none = 0
        case clockwise90 = 90
        case clockwise180 = 180
        case clockwise270 = 270

        var degrees: CGFloat {
            CGFloat(rawValue)
        }

        /// Rotate 90° clockwise
        func rotatedClockwise() -> Rotation {
            switch self {
            case .none: return .clockwise90
            case .clockwise90: return .clockwise180
            case .clockwise180: return .clockwise270
            case .clockwise270: return .none
            }
        }

        /// Rotate 90° counter-clockwise
        func rotatedCounterClockwise() -> Rotation {
            switch self {
            case .none: return .clockwise270
            case .clockwise90: return .none
            case .clockwise180: return .clockwise90
            case .clockwise270: return .clockwise180
            }
        }
    }

    // MARK: - Actions

    /// Reset all edits to default
    func reset() {
        backgroundColor = .clear
        padding = 0
        rotation = .none
        flipHorizontal = false
        flipVertical = false
    }

    /// Load an image for editing
    func loadImage(_ image: NSImage) {
        originalImage = image
        reset()
    }
}
