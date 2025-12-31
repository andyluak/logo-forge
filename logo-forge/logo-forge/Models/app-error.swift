import Foundation

enum AppError: LocalizedError, Equatable {
    // Critical (modal)
    case missingAPIKey
    case invalidAPIKey

    // Generation (inline)
    case generationFailed(String)
    case contentFiltered
    case modelUnavailable

    // Transient (toast)
    case networkError
    case rateLimited(retryAfter: Int)
    case exportFailed(String)

    var severity: ErrorSeverity {
        switch self {
        case .missingAPIKey, .invalidAPIKey:
            return .critical
        case .generationFailed, .contentFiltered, .modelUnavailable:
            return .generation
        case .networkError, .rateLimited, .exportFailed:
            return .transient
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API Key Required"
        case .invalidAPIKey:
            return "Invalid API Key"
        case .generationFailed(let reason):
            return "Generation Failed: \(reason)"
        case .contentFiltered:
            return "Content Filtered"
        case .modelUnavailable:
            return "Model Unavailable"
        case .networkError:
            return "Network Error"
        case .rateLimited(let seconds):
            return "Rate Limited - Retry in \(seconds)s"
        case .exportFailed(let reason):
            return "Export Failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            return "Enter your Replicate API key in Settings."
        case .invalidAPIKey:
            return "Check your API key and try again."
        case .generationFailed:
            return "Try again or modify your prompt."
        case .contentFiltered:
            return "Your prompt was blocked by safety filters. Try a different prompt."
        case .modelUnavailable:
            return "The model is temporarily unavailable. Please try again later."
        case .networkError:
            return "Check your internet connection and try again."
        case .rateLimited(let seconds):
            return "Please wait \(seconds) seconds before trying again."
        case .exportFailed:
            return "Check file permissions and available disk space."
        }
    }
}

enum ErrorSeverity {
    case critical
    case generation
    case transient
}
