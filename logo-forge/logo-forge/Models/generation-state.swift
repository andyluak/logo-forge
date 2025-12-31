import SwiftUI

// MARK: - Generation State
// Tracks everything about the current generation session
// Separate from AppState because it's specific to the workspace

@Observable
final class GenerationState {
    // MARK: Input
    var prompt: String = ""
    var selectedStyle: Style = .minimal
    var variationCount: Int = 4
    var referenceImages: [NSImage] = []

    // MARK: Output
    var variations: [GeneratedVariation] = []
    var selectedVariationID: UUID?

    // MARK: Status
    var status: Status = .idle
    var error: AppError?

    /// Current generation status
    enum Status: Equatable {
        case idle                    // Nothing happening
        case preparing               // Encoding images, preparing request
        case generating(completed: Int, total: Int)  // In progress
        case completed               // All done
        case failed                  // Error occurred

        var isGenerating: Bool {
            if case .generating = self { return true }
            if case .preparing = self { return true }
            return false
        }

        var statusText: String {
            switch self {
            case .idle:
                return "Ready"
            case .preparing:
                return "Preparing..."
            case .generating(let completed, let total):
                return "Generating \(completed)/\(total)..."
            case .completed:
                return "Complete"
            case .failed:
                return "Failed"
            }
        }
    }

    // MARK: Computed Properties

    var canGenerate: Bool {
        !prompt.isEmpty && !status.isGenerating
    }

    var selectedVariation: GeneratedVariation? {
        guard let id = selectedVariationID else { return nil }
        return variations.first { $0.id == id }
    }

    // MARK: Actions

    func reset() {
        prompt = ""
        selectedStyle = .minimal
        variationCount = 4
        referenceImages = []
        variations = []
        selectedVariationID = nil
        status = .idle
        error = nil
    }

    func clearResults() {
        variations = []
        selectedVariationID = nil
        status = .idle
        error = nil
    }

    func selectVariation(_ id: UUID) {
        selectedVariationID = id
    }
}
