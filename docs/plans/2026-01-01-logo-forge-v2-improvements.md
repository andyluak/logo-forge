# Logo Forge v2 - Improvements Plan

> Professional output quality + enhanced AI capabilities

**Date:** 2026-01-01
**Status:** Draft
**Builds on:** [Original Design](./2025-12-31-logo-forge-design.md)

---

## Summary

This plan adds professional-grade features to the existing Logo Forge implementation:

1. **Dual AI Models** - Add Ideogram v3 for text-heavy logos
2. **AI Upscaling** - 4x enhancement via Real-ESRGAN
3. **Vector SVG Export** - AI-powered vectorization
4. **Social Media Bundle** - Twitter, LinkedIn, Facebook, YouTube sizes
5. **UI Refresh** - Studio/Atelier aesthetic with hero-focused layout

---

## Current State (What Exists)

| Component | Status |
|-----------|--------|
| ReplicateService | Nano Banana Pro only |
| ExportService | iOS, Android, Favicon bundles |
| ExportBundle | No SVG, no Social |
| UI | VariationsGrid layout |

---

## New Features

### 1. Dual AI Models

**Goal:** Let users choose Ideogram v3 (best for text) or Nano Banana Pro (best for abstract).

```swift
// New file: Models/ai-model.swift
enum AIModel: String, CaseIterable, Identifiable {
    case ideogramV3 = "Ideogram v3"
    case nanaBananaPro = "Nano Banana Pro"

    var id: String { rawValue }

    var replicateModel: String {
        switch self {
        case .ideogramV3: return "ideogram-ai/ideogram-v3"
        case .nanaBananaPro: return "google/nano-banana-pro"
        }
    }

    var costPerImage: Decimal {
        switch self {
        case .ideogramV3: return 0.08
        case .nanaBananaPro: return 0.15
        }
    }

    var description: String {
        switch self {
        case .ideogramV3: return "Best for logos with text/typography"
        case .nanaBananaPro: return "Best for abstract, artistic logos"
        }
    }
}
```

**Changes required:**
- [ ] Create `Models/ai-model.swift`
- [ ] Update `ReplicateService.generate()` to accept `AIModel` parameter
- [ ] Update `ReplicateCreateRequest` to use dynamic model path
- [ ] Add `ModelToggle` component to `PromptBar`
- [ ] Store selected model in `GenerationState`
- [ ] Persist model choice in `Project`

---

### 2. AI Upscaling Service

**Goal:** Enhance images to 4x resolution before export using Real-ESRGAN.

```swift
// New file: Services/upscaling-service.swift
protocol UpscalingServiceProtocol: Sendable {
    func upscale(_ image: NSImage, factor: Int) async throws -> NSImage
    var costPerImage: Decimal { get }
}

final class UpscalingService: UpscalingServiceProtocol, Sendable {
    private let replicateModel = "nightmareai/real-esrgan"
    let costPerImage: Decimal = 0.02

    func upscale(_ image: NSImage, factor: Int = 4) async throws -> NSImage {
        // 1. Convert NSImage to base64 PNG
        // 2. POST to Replicate with model + scale factor
        // 3. Poll for completion
        // 4. Download and return upscaled image
    }
}
```

**Changes required:**
- [ ] Create `Services/upscaling-service.swift`
- [ ] Add `UpscaleMode` enum to `Models/`
- [ ] Add upscaling option to `ExportSheet`
- [ ] Integrate into export pipeline (before resize)
- [ ] Add to environment keys

---

### 3. Vectorization Service

**Goal:** Convert raster logos to clean SVG via Vectorizer AI.

```swift
// New file: Services/vectorization-service.swift
protocol VectorizationServiceProtocol: Sendable {
    func vectorize(_ image: NSImage) async throws -> Data  // SVG data
    var costPerImage: Decimal { get }
}

final class VectorizationService: VectorizationServiceProtocol, Sendable {
    private let replicateModel = "vectorizer-ai/vectorizer"
    let costPerImage: Decimal = 0.05

    func vectorize(_ image: NSImage) async throws -> Data {
        // 1. Convert NSImage to base64 PNG
        // 2. POST to Replicate vectorizer
        // 3. Poll for completion
        // 4. Return SVG data
    }
}
```

**Changes required:**
- [ ] Create `Services/vectorization-service.swift`
- [ ] Add `.svg` case to `ExportBundle`
- [ ] Generate dark/transparent SVG variants
- [ ] Integrate into export pipeline
- [ ] Add to environment keys

---

### 4. Social Media Bundle

**Goal:** Export sizes optimized for social platforms.

```swift
// Add to ExportBundle
case social

static let socialSizes: [ExportSize] = [
    ExportSize(size: 400, filename: "twitter.png"),      // Twitter profile
    ExportSize(size: 300, filename: "linkedin.png"),     // LinkedIn profile
    ExportSize(size: 180, filename: "facebook.png"),     // Facebook profile
    ExportSize(size: 800, filename: "youtube.png"),      // YouTube channel
]
```

**Changes required:**
- [ ] Add `social` case to `ExportBundle`
- [ ] Add `socialSizes` array
- [ ] Update `displayName` and `iconName`
- [ ] Update `folderName`

---

### 5. Export Options State

**Goal:** User controls for upscaling and variants.

```swift
// New file: Models/export-options.swift
@Observable
final class ExportOptions {
    var selectedBundles: Set<ExportBundle> = [.iOS, .android]
    var upscaleMode: UpscaleMode = .smart
    var generateVariants: Bool = true  // light/dark/transparent
}

enum UpscaleMode: String, CaseIterable {
    case off = "None"
    case smart = "Smart (when needed)"
    case always = "Always enhance"
}
```

**Changes required:**
- [ ] Create `Models/export-options.swift`
- [ ] Update `ExportSheet` to use `ExportOptions`
- [ ] Show cost estimate based on selections
- [ ] Add default settings to `AppSettings`

---

### 6. Updated Export Pipeline

```
Selected Variation
      │
      ▼
┌─────────────────┐     ┌─────────────┐
│ Upscale 4x?     │────▶│ Real-ESRGAN │  $0.02
│ (if enabled)    │     └─────────────┘
└─────────────────┘
      │
      ▼
┌─────────────────┐     ┌─────────────┐
│ Vectorize?      │────▶│ Vectorizer  │  $0.05
│ (if SVG bundle) │     └─────────────┘
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Resize to all   │ ← Core Graphics (free)
│ bundle sizes    │
└─────────────────┘
      │
      ▼
Export Bundle (PNG + SVG + variants)
```

**Changes to ExportService:**
- [ ] Accept `ExportOptions` parameter
- [ ] Call `UpscalingService` if enabled
- [ ] Call `VectorizationService` for SVG bundles
- [ ] Generate dark/transparent variants if enabled

---

### 7. UI Refresh

---

## UI Design Specification

### Design Thinking

**Purpose:** Logo generation tool for designers, founders, indie developers who need professional output fast. They care about quality, not gimmicks.

**Tone:** **Studio/Atelier** — Refined, confident, slightly editorial. Think: a designer's private workspace, not a SaaS dashboard. The work is the interface.

**Differentiation:** The logo IS the hero. When viewing variations, it feels like browsing an art gallery, not a file manager. Everything else recedes.

**What makes it unforgettable:** The moment you generate—your logo appears large, centered, commanding attention on a dark canvas with a subtle glow. No competing UI elements.

---

### Color System

```swift
// Utilities/theme.swift

import SwiftUI

enum LogoForgeTheme {
    // MARK: - Core Palette

    /// Deep charcoal - the canvas everything sits on
    static let canvas = Color(hex: "1A1A1A")

    /// Slightly elevated surfaces (sidebar, cards)
    static let surface = Color(hex: "242424")

    /// Warm paper white - primary foreground, CTAs
    static let paper = Color(hex: "FAF8F5")

    /// Muted warm gray - secondary text
    static let paperMuted = Color(hex: "A8A4A0")

    /// Subtle warm accent for borders, dividers
    static let accent = Color(hex: "E8E4DF")

    // MARK: - Semantic Colors

    static let textPrimary = paper
    static let textSecondary = paperMuted
    static let selected = Color(hex: "3D3D3D")
    static let hover = Color(hex: "2A2A2A")
    static let border = Color(hex: "333333")

    // MARK: - Status Colors

    static let success = Color(hex: "4ADE80").opacity(0.9)
    static let warning = Color(hex: "FBBF24").opacity(0.9)
    static let error = Color(hex: "F87171").opacity(0.9)

    // MARK: - Gradients

    /// Subtle radial glow behind hero image
    static let heroGlow = RadialGradient(
        colors: [surface.opacity(0.4), canvas],
        center: .center,
        startRadius: 50,
        endRadius: 400
    )

    // MARK: - Animations

    /// Primary easing - confident, smooth
    static let smoothEase = Animation.easeOut(duration: 0.4)

    /// Quick interactions - hover, tap feedback
    static let quickEase = Animation.easeOut(duration: 0.2)

    /// Staggered reveals - for variation strip
    static func stagger(index: Int) -> Animation {
        .easeOut(duration: 0.4).delay(Double(index) * 0.08)
    }
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
```

---

### Typography

| Use | Font | Size | Weight | Tracking |
|-----|------|------|--------|----------|
| Display (prompts, headings) | Instrument Serif | 18-24pt | Regular | 0 |
| UI Labels | Söhne / SF Pro | 13-15pt | Regular/Medium | 0 |
| Section Headers | Söhne / SF Pro | 11pt | Medium | 1.5pt |
| Buttons | Söhne / SF Pro | 14pt | Medium | 0 |
| Captions | Söhne / SF Pro | 11pt | Regular | 0 |

**Fallback:** Use system `.serif` for display, system default for UI.

```swift
extension LogoForgeTheme {
    // Display font - editorial feel
    static func display(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: .title)
    }

    // Fallback if custom font unavailable
    static func displayFallback(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    // UI font
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
```

---

### Window Layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                                                              ○ ○ ○           │
├───────────────┬──────────────────────────────────────────────────────────────┤
│               │                                                              │
│   PROJECTS    │                                                              │
│   ──────────  │            ┌────────────────────────────┐                   │
│               │            │                            │                   │
│   Acme Corp   │            │                            │                   │
│   ● active    │            │        YOUR LOGO           │    ← HERO AREA    │
│               │            │                            │      (60% height) │
│   Startup X   │            │      (selected var)        │                   │
│   Rebrand     │            │                            │                   │
│               │            └────────────────────────────┘                   │
│               │                                                              │
│   + New       │       ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                   │
│               │       │  v1  │ │  v2  │ │  v3  │ │  v4  │  ← VARIATION STRIP│
│───────────────│       │  ●   │ │  ○   │ │  ○   │ │  ○   │                   │
│               │       └──────┘ └──────┘ └──────┘ └──────┘                   │
│   SETTINGS    │                                                              │
│               │ ─────────────────────────────────────────────────────────── │
│   API Key ●   │                                                              │
│   Export  ◐   │   What's your vision?                                        │
│               │   ┌──────────────────────────────────────────────────────┐  │
│               │   │ A minimal wordmark for a coffee roastery called...  │  │
│               │   └──────────────────────────────────────────────────────┘  │
│               │                                                              │
│               │   Minimal ▼    ◉ Text ○ Abstract    ×4    [Export] [Gen]    │
│               │                                                              │
└───────────────┴──────────────────────────────────────────────────────────────┘
```

**Key layout decisions:**
- Sidebar: 200px fixed, minimal chrome
- Hero: 60% of detail area height
- Variation strip: Horizontal scroll, 80px thumbnails
- Prompt bar: Bottom-anchored, feels like a command line

---

### Component Specifications

#### 1. Hero Area

The centerpiece. Selected logo displayed large with subtle depth effects.

```swift
// Views/Components/hero-area.swift

import SwiftUI

struct HeroArea: View {
    let image: NSImage?
    let isGenerating: Bool

    @State private var isHovering = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Subtle radial glow
                LogoForgeTheme.heroGlow

                if let image = image {
                    // The logo - commanding presence
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            maxWidth: geo.size.width * 0.6,
                            maxHeight: geo.size.height * 0.75
                        )
                        // Dramatic shadow for depth
                        .shadow(
                            color: .black.opacity(0.4),
                            radius: 40,
                            y: 20
                        )
                        // Subtle hover lift
                        .scaleEffect(isHovering ? 1.02 : 1.0)
                        .animation(LogoForgeTheme.smoothEase, value: isHovering)
                        .onHover { isHovering = $0 }

                } else if isGenerating {
                    // Generation in progress
                    GeneratingState()
                } else {
                    // Empty state
                    EmptyHeroState()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(LogoForgeTheme.canvas)
    }
}

struct EmptyHeroState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.3))

            Text("Your logo will appear here")
                .font(LogoForgeTheme.displayFallback(18))
                .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.5))
        }
    }
}

struct GeneratingState: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            // Custom spinner
            Circle()
                .stroke(LogoForgeTheme.border, lineWidth: 2)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(LogoForgeTheme.paper, lineWidth: 2)
                        .rotationEffect(.degrees(rotation))
                )
                .onAppear {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("Generating...")
                .font(LogoForgeTheme.body(14))
                .foregroundStyle(LogoForgeTheme.textSecondary)
        }
    }
}
```

---

#### 2. Variation Strip

Horizontal gallery of thumbnails. Selected state is subtle but clear.

```swift
// Views/Components/variation-strip.swift

import SwiftUI

struct VariationStrip: View {
    let variations: [NSImage]
    @Binding var selectedIndex: Int

    @State private var hoveredIndex: Int?

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(variations.enumerated()), id: \.offset) { index, image in
                VariationThumbnail(
                    image: image,
                    isSelected: selectedIndex == index,
                    isHovered: hoveredIndex == index
                )
                .onTapGesture {
                    withAnimation(LogoForgeTheme.smoothEase) {
                        selectedIndex = index
                    }
                }
                .onHover { hovering in
                    withAnimation(LogoForgeTheme.quickEase) {
                        hoveredIndex = hovering ? index : nil
                    }
                }
                // Staggered entrance animation
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
}

struct VariationThumbnail: View {
    let image: NSImage
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 10) {
            // Thumbnail
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                // Dynamic shadow based on state
                .shadow(
                    color: .black.opacity(isSelected ? 0.5 : 0.25),
                    radius: isSelected ? 20 : 10,
                    y: isSelected ? 10 : 5
                )
                // Scale on selection/hover
                .scaleEffect(isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))

            // Selection indicator
            Circle()
                .fill(isSelected ? LogoForgeTheme.paper : .clear)
                .stroke(
                    isSelected ? LogoForgeTheme.paper : LogoForgeTheme.border,
                    lineWidth: 1.5
                )
                .frame(width: 8, height: 8)
        }
        .animation(LogoForgeTheme.smoothEase, value: isSelected)
        .animation(LogoForgeTheme.quickEase, value: isHovered)
    }
}
```

---

#### 3. Model Toggle

Clean segmented control. "Text" vs "Abstract" - simple mental model.

```swift
// Views/Components/model-toggle.swift

import SwiftUI

struct ModelToggle: View {
    @Binding var selection: AIModel

    var body: some View {
        HStack(spacing: 0) {
            ToggleSegment(
                label: "Text",
                isSelected: selection == .ideogramV3,
                position: .left
            ) {
                selection = .ideogramV3
            }

            ToggleSegment(
                label: "Abstract",
                isSelected: selection == .nanaBananaPro,
                position: .right
            ) {
                selection = .nanaBananaPro
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(LogoForgeTheme.surface)
        )
    }
}

struct ToggleSegment: View {
    enum Position { case left, right }

    let label: String
    let isSelected: Bool
    let position: Position
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(LogoForgeTheme.body(13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(
                    isSelected ? LogoForgeTheme.canvas : LogoForgeTheme.textSecondary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(LogoForgeTheme.paper)
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(LogoForgeTheme.hover)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
```

---

#### 4. Prompt Bar

Editorial feel. The prompt input feels like writing, not filling a form.

```swift
// Updates to Views/Components/prompt-bar.swift

struct PromptBar: View {
    @Binding var prompt: String
    @Binding var style: Style
    @Binding var model: AIModel
    @Binding var variationCount: Int

    let onGenerate: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Editorial prompt label
            Text("What's your vision?")
                .font(LogoForgeTheme.displayFallback(15))
                .foregroundStyle(LogoForgeTheme.textSecondary)

            // Prompt input - feels like a text editor
            TextField(
                "A minimal wordmark for a coffee roastery...",
                text: $prompt,
                axis: .vertical
            )
            .font(LogoForgeTheme.body(15))
            .foregroundStyle(LogoForgeTheme.textPrimary)
            .textFieldStyle(.plain)
            .lineLimit(2...4)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LogoForgeTheme.surface)
            )

            // Controls row
            HStack(spacing: 20) {
                // Style picker
                StylePicker(selection: $style)

                // Model toggle
                ModelToggle(selection: $model)

                // Variation count
                VariationStepper(count: $variationCount)

                Spacer()

                // Export button (secondary)
                Button(action: onExport) {
                    Text("Export")
                        .font(LogoForgeTheme.body(14, weight: .medium))
                }
                .buttonStyle(SecondaryButtonStyle())

                // Generate button (primary)
                Button(action: onGenerate) {
                    Text("Generate")
                        .font(LogoForgeTheme.body(14, weight: .medium))
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .background(LogoForgeTheme.canvas)
    }
}
```

---

#### 5. Button Styles

Refined, not flashy. Primary buttons have presence without screaming.

```swift
// Utilities/button-styles.swift

struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LogoForgeTheme.canvas)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(LogoForgeTheme.paper)
                    // Subtle glow on hover
                    .shadow(
                        color: LogoForgeTheme.paper.opacity(isHovered ? 0.3 : 0),
                        radius: 16
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(LogoForgeTheme.quickEase, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LogoForgeTheme.textSecondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(LogoForgeTheme.border, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHovered ? LogoForgeTheme.hover : .clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(LogoForgeTheme.quickEase, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
```

---

#### 6. Export Sheet

Modal overlay. Logo preview stays visible—you're always looking at your work.

```swift
// Views/Components/export-sheet.swift

struct ExportSheet: View {
    let image: NSImage
    @Binding var options: ExportOptions

    let onExport: () -> Void
    let onCancel: () -> Void

    private var estimatedCost: Decimal {
        var cost: Decimal = 0
        if options.upscaleMode != .off { cost += 0.02 }
        if options.selectedBundles.contains(.svg) { cost += 0.05 }
        return cost
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("EXPORT")
                .font(LogoForgeTheme.body(12, weight: .medium))
                .foregroundStyle(LogoForgeTheme.textSecondary)
                .tracking(2)
                .padding(.top, 32)
                .padding(.bottom, 24)

            // Logo preview
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 180)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LogoForgeTheme.surface)
                )
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(.horizontal, 40)

            // Divider
            Rectangle()
                .fill(LogoForgeTheme.border)
                .frame(height: 1)
                .padding(.vertical, 28)
                .padding(.horizontal, 40)

            // Options
            HStack(alignment: .top, spacing: 48) {
                // Platforms
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("PLATFORMS")

                    ForEach(ExportBundle.allCases) { bundle in
                        BundleToggle(
                            bundle: bundle,
                            isSelected: options.selectedBundles.contains(bundle)
                        ) {
                            if options.selectedBundles.contains(bundle) {
                                options.selectedBundles.remove(bundle)
                            } else {
                                options.selectedBundles.insert(bundle)
                            }
                        }
                    }
                }

                // Options
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("OPTIONS")

                    Text("Enhancement")
                        .font(LogoForgeTheme.body(13))
                        .foregroundStyle(LogoForgeTheme.textSecondary)

                    ForEach(UpscaleMode.allCases, id: \.self) { mode in
                        RadioOption(
                            label: mode.rawValue,
                            isSelected: options.upscaleMode == mode
                        ) {
                            options.upscaleMode = mode
                        }
                    }

                    Spacer().frame(height: 8)

                    CheckboxOption(
                        label: "Include dark variant",
                        isOn: $options.generateVariants
                    )
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // Footer
            VStack(spacing: 16) {
                Rectangle()
                    .fill(LogoForgeTheme.border)
                    .frame(height: 1)

                HStack {
                    Spacer()

                    if estimatedCost > 0 {
                        Text("$\(estimatedCost as NSDecimalNumber) estimated")
                            .font(LogoForgeTheme.body(13))
                            .foregroundStyle(LogoForgeTheme.textSecondary)
                    }

                    Spacer().frame(width: 24)

                    Button("Cancel", action: onCancel)
                        .buttonStyle(SecondaryButtonStyle())

                    Button(action: onExport) {
                        HStack(spacing: 6) {
                            Text("Export")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 540, height: 560)
        .background(LogoForgeTheme.canvas)
    }
}

struct SectionHeader: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(LogoForgeTheme.body(11, weight: .medium))
            .foregroundStyle(LogoForgeTheme.textSecondary)
            .tracking(1.5)
    }
}
```

---

### Motion & Micro-interactions

| Interaction | Animation | Duration |
|-------------|-----------|----------|
| Variation selection | Scale + shadow increase | 0.4s ease-out |
| Hover states | Background fill | 0.2s ease-out |
| Button press | Scale to 0.98 | 0.2s ease-out |
| Hero hover | Scale to 1.02 | 0.4s ease-out |
| Variation strip entrance | Staggered fade + scale | 0.4s + 0.08s delay per item |
| Sheet appear | Fade + slight scale | 0.3s ease-out |
| Generation spinner | Continuous rotation | 1s linear |

---

### Files to Create (Phase 5)

| File | Purpose |
|------|---------|
| `Utilities/theme.swift` | Colors, fonts, animations |
| `Utilities/button-styles.swift` | Primary/Secondary button styles |
| `Views/Components/hero-area.swift` | Main logo display area |
| `Views/Components/variation-strip.swift` | Horizontal thumbnails |
| `Views/Components/model-toggle.swift` | Text/Abstract segmented control |
| `Views/Components/export-sheet.swift` | Export modal redesign |

### Files to Modify (Phase 5)

| File | Changes |
|------|---------|
| `Views/Screens/workspace-view.swift` | Replace VariationsGrid with Hero + Strip layout |
| `Views/Components/prompt-bar.swift` | Add ModelToggle, new styling |
| `Views/Screens/sidebar-view.swift` | Apply theme colors |
| `ContentView.swift` | Apply theme background |

---

## Implementation Phases

### Phase 1: AI Model Selection
**Goal:** Users can choose between Ideogram v3 and Nano Banana Pro

- [ ] Create `ai-model.swift`
- [ ] Update `ReplicateService` to accept model parameter
- [ ] Add `ModelToggle` to `PromptBar`
- [ ] Update `GenerationState` and `Project` model
- [ ] Test both models generate correctly

**Deliverable:** Can generate with either model

---

### Phase 2: Social Media Bundle
**Goal:** Export social media sizes

- [ ] Add `social` case to `ExportBundle`
- [ ] Add `socialSizes` definitions
- [ ] Update export UI with new option
- [ ] Test export creates correct files

**Deliverable:** Can export Twitter/LinkedIn/Facebook/YouTube sizes

---

### Phase 3: AI Upscaling
**Goal:** 4x enhancement before export

- [ ] Create `UpscalingService`
- [ ] Add `UpscaleMode` enum
- [ ] Create `ExportOptions` state
- [ ] Update `ExportSheet` with upscale toggle
- [ ] Integrate into export pipeline
- [ ] Show cost estimate

**Deliverable:** Can upscale images before export

---

### Phase 4: Vector SVG Export
**Goal:** AI-powered SVG conversion

- [ ] Create `VectorizationService`
- [ ] Add `svg` case to `ExportBundle`
- [ ] Generate dark/transparent SVG variants
- [ ] Update export pipeline
- [ ] Test SVG output quality

**Deliverable:** Can export clean vector SVGs

---

### Phase 5: UI Refresh
**Goal:** Studio/Atelier aesthetic - logo as hero, gallery-like experience

**5a. Theme Foundation**
- [ ] Create `Utilities/theme.swift` with LogoForgeTheme
- [ ] Add Color hex extension
- [ ] Define animation curves (smoothEase, quickEase, stagger)
- [ ] Create `Utilities/button-styles.swift` (Primary, Secondary)

**5b. Hero Layout**
- [ ] Create `Views/Components/hero-area.swift`
- [ ] Implement EmptyHeroState
- [ ] Implement GeneratingState with custom spinner
- [ ] Add radial glow background
- [ ] Add hover lift effect (scale 1.02)
- [ ] Add dramatic shadow (40px blur, 20px y-offset)

**5c. Variation Strip**
- [ ] Create `Views/Components/variation-strip.swift`
- [ ] Horizontal layout with 80px thumbnails
- [ ] Selection indicator (filled circle)
- [ ] Hover/selection scale effects
- [ ] Staggered entrance animation

**5d. Model Toggle**
- [ ] Create `Views/Components/model-toggle.swift`
- [ ] Segmented control: "Text" / "Abstract"
- [ ] Hover states on segments
- [ ] Integrate into PromptBar

**5e. Prompt Bar Redesign**
- [ ] Update `Views/Components/prompt-bar.swift`
- [ ] Editorial "What's your vision?" label
- [ ] Multi-line TextField with surface background
- [ ] Add ModelToggle to controls row
- [ ] Apply theme typography

**5f. Export Sheet Redesign**
- [ ] Create `Views/Components/export-sheet.swift`
- [ ] Logo preview with shadow
- [ ] Platform radio buttons
- [ ] Upscale mode options
- [ ] Cost estimate in footer
- [ ] Apply theme styling

**5g. Apply Theme Globally**
- [ ] Update `ContentView.swift` - canvas background
- [ ] Update `Views/Screens/workspace-view.swift` - replace VariationsGrid
- [ ] Update `Views/Screens/sidebar-view.swift` - theme colors
- [ ] Test dark mode consistency

**Deliverable:** Premium, gallery-like interface with hero-focused layout

---

## Dependency Graph

```
Phase 1 (Models) ──────────────────┐
                                   │
Phase 2 (Social) ─────────────┐    │
                              │    │
                              ▼    ▼
                         Phase 3 (Upscaling)
                              │
                              ▼
                         Phase 4 (SVG)
                              │
                              ▼
                         Phase 5 (UI)
```

---

## Cost Summary

| Operation | Cost |
|-----------|------|
| Generation (Ideogram v3) | $0.08/image |
| Generation (Nano Banana Pro) | $0.15/image |
| AI Upscaling (4x) | $0.02/image |
| AI Vectorization | $0.05/image |
| **Typical export with AI** | **$0.07** |

---

## File Changes Summary

### New Files

| File | Phase | Purpose |
|------|-------|---------|
| `Models/ai-model.swift` | 1 | AIModel enum (Ideogram v3, Nano Banana Pro) |
| `Models/export-options.swift` | 3 | ExportOptions state, UpscaleMode enum |
| `Services/upscaling-service.swift` | 3 | Real-ESRGAN 4x upscaling |
| `Services/vectorization-service.swift` | 4 | Vectorizer AI SVG conversion |
| `Utilities/theme.swift` | 5 | LogoForgeTheme colors, fonts, animations |
| `Utilities/button-styles.swift` | 5 | PrimaryButtonStyle, SecondaryButtonStyle |
| `Views/Components/hero-area.swift` | 5 | Hero display with glow, shadow, hover |
| `Views/Components/variation-strip.swift` | 5 | Horizontal thumbnail gallery |
| `Views/Components/model-toggle.swift` | 1 | Text/Abstract segmented control |
| `Views/Components/export-sheet.swift` | 5 | Redesigned export modal |

### Modified Files

| File | Phase | Changes |
|------|-------|---------|
| `Services/replicate-service.swift` | 1 | Accept AIModel parameter, dynamic model path |
| `Models/replicate-models.swift` | 1 | Update request to use dynamic model |
| `Models/export-bundle.swift` | 2, 4 | Add social, svg cases with sizes |
| `Models/project.swift` | 1 | Add model field |
| `Models/generation-state.swift` | 1 | Add model field |
| `Services/export-service.swift` | 3, 4 | Integrate upscaling/vectorization pipeline |
| `Views/Components/prompt-bar.swift` | 1, 5 | Add ModelToggle, theme styling |
| `Views/Screens/workspace-view.swift` | 5 | Replace VariationsGrid with Hero + Strip |
| `Views/Screens/sidebar-view.swift` | 5 | Apply theme colors |
| `ContentView.swift` | 5 | Apply theme background |
| `Utilities/environment-keys.swift` | 3, 4 | Add upscaling/vectorization services |

---

## Future Roadmap (Post-v2)

These are improvements to consider after v2 is complete. Ordered by impact and feasibility.

---

### Priority 2: Faster Iteration

**Goal:** Reduce generation costs and speed up the creative workflow.

| Feature | Description | Complexity |
|---------|-------------|------------|
| **AI Inpainting** | Edit specific parts of logo without regenerating entire image | Medium |
| **Partial Regeneration** | Keep logo shape, change text only (or vice versa) | Medium |
| **Undo/Redo History** | Step back through edits and generations | Low |
| **Batch Regeneration** | Regenerate all 4 variations with one click | Low |
| **Prompt History** | Quick access to previous prompts | Low |

**Why this matters:** Currently, any change requires a full regeneration ($0.08-0.15). Inpainting could reduce iteration costs by 80%.

---

### Priority 3: Creative Exploration

**Goal:** Give users more creative control and inspiration sources.

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Sketch-to-Logo** | Draw rough idea on canvas, AI refines into logo | High |
| **Style Transfer** | Apply visual style from a reference logo | Medium |
| **Color Palette Extraction** | Extract colors from reference images | Low |
| **Variation Controls** | Temperature, style strength sliders | Low |
| **Prompt Suggestions** | AI-generated prompt improvements | Low |

**Potential implementation (Sketch-to-Logo):**
```swift
// Future: SketchCanvas component
struct SketchCanvas: View {
    @State private var paths: [Path] = []

    var body: some View {
        Canvas { context, size in
            for path in paths {
                context.stroke(path, with: .color(.white), lineWidth: 2)
            }
        }
        .gesture(DragGesture().onChanged { /* capture drawing */ })
    }
}

// Convert sketch to image, send as reference to AI
```

---

### Priority 4: Brand Ecosystem

**Goal:** Expand from single logo to complete brand identity.

| Feature | Description | Complexity |
|---------|-------------|------------|
| **Color Palette Generation** | Primary, secondary, accent colors from logo | Medium |
| **Typography Pairing** | Font suggestions that match logo style | Medium |
| **Brand Guidelines PDF** | Auto-generate usage guidelines document | High |
| **Social Media Templates** | Pre-sized templates with logo placed | Medium |
| **Business Card Mockup** | Preview logo on business card | Low |
| **Favicon + PWA Generator** | Complete web manifest package | Low (already partial) |
| **Brand Consistency Checker** | Analyze if assets match brand | High |

**Potential brand kit output:**
```
brand-kit/
├── logo/
│   ├── primary.svg
│   ├── primary-dark.svg
│   ├── icon-only.svg
│   └── wordmark-only.svg
├── colors/
│   └── palette.json
├── typography/
│   └── recommendations.md
├── guidelines/
│   └── brand-guidelines.pdf
└── templates/
    ├── twitter-header.png
    ├── linkedin-banner.png
    └── business-card.png
```

---

### Priority Matrix

```
                    HIGH IMPACT
                         │
     ┌───────────────────┼───────────────────┐
     │                   │                   │
     │   AI Inpainting   │   Brand Kit Gen   │
     │   Sketch-to-Logo  │   Guidelines PDF  │
     │                   │                   │
LOW ─┼───────────────────┼───────────────────┼─ HIGH
EFFORT                   │                   EFFORT
     │                   │                   │
     │   Undo/Redo       │   Style Transfer  │
     │   Prompt History  │   Consistency AI  │
     │   Color Extract   │                   │
     │                   │                   │
     └───────────────────┼───────────────────┘
                         │
                    LOW IMPACT
```

**Recommended order:**
1. Undo/Redo + Prompt History (quick wins)
2. AI Inpainting (high value)
3. Color Palette Extraction (enables brand kit)
4. Brand Kit Generation (differentiator)
5. Sketch-to-Logo (wow factor)

---

## Research Sources

- [Logo Diffusion](https://logodiffusion.com/) - AI logo generation trends
- [SVG AI](https://www.svgai.org/blog/ai-svg-generation/free-ai-svg-tools-resources) - SVG generation tools
- [Replicate Models](https://replicate.com/collections/text-to-image) - Available AI models
- [Ideogram](https://replicate.com/ideogram-ai/ideogram-v3) - Text rendering model

---

*Plan created: 2026-01-01*
