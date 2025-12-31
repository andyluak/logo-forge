# Logo Forge - Design Document

> macOS SwiftUI app for AI-powered logo generation with multi-platform export

**Date:** 2025-12-31
**Status:** Approved

---

## Table of Contents

1. [Overview](#overview)
2. [Tech Stack](#tech-stack)
3. [Architecture](#architecture)
4. [Data Models](#data-models)
5. [Services Layer](#services-layer)
6. [View Hierarchy](#view-hierarchy)
7. [Replicate API Integration](#replicate-api-integration)
8. [Export System](#export-system)
9. [Editing Tools](#editing-tools)
10. [Error Handling](#error-handling)
11. [Onboarding & Settings](#onboarding--settings)
12. [Implementation Phases](#implementation-phases)
13. [Risks & Mitigations](#risks--mitigations)

---

## Overview

Logo Forge is a native macOS app that generates logos using AI (Replicate's Nano Banana Pro model) and exports them to all required sizes for iOS, Android, favicon, and social media.

### Core Features

- **Text-to-Image**: User types prompt, gets logo variations
- **Image-to-Image**: User uploads up to 14 reference images, AI refines
- **Style Presets**: Minimal, bold, tech, vintage, etc. (dropdown with thumbnails)
- **Variation Control**: Generate 1-4 variations per request (user configurable)
- **Basic Editing**: Background color, padding, crop, rotate, flip
- **One-Click Export**: iOS, Android, Favicon, Social Media bundles (checkboxes)
- **Project History**: Auto-saved locally, sidebar navigation

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| AI Model | Nano Banana Pro | Excellent text rendering for logos, $0.15/image |
| API Key Storage | Keychain only | Secure, native macOS, encrypted at rest |
| Variations | User configurable 1-4 | Cost control in user's hands |
| Window Structure | NavigationSplitView | Native macOS pattern, quick project switching |
| Auto-save | On every generation | No lost work |
| Error Handling | Severity-based | Modal (critical), Inline (generation), Toast (transient) |
| Onboarding | Single-screen setup | Minimal friction, API key required upfront |

---

## Tech Stack

| Component | Choice | Why |
|-----------|--------|-----|
| App | Swift + SwiftUI | Native macOS, fast, no Electron bloat |
| State | @Observable (iOS 17+) | Modern, performant, simpler than ObservableObject |
| AI API | Replicate (Nano Banana Pro) | User brings own key, no backend costs |
| Image Processing | Core Graphics | Native Apple framework, hardware accelerated |
| Storage | SwiftData + FileManager | Offline-first, user owns files |
| Secrets | Keychain Services | Secure, encrypted, native |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Logo Forge - Modern SwiftUI                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                      App (@main)                         │    │
│  │  @State var appState = AppState()  ← owns root state    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                     │
│                            ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 Views (SwiftUI)                          │    │
│  │  • Root views receive @Observable via .environment()    │    │
│  │  • Simple views use @State for local state only         │    │
│  │  • @Bindable for two-way binding when needed            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                     │
│                            ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │               Services (injected via Environment)        │    │
│  │  • ReplicateService    (API calls)                       │    │
│  │  • ExportService       (image resizing/export)           │    │
│  │  • KeychainService     (secure storage)                  │    │
│  │  • ProjectService      (file management)                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                     │
│                            ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Data Layer                            │    │
│  │  • SwiftData models (@Model)                             │    │
│  │  • FileManager for exports                               │    │
│  │  • Keychain for API key                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Principles

- **@Observable at App level**: `@State` owns root state in App struct
- **Services via Environment**: Injected for testability
- **Lean ViewModels**: Not every view needs one, only root views
- **SwiftData for persistence**: Models separate from runtime state

---

## Data Models

### SwiftData Models (Persisted)

```swift
@Model
final class Project {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var prompt: String
    var style: String
    var referenceImagePaths: [String]
    var selectedVariationIndex: Int?

    @Relationship(deleteRule: .cascade)
    var variations: [GeneratedImage]
}

@Model
final class GeneratedImage {
    var id: UUID
    var createdAt: Date
    var localPath: String
    var prompt: String
    var style: String
    var isSelected: Bool
}
```

### Runtime State (@Observable)

```swift
@Observable
final class AppState {
    var currentProject: Project?
    var isGenerating = false
    var generationProgress: Double = 0
    var pendingVariations: [GeneratedImage] = []
    var error: AppError?
    var apiKeyValid: Bool = false
}

@Observable
final class GenerationRequest {
    var prompt: String = ""
    var style: Style = .minimal
    var variationCount: Int = 4
    var referenceImages: [NSImage] = []
}

@Observable
final class EditorState {
    var backgroundColor: Color = .clear
    var padding: CGFloat = 0
    var rotation: Angle = .zero
    var isFlippedHorizontal = false
    var isFlippedVertical = false
    var cropRect: CGRect?
}
```

### Style Enum

```swift
enum Style: String, CaseIterable, Identifiable {
    case minimal = "Minimal"
    case bold = "Bold"
    case tech = "Tech"
    case vintage = "Vintage"
    case playful = "Playful"
    case elegant = "Elegant"
    case custom = "Custom"

    var id: String { rawValue }
    var promptSuffix: String { /* style-specific prompt additions */ }
    var thumbnailName: String { /* placeholder asset name */ }
}
```

### File Structure

```
~/Documents/Logo Forge/
├── Projects/
│   └── {project-uuid}/
│       ├── original.png
│       ├── variation-0.png
│       ├── variation-1.png
│       ├── references/
│       │   └── ref-0.png, ref-1.png...
│       └── exports/
│           ├── ios/
│           ├── android/
│           ├── favicon/
│           └── social/
└── LogoForge.store (SwiftData)
```

---

## Services Layer

### Protocols

```swift
protocol ReplicateServiceProtocol {
    func generate(prompt: String, style: Style, references: [Data]) async throws -> Data
    func generateVariations(prompt: String, style: Style, references: [Data], count: Int) async throws -> [Data]
    func validateAPIKey(_ key: String) async throws -> Bool
}

protocol ExportServiceProtocol {
    func export(image: NSImage, to bundles: Set<ExportBundle>, destination: URL) async throws
}

protocol KeychainServiceProtocol {
    func save(key: String) throws
    func retrieve() throws -> String?
    func delete() throws
}

protocol ProjectServiceProtocol {
    func createProject(name: String) async throws -> Project
    func saveImage(_ data: Data, to project: Project, as filename: String) throws -> URL
    func loadImage(from path: String, in project: Project) throws -> NSImage
}
```

### Environment Injection

```swift
extension EnvironmentValues {
    @Entry var replicateService: ReplicateServiceProtocol = ReplicateService()
    @Entry var exportService: ExportServiceProtocol = ExportService()
    @Entry var keychainService: KeychainServiceProtocol = KeychainService()
    @Entry var projectService: ProjectServiceProtocol = ProjectService()
}
```

---

## View Hierarchy

```
LogoForgeApp (@main)
│
├── ContentView (NavigationSplitView)
│   │
│   ├── [Sidebar]
│   │   ├── ProjectListView
│   │   │   ├── NewProjectButton
│   │   │   └── ProjectRow (ForEach)
│   │   └── HistorySection
│   │       └── HistoryRow (ForEach, grouped by date)
│   │
│   └── [Detail]
│       └── WorkspaceView
│           ├── PromptBar
│           │   ├── TextField (prompt input)
│           │   ├── StylePicker (dropdown + thumbnails)
│           │   ├── VariationStepper (1-4)
│           │   └── GenerateButton
│           │
│           ├── ReferenceImagesBar (drop zone, up to 14)
│           │   └── ReferenceThumbnail (ForEach)
│           │
│           ├── VariationsGrid
│           │   └── VariationCard (LazyVGrid)
│           │
│           ├── EditorPanel (when variation selected)
│           │   ├── BackgroundColorPicker
│           │   ├── PaddingSlider
│           │   ├── CropTool
│           │   └── RotateFlipButtons
│           │
│           └── ExportBar
│               ├── BundleCheckboxes
│               └── ExportButton
│
├── SettingsView (Settings scene)
│
└── OnboardingSheet (first run)
```

### Window Layout

```
┌─────────────────────────────────────────────────────────┐
│ ◉ ◉ ◉  Logo Forge                          ⚙️ Settings │
├────────────┬────────────────────────────────────────────┤
│  PROJECTS  │                                            │
│ ──────────│                                            │
│ 📁 Acme    │   ┌─────────────────────────────────────┐  │
│ 📁 Startup │   │         GENERATION AREA             │  │
│ 📁 Brand X │   │   [Prompt Input] [Style ▼] [1-4]   │  │
│            │   │                                     │  │
│ + New      │   │   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │  │
│            │   │   │ V1  │ │ V2  │ │ V3  │ │ V4  │  │  │
│ ──────────│   │   └─────┘ └─────┘ └─────┘ └─────┘  │  │
│  HISTORY   │   │                                     │  │
│ ──────────│   │   [Edit] [Regenerate] [Export]     │  │
│ 🕐 Today   │   └─────────────────────────────────────┘  │
│ 🕐 Yesterday│                                            │
└────────────┴────────────────────────────────────────────┘
```

---

## Replicate API Integration

### API Models

```swift
struct ReplicateCreateRequest: Encodable {
    let model: String = "google/nano-banana-pro"
    let input: InputParams

    struct InputParams: Encodable {
        let prompt: String
        let image_input: [String]?  // base64 encoded
        let resolution: String       // "1K", "2K", "4K"
        let aspect_ratio: String     // "1:1"
        let output_format: String    // "png"
    }
}

struct ReplicatePrediction: Decodable {
    let id: String
    let status: Status
    let output: [String]?
    let error: String?

    enum Status: String, Decodable {
        case starting, processing, succeeded, failed, canceled
    }
}
```

### Generation Flow

1. Create prediction (POST /predictions)
2. Poll for completion (GET /predictions/{id}) every 2 seconds
3. Download result image from output URL
4. Return image data

### Parallel Generation

```swift
func generateVariations(prompt:, style:, references:, count:) async throws -> [Data] {
    try await withThrowingTaskGroup(of: Data.self) { group in
        for _ in 0..<count {
            group.addTask {
                try await self.generate(prompt:, style:, references:)
            }
        }
        return try await group.reduce(into: []) { $0.append($1) }
    }
}
```

---

## Export System

### Export Bundles

| Bundle | Sizes |
|--------|-------|
| **iOS** | 20, 29, 40, 58, 60, 76, 80, 87, 120, 167, 180, 1024 |
| **Android** | 48 (mdpi), 72 (hdpi), 96 (xhdpi), 144 (xxhdpi), 192 (xxxhdpi), 512 |
| **Favicon** | 16, 32, 48, 96, 180, 192, 512 + .ico + webmanifest |
| **Social** | 400x400 (Twitter), 300x300 (LinkedIn), 180x180 (Facebook), 800x800 (YouTube) |
| **Generic** | @1x (64), @2x (128), @3x (192), large (1024) |

### Output Structure

```
exports/
├── ios/
│   └── AppIcon.appiconset/
│       ├── Contents.json
│       └── icon-*.png
├── android/
│   ├── mipmap-mdpi/ic_launcher.png
│   ├── mipmap-hdpi/ic_launcher.png
│   ├── mipmap-xhdpi/ic_launcher.png
│   ├── mipmap-xxhdpi/ic_launcher.png
│   ├── mipmap-xxxhdpi/ic_launcher.png
│   └── playstore-icon.png
├── favicon/
│   ├── favicon.ico
│   ├── favicon-*.png
│   └── site.webmanifest
└── social/
    ├── twitter.png
    ├── linkedin.png
    ├── facebook.png
    └── youtube.png
```

---

## Editing Tools

### Available Operations

| Operation | Implementation |
|-----------|----------------|
| Background Color | ColorPicker → fill behind image |
| Padding | Slider 0-100px → expand canvas |
| Rotate | 90° increments → Core Graphics transform |
| Flip | Horizontal/Vertical → Core Graphics scale(-1) |
| Crop | Rectangle selection → CGImage cropping |

### Future Extension (Layer-Aware)

```swift
protocol EditOperation {
    func apply(to image: NSImage) -> NSImage
}

// Current
struct PaddingOperation: EditOperation { }
struct RotateOperation: EditOperation { }

// Future
// struct BackgroundRemovalOperation: EditOperation { }
// struct LayerCompositeOperation: EditOperation { }
```

---

## Error Handling

### Severity-Based Approach

| Severity | UI | Examples |
|----------|-----|----------|
| **Critical** | Modal alert | Missing API key, Invalid API key |
| **Generation** | Inline in results | API timeout, Content filtered, Model unavailable |
| **Transient** | Toast (5s auto-dismiss) | Network error, Rate limited, Export failed |

### Error Types

```swift
enum AppError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case generationFailed(String)
    case contentFiltered
    case modelUnavailable
    case networkError
    case rateLimited(retryAfter: Int)
    case exportFailed(String)

    var severity: ErrorSeverity { }
    var errorDescription: String? { }
    var recoverySuggestion: String? { }
}
```

---

## Onboarding & Settings

### First Run Flow

1. Check Keychain for existing API key
2. If missing → show OnboardingSheet (modal)
3. User enters key → validate with Replicate API
4. If valid → save to Keychain, dismiss, enter workspace
5. If invalid → show error, let user retry

### OnboardingSheet Layout

```
┌─────────────────────────────────────────────────┐
│                                                 │
│         🎨 Welcome to Logo Forge                │
│                                                 │
│   Generate beautiful logos with AI.             │
│   Enter your Replicate API key to start.        │
│                                                 │
│   ┌─────────────────────────────────────────┐   │
│   │  r8_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx     │   │
│   └─────────────────────────────────────────┘   │
│                                                 │
│   🔗 Get your API key from replicate.com        │
│                                                 │
│              [ Get Started ]                    │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Settings Contents

- API Key (SecureField + show/hide toggle)
- Default export location picker
- About section (version, model info, links)

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Project structure & file organization
- [ ] KeychainService implementation
- [ ] Basic NavigationSplitView shell
- [ ] Empty states & placeholder views
- [ ] Settings view with API key input

### Phase 2: Core Generation
- [ ] ReplicateService with create/poll/download
- [ ] PromptBar UI (prompt, style picker, count stepper)
- [ ] Generation loading states ("Model warming up...")
- [ ] VariationsGrid display
- [ ] Error handling (inline + toast)
- [ ] Reference image drop zone (up to 14, resize before send)

### Phase 3: Project Persistence
- [ ] SwiftData models (Project, GeneratedImage)
- [ ] ProjectService (file management)
- [ ] Sidebar project list
- [ ] Auto-save on generation
- [ ] Project rename/delete with confirmation
- [ ] History section (grouped by date)

### Phase 4: Editing
- [ ] EditorState & EditorPanel UI
- [ ] ImageProcessor (padding, background, rotate, flip)
- [ ] Crop tool (basic rectangle)
- [ ] Apply/Reset flow
- [ ] Real-time preview updates

### Phase 5: Export
- [ ] ExportBundle definitions & sizes
- [ ] Core Graphics resize pipeline
- [ ] iOS .appiconset + Contents.json
- [ ] Android mipmap folder structure
- [ ] Favicon .ico generation + webmanifest
- [ ] Social media sizes
- [ ] Export progress & completion feedback

### Phase 6: Polish
- [ ] Onboarding sheet (first run)
- [ ] Contextual tooltips (first use hints)
- [ ] Keyboard shortcuts (Cmd+G, Cmd+E, etc.)
- [ ] Menu bar integration
- [ ] App icon
- [ ] Edge case handling & testing

### Dependency Graph

```
Phase 1 ─────► Phase 2 ─────► Phase 3
                  │              │
                  │              ▼
                  │          Phase 4
                  │              │
                  ▼              ▼
              Phase 5 ◄──────────┘
                  │
                  ▼
              Phase 6
```

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Sandbox file access | Can't export to user locations | NSOpenPanel + scoped URL bookmarks |
| Large reference payloads | API timeout, memory pressure | Resize to max 1024px before base64 |
| Replicate cold starts | 15-20s feels broken | "Model warming up..." state |
| ICO format complexity | Invalid favicon.ico | Use proven ICO encoder or library |
| SwiftData + @Observable | State sync issues | Keep @Model as pure data, separate from AppState |
| Generation cancellation | Orphaned API predictions | Store prediction ID, cleanup on launch |
| Accidental project delete | Data loss | Confirmation dialog + optional soft delete |

---

## Performance Targets

| Metric | Target |
|--------|--------|
| App launch to ready | < 1 second |
| Image resize (single) | < 100ms |
| Full export (all bundles) | < 5 seconds |
| Memory usage (idle) | < 100MB |
| Memory usage (14 refs + 4 variations) | < 500MB |

---

## Testing Strategy

- **Unit tests**: ImageProcessor, ExportService (pure functions)
- **Mock services**: ReplicateService for UI tests
- **Snapshot tests**: Export outputs (known input → expected sizes)
- **Integration tests**: Full generation flow with mock API

---

*Document generated: 2025-12-31*
