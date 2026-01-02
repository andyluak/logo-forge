import Foundation
import AppKit

// MARK: - Inpainting Service
/// Handles AI-powered inpainting using Replicate's Flux Fill Pro
/// Takes source image + mask + prompt → returns modified image

protocol InpaintingServiceProtocol: Sendable {
    func inpaint(
        image: NSImage,
        mask: NSImage,
        prompt: String,
        model: AIModel
    ) async throws -> NSImage
}

final class InpaintingService: InpaintingServiceProtocol, Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let keychainService: KeychainService

    /// Polling interval for checking prediction status
    private let pollInterval: Duration = .seconds(2)

    /// Maximum time to wait for inpainting to complete
    private let maxWaitTime: Duration = .seconds(120)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    // MARK: - Public API

    /// Inpaint a region of the image based on the mask
    /// - Parameters:
    ///   - image: Source image to modify
    ///   - mask: Binary mask (white = areas to inpaint, black = keep)
    ///   - prompt: Description of what to generate in masked area
    ///   - model: AI model to use (must support inpainting)
    func inpaint(
        image: NSImage,
        mask: NSImage,
        prompt: String,
        model: AIModel = .fluxFillPro
    ) async throws -> NSImage {
        guard model.supportsInpainting else {
            throw AppError.generationFailed("Model \(model.rawValue) does not support inpainting")
        }

        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        // Convert images to base64 data URIs
        guard let imageData = image.pngData(),
              let maskData = mask.pngData() else {
            throw AppError.generationFailed("Failed to encode images")
        }

        let imageBase64 = "data:image/png;base64," + imageData.base64EncodedString()
        let maskBase64 = "data:image/png;base64," + maskData.base64EncodedString()

        // Create prediction
        let predictionID = try await createPrediction(
            image: imageBase64,
            mask: maskBase64,
            prompt: prompt,
            model: model,
            apiKey: apiKey
        )

        // Poll for completion
        let outputURL = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Download result
        let result = try await downloadImage(from: outputURL)

        return result
    }

    // MARK: - Private

    private func createPrediction(
        image: String,
        mask: String,
        prompt: String,
        model: AIModel,
        apiKey: String
    ) async throws -> String {
        let url = baseURL.appending(path: "models/\(model.replicateModel)/predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = InpaintRequest(image: image, mask: mask, prompt: prompt, model: model)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        // Debug logging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🎨 Inpaint Response (\(httpResponse.statusCode)): \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let prediction = try JSONDecoder().decode(InpaintPrediction.self, from: data)
            return prediction.id

        case 401:
            throw AppError.invalidAPIKey

        case 429:
            throw AppError.rateLimited(retryAfter: 30)

        case 422:
            if let responseString = String(data: data, encoding: .utf8) {
                throw AppError.generationFailed("Invalid input: \(responseString)")
            }
            throw AppError.generationFailed("Invalid input parameters")

        default:
            if let responseString = String(data: data, encoding: .utf8) {
                throw AppError.generationFailed("HTTP \(httpResponse.statusCode): \(responseString)")
            }
            throw AppError.generationFailed("HTTP \(httpResponse.statusCode)")
        }
    }

    private func pollForCompletion(predictionID: String, apiKey: String) async throws -> URL {
        let url = baseURL.appending(path: "predictions/\(predictionID)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let startTime = Date()

        while true {
            if Date().timeIntervalSince(startTime) > Double(maxWaitTime.components.seconds) {
                throw AppError.generationFailed("Inpainting timed out")
            }

            try await Task.sleep(for: pollInterval)

            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(InpaintPrediction.self, from: data)

            switch prediction.status {
            case "succeeded":
                // Flux Fill Pro returns a single URL string
                guard let urlString = prediction.output,
                      let url = URL(string: urlString) else {
                    throw AppError.generationFailed("No output URL in response")
                }
                return url

            case "failed":
                let errorMessage = prediction.error ?? "Unknown error"
                if errorMessage.lowercased().contains("safety") || errorMessage.lowercased().contains("filter") {
                    throw AppError.contentFiltered
                }
                throw AppError.generationFailed(errorMessage)

            case "canceled":
                throw AppError.generationFailed("Inpainting was canceled")

            default:
                // starting, processing - continue polling
                continue
            }
        }
    }

    private func downloadImage(from url: URL) async throws -> NSImage {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppError.generationFailed("Failed to download inpainted image")
        }

        guard let image = NSImage(data: data) else {
            throw AppError.generationFailed("Invalid image data")
        }

        return image
    }
}

// MARK: - Request Model

private struct InpaintRequest: Encodable {
    let input: InputParams

    struct InputParams: Encodable {
        let image: String
        let mask: String
        let prompt: String
        let outputFormat: String
        let guidanceScale: Double
        let numInferenceSteps: Int
        let strength: Double

        enum CodingKeys: String, CodingKey {
            case image
            case mask
            case prompt
            case outputFormat = "output_format"
            case guidanceScale = "guidance_scale"
            case numInferenceSteps = "num_inference_steps"
            case strength
        }
    }

    init(image: String, mask: String, prompt: String, model: AIModel) {
        switch model {
        case .fluxFillPro:
            self.input = InputParams(
                image: image,
                mask: mask,
                prompt: prompt,
                outputFormat: "png",
                guidanceScale: 30,
                numInferenceSteps: 50,
                strength: 1.0
            )
        case .ideogramV3:
            // Ideogram uses different inpainting params
            self.input = InputParams(
                image: image,
                mask: mask,
                prompt: prompt,
                outputFormat: "png",
                guidanceScale: 7.5,
                numInferenceSteps: 30,
                strength: 0.8
            )
        default:
            // Default fallback
            self.input = InputParams(
                image: image,
                mask: mask,
                prompt: prompt,
                outputFormat: "png",
                guidanceScale: 7.5,
                numInferenceSteps: 30,
                strength: 0.8
            )
        }
    }
}

// MARK: - Response Model

private struct InpaintPrediction: Decodable {
    let id: String
    let status: String
    let output: String?
    let error: String?
}

// MARK: - NSImage Extension

extension NSImage {
    /// Convert NSImage to PNG data
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }

    /// Get actual pixel dimensions (not points)
    var pixelSize: CGSize? {
        guard let tiffData = tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return CGSize(width: bitmapRep.pixelsWide, height: bitmapRep.pixelsHigh)
    }
}
