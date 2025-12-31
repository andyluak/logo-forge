import Foundation
import AppKit  // For NSImage

// MARK: - Request Models
// These are what we SEND to Replicate's API

/// The top-level request body for creating a prediction
/// Replicate expects: { "model": "...", "input": { ... } }
struct ReplicateCreateRequest: Encodable {
    let model: String
    let input: InputParams

    struct InputParams: Encodable {
        let prompt: String

        /// Base64-encoded reference images (up to 14)
        /// Optional - only sent if user provides reference images
        let imageInput: [String]?

        /// "1K", "2K", or "4K" - we'll use 1K for speed/cost
        let resolution: String

        /// "1:1" for square logos
        let aspectRatio: String

        /// "png" for transparency support
        let outputFormat: String

        // Replicate expects snake_case in JSON
        enum CodingKeys: String, CodingKey {
            case prompt
            case imageInput = "image_input"
            case resolution
            case aspectRatio = "aspect_ratio"
            case outputFormat = "output_format"
        }
    }

    /// Convenience initializer with sensible defaults for logo generation
    init(prompt: String, referenceImages: [Data] = []) {
        self.model = "google/nano-banana-pro"
        self.input = InputParams(
            prompt: prompt,
            imageInput: referenceImages.isEmpty ? nil : referenceImages.map { $0.base64EncodedString() },
            resolution: "1K",
            aspectRatio: "1:1",
            outputFormat: "png"
        )
    }
}

// MARK: - Response Models
// These are what we RECEIVE from Replicate's API

/// The prediction object returned by Replicate
/// Used for both create response and poll response
struct ReplicatePrediction: Decodable {
    let id: String
    let status: Status

    /// URLs to the generated images (only present when status == .succeeded)
    let output: [String]?

    /// Error message (only present when status == .failed)
    let error: String?

    /// Possible states of a prediction
    /// starting → processing → succeeded/failed/canceled
    enum Status: String, Decodable {
        case starting    // Job queued, waiting for GPU
        case processing  // GPU is working on it
        case succeeded   // Done! Output URLs available
        case failed      // Something went wrong
        case canceled    // User or system canceled

        var isTerminal: Bool {
            switch self {
            case .succeeded, .failed, .canceled: return true
            case .starting, .processing: return false
            }
        }
    }
}

// MARK: - Internal Models
// These are for our app's internal use

/// Represents a generated logo variation
struct GeneratedVariation: Identifiable {
    let id: UUID
    let image: NSImage
    let prompt: String
    let style: Style
    let createdAt: Date

    init(image: NSImage, prompt: String, style: Style) {
        self.id = UUID()
        self.image = image
        self.prompt = prompt
        self.style = style
        self.createdAt = Date()
    }
}
