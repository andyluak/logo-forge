import AppKit
import SwiftUI

// MARK: - Color Extraction Service
/// Extracts dominant colors from images using k-means clustering

final class ColorExtractionService {

    /// Extract dominant colors from an image
    func extract(from image: NSImage, maxColors: Int = 6) -> ColorPalette {
        guard let pixels = getPixels(from: image) else {
            return .empty
        }

        guard !pixels.isEmpty else {
            return .empty
        }

        // Run k-means clustering
        let clusters = kMeansClustering(pixels: pixels, k: maxColors + 2)

        // Filter near-duplicates and sort by coverage
        let filtered = filterSimilarColors(clusters)
        let sorted = filtered.sorted { $0.coverage > $1.coverage }
        let top = Array(sorted.prefix(maxColors))

        return ColorPalette(colors: top)
    }

    // MARK: - Private

    private struct RGB: Hashable {
        let r: Int, g: Int, b: Int

        func distance(to other: RGB) -> Double {
            let dr = Double(r - other.r)
            let dg = Double(g - other.g)
            let db = Double(b - other.b)
            return sqrt(dr*dr + dg*dg + db*db)
        }
    }

    private func getPixels(from image: NSImage) -> [RGB]? {
        // Downsample to 50x50 for speed
        let targetSize = CGSize(width: 50, height: 50)

        guard let tiffData = image.tiffRepresentation,
              let _ = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // Create downsampled image
        let downsampled = NSImage(size: targetSize)
        downsampled.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        downsampled.unlockFocus()

        guard let smallTiff = downsampled.tiffRepresentation,
              let smallBitmap = NSBitmapImageRep(data: smallTiff) else {
            return nil
        }

        var pixels: [RGB] = []

        for y in 0..<Int(targetSize.height) {
            for x in 0..<Int(targetSize.width) {
                if let color = smallBitmap.colorAt(x: x, y: y) {
                    // Skip transparent pixels
                    if color.alphaComponent < 0.5 { continue }

                    let r = Int(color.redComponent * 255)
                    let g = Int(color.greenComponent * 255)
                    let b = Int(color.blueComponent * 255)
                    pixels.append(RGB(r: r, g: g, b: b))
                }
            }
        }

        return pixels
    }

    private func kMeansClustering(pixels: [RGB], k: Int) -> [ExtractedColor] {
        guard !pixels.isEmpty else { return [] }

        // Initialize centroids randomly
        var centroids = Array(pixels.shuffled().prefix(k))

        // Run iterations
        for _ in 0..<10 {
            // Assign pixels to nearest centroid
            var clusters: [[RGB]] = Array(repeating: [], count: k)

            for pixel in pixels {
                var minDist = Double.infinity
                var minIdx = 0

                for (idx, centroid) in centroids.enumerated() {
                    let dist = pixel.distance(to: centroid)
                    if dist < minDist {
                        minDist = dist
                        minIdx = idx
                    }
                }

                clusters[minIdx].append(pixel)
            }

            // Update centroids
            for (idx, cluster) in clusters.enumerated() {
                guard !cluster.isEmpty else { continue }

                let avgR = cluster.map(\.r).reduce(0, +) / cluster.count
                let avgG = cluster.map(\.g).reduce(0, +) / cluster.count
                let avgB = cluster.map(\.b).reduce(0, +) / cluster.count

                centroids[idx] = RGB(r: avgR, g: avgG, b: avgB)
            }
        }

        // Convert to ExtractedColor with coverage
        let total = Double(pixels.count)
        var results: [ExtractedColor] = []

        // Recalculate cluster sizes
        var clusters: [[RGB]] = Array(repeating: [], count: k)
        for pixel in pixels {
            var minDist = Double.infinity
            var minIdx = 0
            for (idx, centroid) in centroids.enumerated() {
                let dist = pixel.distance(to: centroid)
                if dist < minDist {
                    minDist = dist
                    minIdx = idx
                }
            }
            clusters[minIdx].append(pixel)
        }

        for (idx, centroid) in centroids.enumerated() {
            let coverage = Double(clusters[idx].count) / total
            if coverage > 0.01 {  // Skip tiny clusters
                results.append(ExtractedColor(
                    r: centroid.r,
                    g: centroid.g,
                    b: centroid.b,
                    coverage: coverage
                ))
            }
        }

        return results
    }

    private func filterSimilarColors(_ colors: [ExtractedColor]) -> [ExtractedColor] {
        var filtered: [ExtractedColor] = []

        for color in colors {
            let isDuplicate = filtered.contains { existing in
                colorDistance(color, existing) < 30  // Threshold
            }
            if !isDuplicate {
                filtered.append(color)
            }
        }

        return filtered
    }

    private func colorDistance(_ a: ExtractedColor, _ b: ExtractedColor) -> Double {
        // Parse hex to RGB and calculate distance
        let aRGB = hexToRGB(a.hex)
        let bRGB = hexToRGB(b.hex)

        let dr = Double(aRGB.r - bRGB.r)
        let dg = Double(aRGB.g - bRGB.g)
        let db = Double(aRGB.b - bRGB.b)

        return sqrt(dr*dr + dg*dg + db*db)
    }

    private func hexToRGB(_ hex: String) -> (r: Int, g: Int, b: Int) {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgbValue: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgbValue)

        return (
            r: Int((rgbValue & 0xFF0000) >> 16),
            g: Int((rgbValue & 0x00FF00) >> 8),
            b: Int(rgbValue & 0x0000FF)
        )
    }
}
