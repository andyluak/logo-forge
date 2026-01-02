import Foundation
import AppKit

// MARK: - Protocol

protocol UpscalingServiceProtocol: Sendable {
    func upscale(_ image: NSImage, factor: Int) async throws -> NSImage
    var costPerImage: Decimal { get }
}

// MARK: - Implementation

final class UpscalingService: UpscalingServiceProtocol, Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let replicateModel = "nightmareai/real-esrgan"
    private let keychainService: KeychainService

    let costPerImage: Decimal = 0.02

    /// How often to check if upscaling is complete (seconds)
    private let pollInterval: Duration = .seconds(2)

    /// Maximum time to wait for upscaling (seconds)
    private let maxWaitTime: Duration = .seconds(120)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    // MARK: - Public API

    /// Upscale an image by the given factor (default 4x)
    func upscale(_ image: NSImage, factor: Int = 4) async throws -> NSImage {
        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        // Convert NSImage to base64 PNG
        guard let imageData = imageToBase64PNG(image) else {
            throw AppError.generationFailed("Failed to encode image for upscaling")
        }

        // Create prediction
        let predictionID = try await createPrediction(imageData: imageData, scale: factor, apiKey: apiKey)

        // Poll for completion
        let imageURL = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Download the upscaled image
        let upscaledImage = try await downloadImage(from: imageURL)

        return upscaledImage
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

    private func createPrediction(imageData: String, scale: Int, apiKey: String) async throws -> String {
        let url = baseURL.appending(path: "models/\(replicateModel)/predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = UpscaleRequest(image: imageData, scale: scale)
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
            throw AppError.generationFailed("Upscaling failed: \(responseString)")
        }
    }

    private func pollForCompletion(predictionID: String, apiKey: String) async throws -> URL {
        let url = baseURL.appending(path: "predictions/\(predictionID)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let startTime = Date()

        while true {
            if Date().timeIntervalSince(startTime) > Double(maxWaitTime.components.seconds) {
                throw AppError.generationFailed("Upscaling timed out")
            }

            try await Task.sleep(for: pollInterval)

            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)

            switch prediction.status {
            case .succeeded:
                guard let urlString = prediction.output,
                      let url = URL(string: urlString) else {
                    throw AppError.generationFailed("No output URL from upscaling")
                }
                return url

            case .failed:
                throw AppError.generationFailed(prediction.error ?? "Upscaling failed")

            case .canceled:
                throw AppError.generationFailed("Upscaling was canceled")

            case .starting, .processing:
                continue
            }
        }
    }

    private func downloadImage(from url: URL) async throws -> NSImage {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppError.generationFailed("Failed to download upscaled image")
        }

        guard let image = NSImage(data: data) else {
            throw AppError.generationFailed("Invalid upscaled image data")
        }

        return image
    }
}

// MARK: - Request Model

private struct UpscaleRequest: Encodable {
    let input: Input

    struct Input: Encodable {
        let image: String
        let scale: Int
        let faceEnhance: Bool

        enum CodingKeys: String, CodingKey {
            case image
            case scale
            case faceEnhance = "face_enhance"
        }
    }

    init(image: String, scale: Int, faceEnhance: Bool = false) {
        self.input = Input(image: image, scale: scale, faceEnhance: faceEnhance)
    }
}
