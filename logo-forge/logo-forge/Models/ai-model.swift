import Foundation

// MARK: - AI Model
// Defines available AI models for logo generation and inpainting
// Users can choose based on their needs (text vs abstract vs inpainting)

enum AIModel: String, CaseIterable, Identifiable, Codable {
    case ideogramV3 = "Ideogram v3"
    case nanaBananaPro = "Nano Banana Pro"
    case fluxFillPro = "Flux Fill Pro"

    var id: String { rawValue }

    /// Replicate API model path
    var replicateModel: String {
        switch self {
        case .ideogramV3: return "ideogram-ai/ideogram-v3-balanced"
        case .nanaBananaPro: return "google/nano-banana-pro"
        case .fluxFillPro: return "black-forest-labs/flux-fill-pro"
        }
    }

    /// Cost per image generation/inpainting
    var costPerImage: Decimal {
        switch self {
        case .ideogramV3: return 0.08
        case .nanaBananaPro: return 0.15
        case .fluxFillPro: return 0.05
        }
    }

    /// Human-readable description for UI
    var description: String {
        switch self {
        case .ideogramV3: return "Best for logos with text/typography"
        case .nanaBananaPro: return "Best for abstract, artistic logos"
        case .fluxFillPro: return "Best for seamless inpainting"
        }
    }

    /// Short label for toggle UI
    var shortLabel: String {
        switch self {
        case .ideogramV3: return "Text"
        case .nanaBananaPro: return "Abstract"
        case .fluxFillPro: return "Flux"
        }
    }

    /// Whether this model supports generation
    var supportsGeneration: Bool {
        switch self {
        case .ideogramV3, .nanaBananaPro: return true
        case .fluxFillPro: return false
        }
    }

    /// Whether this model supports inpainting
    var supportsInpainting: Bool {
        switch self {
        case .ideogramV3, .fluxFillPro: return true
        case .nanaBananaPro: return false
        }
    }

    /// Description for inpainting model picker
    var inpaintDescription: String {
        switch self {
        case .ideogramV3: return "Best for text edits"
        case .fluxFillPro: return "Best for seamless blending"
        case .nanaBananaPro: return ""
        }
    }

    /// Models that support generation
    static var generationModels: [AIModel] {
        allCases.filter { $0.supportsGeneration }
    }

    /// Models that support inpainting
    static var inpaintingModels: [AIModel] {
        allCases.filter { $0.supportsInpainting }
    }
}
