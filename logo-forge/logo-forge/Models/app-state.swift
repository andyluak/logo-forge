import SwiftUI

@Observable
final class AppState {
    var isGenerating = false
    var generationProgress: Double = 0
    var error: AppError?
    var apiKeyValid = false
    var toastMessage: String?

    func clearError() {
        error = nil
    }

    func showToast(_ message: String) {
        toastMessage = message
    }

    func dismissToast() {
        toastMessage = nil
    }
}
