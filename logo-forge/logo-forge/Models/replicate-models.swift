import Foundation
import AppKit  // For NSImage

// MARK: - Request Models
// These are what we SEND to Replicate's API
// Different models have different input schemas

/// Protocol for model-specific request inputs
protocol ReplicateInputProtocol: Encodable {}

/// Factory to create the right request for each AI model
enum ReplicateRequestFactory {
    static func createRequest(prompt: String, referenceImages: [Data], model: AIModel) -> any Encodable {
        switch model {
        case .nanaBananaPro:
            return NanaBananaProRequest(prompt: prompt, referenceImages: referenceImages)
        case .ideogramV3:
            return IdeogramV3Request(prompt: prompt, referenceImages: referenceImages)
        case .fluxFillPro:
            // Flux Fill Pro is inpainting-only, shouldn't be used for generation
            // Return Ideogram as fallback (won't be called if supportsGeneration is checked)
            return IdeogramV3Request(prompt: prompt, referenceImages: referenceImages)
        }
    }
}

// MARK: - Nano Banana Pro Request
// Google's model - uses image_input, resolution, output_format

struct NanaBananaProRequest: Encodable {
    let input: InputParams

    struct InputParams: Encodable {
        let prompt: String
        let imageInput: [String]?
        let resolution: String
        let aspectRatio: String
        let outputFormat: String

        enum CodingKeys: String, CodingKey {
            case prompt
            case imageInput = "image_input"
            case resolution
            case aspectRatio = "aspect_ratio"
            case outputFormat = "output_format"
        }
    }

    init(prompt: String, referenceImages: [Data] = []) {
        self.input = InputParams(
            prompt: prompt,
            imageInput: referenceImages.isEmpty ? nil : referenceImages.map { imageData in
                "data:image/png;base64," + imageData.base64EncodedString()
            },
            resolution: "1K",
            aspectRatio: "1:1",
            outputFormat: "png"
        )
    }
}

// MARK: - Ideogram V3 Request
// Best for text in logos - uses style_reference_images, style_type

struct IdeogramV3Request: Encodable {
    let input: InputParams

    struct InputParams: Encodable {
        let prompt: String
        let aspectRatio: String
        let styleType: String
        let magicPromptOption: String
        let styleReferenceImages: [String]?

        enum CodingKeys: String, CodingKey {
            case prompt
            case aspectRatio = "aspect_ratio"
            case styleType = "style_type"
            case magicPromptOption = "magic_prompt_option"
            case styleReferenceImages = "style_reference_images"
        }
    }

    init(prompt: String, referenceImages: [Data] = []) {
        self.input = InputParams(
            prompt: prompt,
            aspectRatio: "1:1",
            styleType: "Design",  // Best for logos
            magicPromptOption: "Auto",
            styleReferenceImages: referenceImages.isEmpty ? nil : referenceImages.map { imageData in
                "data:image/png;base64," + imageData.base64EncodedString()
            }
        )
    }
}

// MARK: - Legacy Compatibility
// Keep ReplicateCreateRequest for backwards compatibility

typealias ReplicateCreateRequest = NanaBananaProRequest

// MARK: - Response Models
// These are what we RECEIVE from Replicate's API

/// The prediction object returned by Replicate
/// Used for both create response and poll response
struct ReplicatePrediction: Decodable {
    let id: String
    let status: Status

    /// URL to the generated image (only present when status == .succeeded)
    /// This is a single string URL, not an array
    let output: String?

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
