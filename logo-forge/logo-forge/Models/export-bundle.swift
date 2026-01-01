import Foundation

// MARK: - Export Bundle
// Defines what sizes and formats to export for each platform
// Each bundle knows its own file structure and naming conventions

enum ExportBundle: String, CaseIterable, Identifiable {
    case iOS
    case android
    case favicon

    var id: String { rawValue }

    /// Human-readable name
    var displayName: String {
        switch self {
        case .iOS: return "iOS App Icon"
        case .android: return "Android Launcher"
        case .favicon: return "Favicon"
        }
    }

    /// SF Symbol for UI
    var iconName: String {
        switch self {
        case .iOS: return "apple.logo"
        case .android: return "rectangle.split.2x2"
        case .favicon: return "globe"
        }
    }

    /// All sizes to export for this bundle
    var sizes: [ExportSize] {
        switch self {
        case .iOS:
            return Self.iOSSizes
        case .android:
            return Self.androidSizes
        case .favicon:
            return Self.faviconSizes
        }
    }

    /// Output folder name
    var folderName: String {
        switch self {
        case .iOS: return "ios"
        case .android: return "android"
        case .favicon: return "favicon"
        }
    }
}

// MARK: - Export Size
// Represents a single output image with size and filename

struct ExportSize {
    let width: Int
    let height: Int
    let filename: String
    let subfolder: String?  // For Android mipmap folders

    /// Square size convenience initializer
    init(size: Int, filename: String, subfolder: String? = nil) {
        self.width = size
        self.height = size
        self.filename = filename
        self.subfolder = subfolder
    }

    /// Non-square size initializer
    init(width: Int, height: Int, filename: String, subfolder: String? = nil) {
        self.width = width
        self.height = height
        self.filename = filename
        self.subfolder = subfolder
    }
}

// MARK: - Size Definitions

extension ExportBundle {

    // MARK: iOS Sizes
    // Apple requires specific sizes for different devices and contexts
    // @2x and @3x variants for retina displays

    static let iOSSizes: [ExportSize] = [
        // iPhone Notification (20pt)
        ExportSize(size: 40, filename: "icon-20@2x.png"),
        ExportSize(size: 60, filename: "icon-20@3x.png"),

        // iPhone Settings (29pt)
        ExportSize(size: 58, filename: "icon-29@2x.png"),
        ExportSize(size: 87, filename: "icon-29@3x.png"),

        // iPhone Spotlight (40pt)
        ExportSize(size: 80, filename: "icon-40@2x.png"),
        ExportSize(size: 120, filename: "icon-40@3x.png"),

        // iPhone App (60pt)
        ExportSize(size: 120, filename: "icon-60@2x.png"),
        ExportSize(size: 180, filename: "icon-60@3x.png"),

        // iPad Notifications (20pt)
        ExportSize(size: 20, filename: "icon-20.png"),
        ExportSize(size: 40, filename: "icon-20@2x-ipad.png"),

        // iPad Settings (29pt)
        ExportSize(size: 29, filename: "icon-29.png"),
        ExportSize(size: 58, filename: "icon-29@2x-ipad.png"),

        // iPad Spotlight (40pt)
        ExportSize(size: 40, filename: "icon-40.png"),
        ExportSize(size: 80, filename: "icon-40@2x-ipad.png"),

        // iPad App (76pt)
        ExportSize(size: 76, filename: "icon-76.png"),
        ExportSize(size: 152, filename: "icon-76@2x.png"),

        // iPad Pro App (83.5pt)
        ExportSize(size: 167, filename: "icon-83.5@2x.png"),

        // App Store (1024pt, no alpha!)
        ExportSize(size: 1024, filename: "icon-1024.png"),
    ]

    // MARK: Android Sizes
    // Android uses density buckets (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
    // Each density goes in its own mipmap folder

    static let androidSizes: [ExportSize] = [
        // Launcher icons by density
        ExportSize(size: 48, filename: "ic_launcher.png", subfolder: "mipmap-mdpi"),
        ExportSize(size: 72, filename: "ic_launcher.png", subfolder: "mipmap-hdpi"),
        ExportSize(size: 96, filename: "ic_launcher.png", subfolder: "mipmap-xhdpi"),
        ExportSize(size: 144, filename: "ic_launcher.png", subfolder: "mipmap-xxhdpi"),
        ExportSize(size: 192, filename: "ic_launcher.png", subfolder: "mipmap-xxxhdpi"),

        // Play Store icon (512x512)
        ExportSize(size: 512, filename: "playstore-icon.png"),
    ]

    // MARK: Favicon Sizes
    // Web favicons need multiple sizes for different contexts
    // Plus an .ico file (generated separately) and webmanifest

    static let faviconSizes: [ExportSize] = [
        ExportSize(size: 16, filename: "favicon-16x16.png"),
        ExportSize(size: 32, filename: "favicon-32x32.png"),
        ExportSize(size: 48, filename: "favicon-48x48.png"),

        // Apple touch icon
        ExportSize(size: 180, filename: "apple-touch-icon.png"),

        // Android Chrome
        ExportSize(size: 192, filename: "android-chrome-192x192.png"),
        ExportSize(size: 512, filename: "android-chrome-512x512.png"),
    ]

}

// MARK: - iOS Contents.json
// Xcode requires a Contents.json manifest for the AppIcon.appiconset

extension ExportBundle {

    /// Generate Contents.json for iOS AppIcon.appiconset
    static func generateiOSContentsJSON() -> Data {
        let contents: [String: Any] = [
            "images": [
                // iPhone
                ["size": "20x20", "idiom": "iphone", "scale": "2x", "filename": "icon-20@2x.png"],
                ["size": "20x20", "idiom": "iphone", "scale": "3x", "filename": "icon-20@3x.png"],
                ["size": "29x29", "idiom": "iphone", "scale": "2x", "filename": "icon-29@2x.png"],
                ["size": "29x29", "idiom": "iphone", "scale": "3x", "filename": "icon-29@3x.png"],
                ["size": "40x40", "idiom": "iphone", "scale": "2x", "filename": "icon-40@2x.png"],
                ["size": "40x40", "idiom": "iphone", "scale": "3x", "filename": "icon-40@3x.png"],
                ["size": "60x60", "idiom": "iphone", "scale": "2x", "filename": "icon-60@2x.png"],
                ["size": "60x60", "idiom": "iphone", "scale": "3x", "filename": "icon-60@3x.png"],

                // iPad
                ["size": "20x20", "idiom": "ipad", "scale": "1x", "filename": "icon-20.png"],
                ["size": "20x20", "idiom": "ipad", "scale": "2x", "filename": "icon-20@2x-ipad.png"],
                ["size": "29x29", "idiom": "ipad", "scale": "1x", "filename": "icon-29.png"],
                ["size": "29x29", "idiom": "ipad", "scale": "2x", "filename": "icon-29@2x-ipad.png"],
                ["size": "40x40", "idiom": "ipad", "scale": "1x", "filename": "icon-40.png"],
                ["size": "40x40", "idiom": "ipad", "scale": "2x", "filename": "icon-40@2x-ipad.png"],
                ["size": "76x76", "idiom": "ipad", "scale": "1x", "filename": "icon-76.png"],
                ["size": "76x76", "idiom": "ipad", "scale": "2x", "filename": "icon-76@2x.png"],
                ["size": "83.5x83.5", "idiom": "ipad", "scale": "2x", "filename": "icon-83.5@2x.png"],

                // App Store
                ["size": "1024x1024", "idiom": "ios-marketing", "scale": "1x", "filename": "icon-1024.png"],
            ],
            "info": [
                "version": 1,
                "author": "Logo Forge"
            ]
        ]

        return try! JSONSerialization.data(withJSONObject: contents, options: .prettyPrinted)
    }

    /// Generate site.webmanifest for favicons
    static func generateWebManifest() -> Data {
        let manifest = """
        {
            "name": "",
            "short_name": "",
            "icons": [
                {
                    "src": "/android-chrome-192x192.png",
                    "sizes": "192x192",
                    "type": "image/png"
                },
                {
                    "src": "/android-chrome-512x512.png",
                    "sizes": "512x512",
                    "type": "image/png"
                }
            ],
            "theme_color": "#ffffff",
            "background_color": "#ffffff",
            "display": "standalone"
        }
        """
        return manifest.data(using: .utf8)!
    }
}
