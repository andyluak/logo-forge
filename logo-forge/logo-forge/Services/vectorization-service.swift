import Foundation
import AppKit

// MARK: - Protocol

protocol VectorizationServiceProtocol: Sendable {
    func vectorize(_ image: NSImage) async throws -> Data  // Returns SVG data
    var costPerImage: Decimal { get }
}

// MARK: - Implementation

final class VectorizationService: VectorizationServiceProtocol, Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let replicateModel = "recraft-ai/recraft-vectorize"
    private let keychainService: KeychainService

    let costPerImage: Decimal = 0.01

    /// How often to check if vectorization is complete (seconds)
    private let pollInterval: Duration = .seconds(2)

    /// Maximum time to wait for vectorization (seconds)
    private let maxWaitTime: Duration = .seconds(120)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    // MARK: - Public API

    /// Convert a raster image to SVG vector format
    func vectorize(_ image: NSImage) async throws -> Data {
        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        // Convert NSImage to base64 PNG
        guard let imageData = imageToBase64PNG(image) else {
            throw AppError.generationFailed("Failed to encode image for vectorization")
        }

        // Create prediction
        let predictionID = try await createPrediction(imageData: imageData, apiKey: apiKey)

        // Poll for completion
        let svgURL = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Download the SVG data
        let svgData = try await downloadSVG(from: svgURL)

        return svgData
    }

    // MARK: - Private: Image Encoding

    private func imageToBase64PNG(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return "data:image/png;base64," + pngData.base64EncodedString()
    }

    // MARK: - Private: API Calls

    private func createPrediction(imageData: String, apiKey: String) async throws -> String {
        let url = baseURL.appending(path: "models/\(replicateModel)/predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = VectorizeRequest(image: imageData)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)
            return prediction.id

        case 401:
            throw AppError.invalidAPIKey

        case 429:
            throw AppError.rateLimited(retryAfter: 30)

        default:
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.generationFailed("Vectorization failed: \(responseString)")
        }
    }

    private func pollForCompletion(predictionID: String, apiKey: String) async throws -> URL {
        let url = baseURL.appending(path: "predictions/\(predictionID)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let startTime = Date()

        while true {
            if Date().timeIntervalSince(startTime) > Double(maxWaitTime.components.seconds) {
                throw AppError.generationFailed("Vectorization timed out")
            }

            try await Task.sleep(for: pollInterval)

            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)

            switch prediction.status {
            case .succeeded:
                guard let urlString = prediction.output,
                      let url = URL(string: urlString) else {
                    throw AppError.generationFailed("No output URL from vectorization")
                }
                return url

            case .failed:
                throw AppError.generationFailed(prediction.error ?? "Vectorization failed")

            case .canceled:
                throw AppError.generationFailed("Vectorization was canceled")

            case .starting, .processing:
                continue
            }
        }
    }

    private func downloadSVG(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppError.generationFailed("Failed to download SVG")
        }

        return data
    }
}

// MARK: - Request Model

private struct VectorizeRequest: Encodable {
    let input: Input

    struct Input: Encodable {
        let image: String
    }

    init(image: String) {
        self.input = Input(image: image)
    }
}
