import Foundation
import AppKit

// MARK: - Export Service
// Handles exporting images to various platform bundles
// Uses Core Graphics for high-quality resizing

final class ExportService: Sendable {
    private let vectorizationService: VectorizationService

    init(vectorizationService: VectorizationService = VectorizationService()) {
        self.vectorizationService = vectorizationService
    }

    // MARK: - Main Export

    /// Export an image to selected bundles at a destination folder
    /// Returns the URL to the export folder
    @MainActor
    func export(
        image: NSImage,
        to bundles: Set<ExportBundle>,
        destination: URL,
        progress: @escaping (ExportProgress) -> Void
    ) async throws -> URL {
        print("📦 ExportService.export called")
        print("   Image size: \(image.size)")
        print("   Bundles: \(bundles.map { $0.rawValue })")
        print("   Destination: \(destination.path)")

        // Create timestamped export folder
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let folderName = "export-\(formatter.string(from: Date()))"
        let exportURL = destination.appending(path: folderName)

        print("   Export folder: \(exportURL.path)")

        do {
            try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
            print("   ✅ Created export directory")
        } catch {
            print("   ❌ Failed to create directory: \(error)")
            throw error
        }

        // Calculate total work (SVG counts as 1)
        let totalSizes = bundles.reduce(0) { total, bundle in
            total + (bundle == .svg ? 1 : bundle.sizes.count)
        }
        var completed = 0

        // Export each bundle
        for bundle in bundles {
            progress(ExportProgress(
                currentBundle: bundle,
                completed: completed,
                total: totalSizes
            ))

            try await exportBundle(bundle, image: image, to: exportURL) { _ in
                completed += 1
                progress(ExportProgress(
                    currentBundle: bundle,
                    completed: completed,
                    total: totalSizes
                ))
            }
        }

        return exportURL
    }

    // MARK: - Bundle Export

    private func exportBundle(
        _ bundle: ExportBundle,
        image: NSImage,
        to baseURL: URL,
        onSize: (ExportSize) -> Void
    ) async throws {
        print("   📁 exportBundle: \(bundle.rawValue)")
        print("      Base URL: \(baseURL.path)")

        let bundleURL: URL

        switch bundle {
        case .iOS:
            // iOS goes in AppIcon.appiconset folder
            bundleURL = baseURL
                .appending(path: bundle.folderName)
                .appending(path: "AppIcon.appiconset")
            print("      Creating iOS bundle at: \(bundleURL.path)")
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
            print("      ✅ iOS directory created")

            // Write Contents.json
            let contentsJSON = ExportBundle.generateiOSContentsJSON()
            try contentsJSON.write(to: bundleURL.appending(path: "Contents.json"))
            print("      ✅ Contents.json written")

        case .favicon:
            bundleURL = baseURL.appending(path: bundle.folderName)
            print("      Creating favicon bundle at: \(bundleURL.path)")
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
            print("      ✅ Favicon directory created")

            // Write webmanifest
            let manifest = ExportBundle.generateWebManifest()
            try manifest.write(to: bundleURL.appending(path: "site.webmanifest"))
            print("      ✅ site.webmanifest written")

            // Generate favicon.ico (multi-resolution ICO file)
            try generateFaviconICO(from: image, to: bundleURL)
            print("      ✅ favicon.ico generated")

        case .svg:
            // SVG requires AI vectorization - no sizes, just one vector file
            bundleURL = baseURL.appending(path: bundle.folderName)
            print("      Creating SVG bundle at: \(bundleURL.path)")
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
            print("      ✅ SVG directory created")

            // Call vectorization API
            print("      🔄 Calling vectorization API...")
            let svgData = try await vectorizationService.vectorize(image)
            let svgURL = bundleURL.appending(path: "logo.svg")
            try svgData.write(to: svgURL)
            print("      ✅ logo.svg saved (\(svgData.count) bytes)")

            onSize(ExportSize(size: 0, filename: "logo.svg"))
            return  // SVG doesn't have multiple sizes

        default:
            bundleURL = baseURL.appending(path: bundle.folderName)
            print("      Creating bundle at: \(bundleURL.path)")
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
            print("      ✅ Directory created")
        }

        // Export each size (skip for SVG which returns early)
        print("      Exporting \(bundle.sizes.count) sizes...")
        for size in bundle.sizes {
            let outputURL: URL

            if let subfolder = size.subfolder {
                // Android mipmap folders
                let subfolderURL = bundleURL.appending(path: subfolder)
                try FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true)
                outputURL = subfolderURL.appending(path: size.filename)
            } else {
                outputURL = bundleURL.appending(path: size.filename)
            }

            // Resize and save
            let resized = resize(image, to: CGSize(width: size.width, height: size.height))

            // iOS App Store icon must not have alpha channel
            let removeAlpha = bundle == .iOS && size.width == 1024

            try savePNG(resized, to: outputURL, removeAlpha: removeAlpha)
            print("         ✅ \(size.filename) (\(size.width)x\(size.height))")

            onSize(size)
        }
        print("      ✅ Bundle complete: \(bundle.rawValue)")
    }

    // MARK: - Image Resizing

    /// Resize image to exact PIXEL dimensions using Core Graphics
    /// NSImage.size returns points, not pixels - this caused images to be
    /// incorrectly sized on retina displays. We use CGImage for pixel-accurate resizing.
    private func resize(_ image: NSImage, to targetSize: CGSize) -> NSImage {
        // Get the CGImage to work with actual pixels, not points
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("⚠️ Could not get CGImage, falling back to original")
            return image
        }

        let targetWidth = Int(targetSize.width)
        let targetHeight = Int(targetSize.height)

        // Create a bitmap context with exact pixel dimensions
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("⚠️ Could not create CGContext, falling back to original")
            return image
        }

        // Use high-quality interpolation
        context.interpolationQuality = .high

        // Draw the source image scaled to fill the entire target rect
        let targetRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        context.draw(cgImage, in: targetRect)

        // Create NSImage from the rendered context
        guard let resizedCGImage = context.makeImage() else {
            print("⚠️ Could not create resized image, falling back to original")
            return image
        }

        // Create NSImage with explicit pixel dimensions
        // Set size to match pixels so it displays at 1:1 on screen
        let resizedImage = NSImage(cgImage: resizedCGImage, size: targetSize)
        return resizedImage
    }

    // MARK: - PNG Export

    /// Save NSImage as PNG file
    private func savePNG(_ image: NSImage, to url: URL, removeAlpha: Bool = false) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ExportError.imageConversionFailed
        }

        let finalBitmap: NSBitmapImageRep

        if removeAlpha {
            // Create new bitmap without alpha (required for App Store icon)
            finalBitmap = removeAlphaChannel(from: bitmap)
        } else {
            finalBitmap = bitmap
        }

        guard let pngData = finalBitmap.representation(using: .png, properties: [:]) else {
            throw ExportError.imageConversionFailed
        }

        try pngData.write(to: url)
    }

    /// Remove alpha channel by compositing over white background
    private func removeAlphaChannel(from bitmap: NSBitmapImageRep) -> NSBitmapImageRep {
        let size = NSSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        let newImage = NSImage(size: size)

        newImage.lockFocus()

        // Fill with white background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw original image on top
        let rect = NSRect(origin: .zero, size: size)
        bitmap.draw(in: rect, from: rect, operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: nil)

        newImage.unlockFocus()

        guard let tiff = newImage.tiffRepresentation,
              let result = NSBitmapImageRep(data: tiff) else {
            return bitmap  // Fallback to original
        }

        return result
    }

    // MARK: - ICO Generation

    /// Generate multi-resolution favicon.ico
    /// ICO format contains multiple sizes in one file
    private func generateFaviconICO(from image: NSImage, to folder: URL) throws {
        // ICO typically contains 16x16, 32x32, 48x48
        let sizes = [16, 32, 48]
        var iconImages: [Data] = []

        for size in sizes {
            let resized = resize(image, to: CGSize(width: size, height: size))
            guard let tiff = resized.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                continue
            }
            iconImages.append(png)
        }

        // Build ICO file format
        let icoData = buildICOFile(images: iconImages, sizes: sizes)
        try icoData.write(to: folder.appending(path: "favicon.ico"))
    }

    /// Build ICO file from PNG images
    /// ICO format: Header + Directory entries + Image data
    private func buildICOFile(images: [Data], sizes: [Int]) -> Data {
        var data = Data()

        // ICO Header (6 bytes)
        data.append(contentsOf: [0, 0])           // Reserved (must be 0)
        data.append(contentsOf: [1, 0])           // Image type: 1 = ICO
        let count = UInt16(images.count)
        data.append(contentsOf: withUnsafeBytes(of: count.littleEndian) { Array($0) })

        // Calculate offsets
        let headerSize = 6
        let directoryEntrySize = 16
        var offset = headerSize + (directoryEntrySize * images.count)

        // Directory entries (16 bytes each)
        for (index, imageData) in images.enumerated() {
            let size = sizes[index]
            let width = UInt8(size == 256 ? 0 : size)  // 0 means 256
            let height = width

            data.append(width)                    // Width
            data.append(height)                   // Height
            data.append(0)                        // Color palette (0 = no palette)
            data.append(0)                        // Reserved
            data.append(contentsOf: [1, 0])       // Color planes
            data.append(contentsOf: [32, 0])      // Bits per pixel

            let imageSize = UInt32(imageData.count)
            data.append(contentsOf: withUnsafeBytes(of: imageSize.littleEndian) { Array($0) })

            let imageOffset = UInt32(offset)
            data.append(contentsOf: withUnsafeBytes(of: imageOffset.littleEndian) { Array($0) })

            offset += imageData.count
        }

        // Image data (PNG format)
        for imageData in images {
            data.append(imageData)
        }

        return data
    }
}

// MARK: - Export Progress

struct ExportProgress {
    let currentBundle: ExportBundle
    let completed: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var statusText: String {
        "Exporting \(currentBundle.displayName)... (\(completed)/\(total))"
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case imageConversionFailed
    case directoryCreationFailed
    case noImageSelected

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image"
        case .directoryCreationFailed:
            return "Failed to create export directory"
        case .noImageSelected:
            return "No image selected for export"
        }
    }
}
