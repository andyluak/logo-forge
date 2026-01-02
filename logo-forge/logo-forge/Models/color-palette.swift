import SwiftUI

struct ExtractedColor: Identifiable, Hashable {
    let id: UUID
    let hex: String       // "#FF5733"
    let color: Color      // SwiftUI Color
    let coverage: Double  // 0.0 - 1.0

    init(r: Int, g: Int, b: Int, coverage: Double) {
        self.id = UUID()
        self.hex = String(format: "#%02X%02X%02X", r, g, b)
        self.color = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
        self.coverage = coverage
    }
}

struct ColorPalette: Identifiable {
    let id: UUID
    let colors: [ExtractedColor]
    let extractedAt: Date

    init(colors: [ExtractedColor]) {
        self.id = UUID()
        self.colors = colors
        self.extractedAt = Date()
    }

    static let empty = ColorPalette(colors: [])
}
