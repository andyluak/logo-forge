import Foundation

// MARK: - AI Model
// Defines available AI models for logo generation
// Users can choose based on their needs (text vs abstract)

enum AIModel: String, CaseIterable, Identifiable, Codable {
    case ideogramV3 = "Ideogram v3"
    case nanaBananaPro = "Nano Banana Pro"

    var id: String { rawValue }

    /// Replicate API model path
    var replicateModel: String {
        switch self {
        case .ideogramV3: return "ideogram-ai/ideogram-v3-balanced"
        case .nanaBananaPro: return "google/nano-banana-pro"
        }
    }

    /// Cost per image generation
    var costPerImage: Decimal {
        switch self {
        case .ideogramV3: return 0.08
        case .nanaBananaPro: return 0.15
        }
    }

    /// Human-readable description for UI
    var description: String {
        switch self {
        case .ideogramV3: return "Best for logos with text/typography"
        case .nanaBananaPro: return "Best for abstract, artistic logos"
        }
    }

    /// Short label for toggle UI
    var shortLabel: String {
        switch self {
        case .ideogramV3: return "Text"
        case .nanaBananaPro: return "Abstract"
        }
    }
}
