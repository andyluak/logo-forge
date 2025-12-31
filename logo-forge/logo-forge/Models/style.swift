import Foundation

enum Style: String, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case bold = "Bold"
    case tech = "Tech"
    case vintage = "Vintage"
    case playful = "Playful"
    case elegant = "Elegant"
    case custom = "Custom"

    var id: String { rawValue }

    var promptSuffix: String {
        switch self {
        case .minimal:
            return "minimal flat design, clean lines, simple shapes, modern"
        case .bold:
            return "bold graphic design, strong contrast, impactful, striking"
        case .tech:
            return "technology style, futuristic, digital, sleek, innovative"
        case .vintage:
            return "vintage retro style, classic, nostalgic, timeless"
        case .playful:
            return "playful fun design, colorful, friendly, approachable"
        case .elegant:
            return "elegant sophisticated design, luxurious, refined, premium"
        case .custom:
            return ""
        }
    }

    var thumbnailName: String {
        "style-\(rawValue.lowercased())"
    }
}
