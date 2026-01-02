import Foundation

// MARK: - Export Options
// User preferences for export behavior

@Observable
final class ExportOptions {
    /// Which bundles to export
    var selectedBundles: Set<ExportBundle> = [.iOS, .android]

    /// Whether to upscale before export
    var upscaleMode: UpscaleMode = .off

    /// Whether to generate dark/transparent variants
    var generateVariants: Bool = false

    /// Estimated cost based on current selections
    var estimatedCost: Decimal {
        var cost: Decimal = 0

        if upscaleMode != .off {
            cost += 0.02  // Upscaling cost
        }

        if selectedBundles.contains(.svg) {
            cost += 0.01  // Vectorization cost
        }

        return cost
    }

    /// Reset to defaults
    func reset() {
        selectedBundles = [.iOS, .android]
        upscaleMode = .off
        generateVariants = false
    }
}

// MARK: - Upscale Mode

enum UpscaleMode: String, CaseIterable, Identifiable {
    case off = "None"
    case smart = "Smart (when needed)"
    case always = "Always enhance"

    var id: String { rawValue }

    /// Description for UI
    var description: String {
        switch self {
        case .off:
            return "Export at original resolution"
        case .smart:
            return "Upscale only if source is smaller than target"
        case .always:
            return "Always upscale to 4x before resizing"
        }
    }
}
