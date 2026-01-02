import Foundation
import AppKit

// MARK: - Protocol

protocol BackgroundRemovalServiceProtocol: Sendable {
    func removeBackground(from image: NSImage) async throws -> NSImage
    var costPerImage: Decimal { get }
}

// MARK: - Implementation

final class BackgroundRemovalService: BackgroundRemovalServiceProtocol, Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let modelVersion = "95fcc2a26d3899cd6c2691c900465aaeff466285a65c14638cc5f36f34befaf1"
    private let keychainService: KeychainService

    let costPerImage: Decimal = 0.01

    /// How often to check if removal is complete (seconds)
    private let pollInterval: Duration = .seconds(1)

    /// Maximum time to wait (seconds)
    private let maxWaitTime: Duration = .seconds(60)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    // MARK: - Public API

    /// Remove background from an image, returning a transparent PNG
    func removeBackground(from image: NSImage) async throws -> NSImage {
        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        // Convert NSImage to base64 PNG
        guard let imageData = imageToBase64PNG(image) else {
            throw AppError.generationFailed("Failed to encode image")
        }

        // Create prediction
        let predictionID = try await createPrediction(imageData: imageData, apiKey: apiKey)

        // Poll for completion
        let imageURL = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Download the result
        let resultImage = try await downloadImage(from: imageURL)

        return resultImage
    }

    // MARK: - Private: Image Encoding

    private func imageToBase64PNG(_ image: NSImage) -> String? {
        // Resize to stay under 256KB data URL limit (~192KB base64 encoded)
        // 512px max dimension with JPEG compression keeps us under
        let resizedImage = resizeIfNeeded(image, maxDimension: 512)

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // Use JPEG for smaller size (we just need subject detection, output will be PNG)
        guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return nil
        }

        print("🔵 Remove-bg Image size: \(jpegData.count) bytes (\(jpegData.count / 1024)KB)")

        return "data:image/jpeg;base64," + jpegData.base64EncodedString()
    }

    private func resizeIfNeeded(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(
                  data: nil,
                  width: Int(newSize.width),
                  height: Int(newSize.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))

        guard let resizedCGImage = context.makeImage() else {
            return image
        }

        return NSImage(cgImage: resizedCGImage, size: newSize)
    }

    // MARK: - Private: API Calls

    private func createPrediction(imageData: String, apiKey: String) async throws -> String {
        // Use /predictions endpoint with version hash (not /models/{model}/predictions)
        let url = baseURL.appending(path: "predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RemoveBackgroundRequest(version: modelVersion, image: imageData)
        let encodedBody = try JSONEncoder().encode(body)

        // Debug: log request size
        print("🔵 Remove-bg Request size: \(encodedBody.count) bytes")

        request.httpBody = encodedBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        // Debug logging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔵 Remove-bg Response (\(httpResponse.statusCode)): \(responseString)")
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)
            return prediction.id

        case 401:
            throw AppError.invalidAPIKey

        case 422:
            // Validation error - likely image too large for data URL
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            if responseString.contains("too large") || responseString.contains("256") {
                throw AppError.generationFailed("Image too large. Try with a smaller image.")
            }
            throw AppError.generationFailed("Invalid request: \(responseString)")

        case 429:
            throw AppError.rateLimited(retryAfter: 30)

        default:
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.generationFailed("Background removal failed (\(httpResponse.statusCode)): \(responseString)")
        }
    }

    private func pollForCompletion(predictionID: String, apiKey: String) async throws -> URL {
        let url = baseURL.appending(path: "predictions/\(predictionID)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let startTime = Date()

        while true {
            if Date().timeIntervalSince(startTime) > Double(maxWaitTime.components.seconds) {
                throw AppError.generationFailed("Background removal timed out")
            }

            try await Task.sleep(for: pollInterval)

            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)

            switch prediction.status {
            case .succeeded:
                guard let urlString = prediction.output,
                      let url = URL(string: urlString) else {
                    throw AppError.generationFailed("No output URL from background removal")
                }
                return url

            case .failed:
                throw AppError.generationFailed(prediction.error ?? "Background removal failed")

            case .canceled:
                throw AppError.generationFailed("Background removal was canceled")

            case .starting, .processing:
                continue
            }
        }
    }

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

// MARK: - Request Model

private struct RemoveBackgroundRequest: Encodable {
    let version: String
    let input: Input

    struct Input: Encodable {
        let image: String
    }

    init(version: String, image: String) {
        self.version = version
        self.input = Input(image: image)
    }
}
