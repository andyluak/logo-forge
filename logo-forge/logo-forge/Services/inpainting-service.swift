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
        model: AIModel,
        preserveTransparency: Bool
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
    ///   - preserveTransparency: If true, preserves original alpha channel outside masked areas
    func inpaint(
        image: NSImage,
        mask: NSImage,
        prompt: String,
        model: AIModel = .ideogramV3,  // Better for logos/cartoons than Flux
        preserveTransparency: Bool = true
    ) async throws -> NSImage {
        guard model.supportsInpainting else {
            throw AppError.generationFailed("Model \(model.rawValue) does not support inpainting")
        }

        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        // Convert images to base64 data URIs
        guard let imageData = image.pngData() else {
            throw AppError.generationFailed("Failed to encode image")
        }

        // Create binary mask PNG with model-specific conventions
        // Ideogram: black = inpaint, white = keep (inverted from our convention)
        // Flux/Bria: white = inpaint, black = keep (same as our convention)
        let maskData: Data
        switch model {
        case .ideogramV3:
            guard let data = createBinaryMaskPNG(from: mask, invert: true) else {
                throw AppError.generationFailed("Failed to encode mask")
            }
            maskData = data
        case .briaEraser, .fluxFillPro:
            // Bria and Flux use same convention as us, but still binarize for clean mask
            guard let data = createBinaryMaskPNG(from: mask, invert: false) else {
                throw AppError.generationFailed("Failed to encode mask")
            }
            maskData = data
        default:
            guard let data = mask.pngData() else {
                throw AppError.generationFailed("Failed to encode mask")
            }
            maskData = data
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
        var result = try await downloadImage(from: outputURL)

        // Preserve original transparency if requested
        if preserveTransparency && image.hasTransparency {
            result = compositePreservingTransparency(
                original: image,
                inpainted: result,
                mask: mask
            )
        }

        return result
    }

    /// Create a strict binary mask PNG directly from the source mask
    /// Returns PNG data with only pure black (0,0,0) and white (255,255,255) pixels
    /// - Parameters:
    ///   - mask: Source mask image
    ///   - invert: If true, inverts the mask (for Ideogram: our white -> their black)
    private func createBinaryMaskPNG(from mask: NSImage, invert: Bool) -> Data? {
        guard let maskSize = mask.pixelSize,
              let maskBitmap = NSBitmapImageRep(data: mask.tiffRepresentation ?? Data()) else {
            return nil
        }

        let width = Int(maskSize.width)
        let height = Int(maskSize.height)
        let bytesPerRow = width * 3  // RGB = 3 bytes per pixel

        guard let resultBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 3,  // RGB only, no alpha
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: bytesPerRow,
            bitsPerPixel: 24
        ),
        let bitmapData = resultBitmap.bitmapData else {
            return nil
        }

        // Direct byte manipulation for guaranteed 0/255 values
        for y in 0..<height {
            for x in 0..<width {
                // Get brightness value, handling color space conversion
                let brightness: CGFloat
                if let color = maskBitmap.colorAt(x: x, y: y) {
                    // Convert to device RGB to ensure correct component reading
                    if let rgbColor = color.usingColorSpace(.deviceRGB) {
                        brightness = rgbColor.redComponent
                    } else {
                        // Fallback: use brightness which works across color spaces
                        brightness = color.brightnessComponent
                    }
                } else {
                    brightness = 0
                }

                // Threshold at 0.5: anything > 0.5 is "painted" area in our convention
                let isPaintedArea = brightness > 0.5

                // Determine output: invert swaps black/white
                // Our convention: white = inpaint, black = keep
                // Ideogram convention: black = inpaint, white = keep
                let byteValue: UInt8
                if invert {
                    byteValue = isPaintedArea ? 0 : 255  // painted -> black (inpaint)
                } else {
                    byteValue = isPaintedArea ? 255 : 0  // painted -> white (inpaint)
                }

                let pixelOffset = y * bytesPerRow + x * 3
                bitmapData[pixelOffset] = byteValue      // R
                bitmapData[pixelOffset + 1] = byteValue  // G
                bitmapData[pixelOffset + 2] = byteValue  // B
            }
        }

        // Encode directly to PNG without going through NSImage/TIFF
        return resultBitmap.representation(using: .png, properties: [:])
    }

    /// Composite inpainted result with original, preserving transparency
    /// - Where mask is white: use inpainted RGB, keep original alpha
    /// - Where mask is black: use original pixel entirely (including alpha)
    private func compositePreservingTransparency(
        original: NSImage,
        inpainted: NSImage,
        mask: NSImage
    ) -> NSImage {
        guard let originalSize = original.pixelSize else { return inpainted }

        let width = Int(originalSize.width)
        let height = Int(originalSize.height)

        // Get bitmap representations
        guard let originalBitmap = NSBitmapImageRep(data: original.tiffRepresentation ?? Data()),
              let inpaintedBitmap = NSBitmapImageRep(data: inpainted.tiffRepresentation ?? Data()),
              let maskBitmap = NSBitmapImageRep(data: mask.tiffRepresentation ?? Data()) else {
            return inpainted
        }

        // Create output bitmap
        guard let resultBitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return inpainted
        }

        // Per-pixel compositing
        for y in 0..<height {
            for x in 0..<width {
                // Get mask value (0 = keep original, 1 = use inpainted)
                let maskColor = maskBitmap.colorAt(x: x, y: y) ?? .black
                let maskValue = maskColor.redComponent

                let originalColor = originalBitmap.colorAt(x: x, y: y) ?? .clear

                // Scale inpainted coordinates if sizes differ
                let inpaintX = x * inpaintedBitmap.pixelsWide / width
                let inpaintY = y * inpaintedBitmap.pixelsHigh / height
                let inpaintedColor = inpaintedBitmap.colorAt(x: inpaintX, y: inpaintY) ?? .clear

                let resultColor: NSColor
                if maskValue > 0.5 {
                    // Mask is white: use inpainted RGB but preserve original alpha
                    resultColor = NSColor(
                        red: inpaintedColor.redComponent,
                        green: inpaintedColor.greenComponent,
                        blue: inpaintedColor.blueComponent,
                        alpha: originalColor.alphaComponent
                    )
                } else {
                    // Mask is black: keep original pixel entirely
                    resultColor = originalColor
                }

                resultBitmap.setColor(resultColor, atX: x, y: y)
            }
        }

        let result = NSImage(size: originalSize)
        result.addRepresentation(resultBitmap)
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
        // Bria Eraser uses version-based endpoint
        let url: URL
        if model == .briaEraser {
            url = baseURL.appending(path: "predictions")
        } else {
            url = baseURL.appending(path: "models/\(model.replicateModel)/predictions")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Use model-specific request format
        let bodyData: Data
        switch model {
        case .fluxFillPro:
            let body = FluxFillProRequest(image: image, mask: mask, prompt: prompt)
            bodyData = try JSONEncoder().encode(body)
        case .ideogramV3:
            let body = IdeogramInpaintRequest(image: image, mask: mask, prompt: prompt)
            bodyData = try JSONEncoder().encode(body)
        case .briaEraser:
            let body = BriaEraserRequest(image: image, mask: mask)
            bodyData = try JSONEncoder().encode(body)
        default:
            let body = IdeogramInpaintRequest(image: image, mask: mask, prompt: prompt)
            bodyData = try JSONEncoder().encode(body)
        }
        request.httpBody = bodyData

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

// MARK: - Request Models

/// Flux Fill Pro request - uses different parameter names
private struct FluxFillProRequest: Encodable {
    let input: InputParams

    struct InputParams: Encodable {
        let image: String
        let mask: String
        let prompt: String
        let steps: Int
        let guidance: Double
        let outputFormat: String

        enum CodingKeys: String, CodingKey {
            case image
            case mask
            case prompt
            case steps
            case guidance
            case outputFormat = "output_format"
        }
    }

    init(image: String, mask: String, prompt: String) {
        self.input = InputParams(
            image: image,
            mask: mask,
            prompt: prompt,
            steps: 50,           // Max quality
            guidance: 15,        // Lower = more context-aware, less prompt-literal
            outputFormat: "png"  // Preserve transparency
        )
    }
}

/// Ideogram V3 inpaint request - optimized for logos/design
private struct IdeogramInpaintRequest: Encodable {
    let input: InputParams

    struct InputParams: Encodable {
        let image: String
        let mask: String
        let prompt: String
        let styleType: String
        let aspectRatio: String
        let magicPromptOption: String

        enum CodingKeys: String, CodingKey {
            case image
            case mask
            case prompt
            case styleType = "style_type"
            case aspectRatio = "aspect_ratio"
            case magicPromptOption = "magic_prompt_option"
        }
    }

    init(image: String, mask: String, prompt: String) {
        self.input = InputParams(
            image: image,
            mask: mask,
            prompt: prompt,
            styleType: "Design",       // Best for logos
            aspectRatio: "1:1",
            magicPromptOption: "Off"   // Keep prompt as-is for precise control
        )
    }
}

/// Bria Eraser request - no prompt needed, just removes masked area
private struct BriaEraserRequest: Encodable {
    let version: String
    let input: InputParams

    struct InputParams: Encodable {
        let image: String
        let mask: String
        let maskType: String
        let preserveAlpha: Bool

        enum CodingKeys: String, CodingKey {
            case image
            case mask
            case maskType = "mask_type"
            case preserveAlpha = "preserve_alpha"
        }
    }

    init(image: String, mask: String) {
        self.version = "893e924eecc119a0c5fbfa5d98401118dcbf0662574eb8d2c01be5749756cbd4"
        self.input = InputParams(
            image: image,
            mask: mask,
            maskType: "manual",
            preserveAlpha: true
        )
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

    /// Check if image has any transparent pixels
    var hasTransparency: Bool {
        guard let tiffData = tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return false
        }

        // Check if the image format supports alpha
        guard bitmapRep.hasAlpha else { return false }

        // Sample some pixels to check for actual transparency
        let width = bitmapRep.pixelsWide
        let height = bitmapRep.pixelsHigh

        // Check corners and center for transparency
        let samplePoints = [
            (0, 0), (width - 1, 0),
            (0, height - 1), (width - 1, height - 1),
            (width / 2, height / 2)
        ]

        for (x, y) in samplePoints {
            if let color = bitmapRep.colorAt(x: x, y: y),
               color.alphaComponent < 1.0 {
                return true
            }
        }

        return false
    }
}
