import Foundation
import AppKit

// MARK: - Protocol
// Protocols let us swap implementations (real vs mock for testing)

protocol ReplicateServiceProtocol: Sendable {
    func generate(prompt: String, style: Style, references: [Data]) async throws -> NSImage
    func generateVariations(prompt: String, style: Style, references: [Data], count: Int) async throws -> [NSImage]
}

// MARK: - Implementation

final class ReplicateService: ReplicateServiceProtocol, Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let keychainService: KeychainService  // Concrete type for Sendable

    /// How often to check if generation is complete (seconds)
    private let pollInterval: Duration = .seconds(2)

    /// Maximum time to wait for generation (seconds)
    private let maxWaitTime: Duration = .seconds(120)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    // MARK: - Public API

    /// Generate a single logo image
    /// This is the main entry point - it handles the full flow:
    /// 1. Create prediction (POST)
    /// 2. Poll until complete (GET)
    /// 3. Download the image
    func generate(prompt: String, style: Style, references: [Data]) async throws -> NSImage {
        // Get API key from Keychain
        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        // Combine user prompt with style suffix
        // e.g., "mountain logo" + "minimal flat design, clean lines..."
        let fullPrompt = style == .custom ? prompt : "\(prompt), \(style.promptSuffix)"

        // Step 1: Create the prediction job
        let predictionID = try await createPrediction(prompt: fullPrompt, references: references, apiKey: apiKey)

        // Step 2: Poll until it's done
        let imageURL = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Step 3: Download the actual image
        let image = try await downloadImage(from: imageURL)

        return image
    }

    /// Generate multiple variations in parallel
    /// Uses Swift's TaskGroup for concurrent execution
    func generateVariations(prompt: String, style: Style, references: [Data], count: Int) async throws -> [NSImage] {
        // TaskGroup runs multiple async tasks concurrently
        // All 4 API calls happen at the same time, not one after another
        try await withThrowingTaskGroup(of: NSImage.self) { group in
            for _ in 0..<count {
                group.addTask {
                    try await self.generate(prompt: prompt, style: style, references: references)
                }
            }

            // Collect results as they complete
            var images: [NSImage] = []
            for try await image in group {
                images.append(image)
            }
            return images
        }
    }

    // MARK: - Private: API Calls

    /// Step 1: Create a prediction job
    /// POST /predictions with the model and input parameters
    /// Returns the prediction ID for polling
    private func createPrediction(prompt: String, references: [Data], apiKey: String) async throws -> String {
        let url = baseURL.appending(path: "predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ReplicateCreateRequest(prompt: prompt, referenceImages: references)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        switch httpResponse.statusCode {
        case 201:
            // Success - parse the prediction ID
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)
            return prediction.id

        case 401:
            throw AppError.invalidAPIKey

        case 429:
            // Rate limited - Replicate tells us to slow down
            throw AppError.rateLimited(retryAfter: 30)

        case 422:
            // Invalid input (usually prompt issues)
            throw AppError.generationFailed("Invalid input parameters")

        default:
            throw AppError.generationFailed("HTTP \(httpResponse.statusCode)")
        }
    }

    /// Step 2: Poll until the prediction completes
    /// GET /predictions/{id} repeatedly until status is terminal
    /// Returns the output image URL on success
    private func pollForCompletion(predictionID: String, apiKey: String) async throws -> URL {
        let url = baseURL.appending(path: "predictions/\(predictionID)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let startTime = Date()

        // Keep polling until we get a terminal status or timeout
        while true {
            // Check timeout
            if Date().timeIntervalSince(startTime) > Double(maxWaitTime.components.seconds) {
                throw AppError.generationFailed("Generation timed out")
            }

            // Wait before next poll
            try await Task.sleep(for: pollInterval)

            // Make the request
            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)

            switch prediction.status {
            case .succeeded:
                // Done! Get the output URL
                guard let urlString = prediction.output?.first,
                      let url = URL(string: urlString) else {
                    throw AppError.generationFailed("No output URL in response")
                }
                return url

            case .failed:
                let errorMessage = prediction.error ?? "Unknown error"
                if errorMessage.lowercased().contains("safety") || errorMessage.lowercased().contains("filter") {
                    throw AppError.contentFiltered
                }
                throw AppError.generationFailed(errorMessage)

            case .canceled:
                throw AppError.generationFailed("Generation was canceled")

            case .starting, .processing:
                // Still working, continue polling
                continue
            }
        }
    }

    /// Step 3: Download the generated image
    /// Simple GET request to fetch the PNG
    private func downloadImage(from url: URL) async throws -> NSImage {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppError.generationFailed("Failed to download image")
        }

        guard let image = NSImage(data: data) else {
            throw AppError.generationFailed("Invalid image data")
        }

        return image
    }
}
