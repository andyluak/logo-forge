import Foundation

// MARK: - AI Model
// Defines available AI models for logo generation and inpainting
// Users can choose based on their needs (text vs abstract vs inpainting)

enum AIModel: String, CaseIterable, Identifiable, Codable {
    case ideogramV3 = "Ideogram v3"
    case nanaBananaPro = "Nano Banana Pro"
    case fluxFillPro = "Flux Fill Pro"
    case briaEraser = "Bria Eraser"

    var id: String { rawValue }

    /// Replicate API model path
    var replicateModel: String {
        switch self {
        case .ideogramV3: return "ideogram-ai/ideogram-v3-balanced"
        case .nanaBananaPro: return "google/nano-banana-pro"
        case .fluxFillPro: return "black-forest-labs/flux-fill-pro"
        case .briaEraser: return "bria/eraser"
        }
    }

    /// Cost per image generation/inpainting
    var costPerImage: Decimal {
        switch self {
        case .ideogramV3: return 0.08
        case .nanaBananaPro: return 0.15
        case .fluxFillPro: return 0.05
        case .briaEraser: return 0.04
        }
    }

    /// Human-readable description for UI
    var description: String {
        switch self {
        case .ideogramV3: return "Best for logos with text/typography"
        case .nanaBananaPro: return "Best for abstract, artistic logos"
        case .fluxFillPro: return "Best for seamless inpainting"
        case .briaEraser: return "Best for removing objects/text"
        }
    }

    /// Short label for toggle UI
    var shortLabel: String {
        switch self {
        case .ideogramV3: return "Text"
        case .nanaBananaPro: return "Abstract"
        case .fluxFillPro: return "Flux"
        case .briaEraser: return "Eraser"
        }
    }

    /// Whether this model supports generation
    var supportsGeneration: Bool {
        switch self {
        case .ideogramV3, .nanaBananaPro: return true
        case .fluxFillPro, .briaEraser: return false
        }
    }

    /// Whether this model supports inpainting
    var supportsInpainting: Bool {
        switch self {
        case .ideogramV3, .fluxFillPro, .briaEraser: return true
        case .nanaBananaPro: return false
        }
    }

    /// Whether this model requires a prompt for inpainting
    var requiresPrompt: Bool {
        switch self {
        case .briaEraser: return false
        default: return true
        }
    }

    /// Description for inpainting model picker
    var inpaintDescription: String {
        switch self {
        case .ideogramV3: return "Best for text edits"
        case .fluxFillPro: return "Best for seamless blending"
        case .briaEraser: return "Best for removing (no prompt)"
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
