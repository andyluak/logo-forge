# Logo Forge - Faster Iteration Features

> Undo/Redo, Prompt History, Color Palette, Prompt Suggestions, AI Inpainting

**Date:** 2026-01-02
**Status:** Draft
**Builds on:** [v2 Improvements](./2026-01-01-logo-forge-v2-improvements.md)

---

## Summary

This plan adds five features to reduce iteration costs and speed up the creative workflow:

1. **Undo/Redo** - Step back through editor changes
2. **Prompt History** - Global + per-project prompt tracking
3. **Color Palette Extraction** - Dominant colors from generated logos
4. **Prompt Suggestions** - AI-powered prompt improvements
5. **AI Inpainting** - Edit specific regions without full regeneration

**Cost impact:** Inpainting can reduce iteration costs by ~80% vs full regeneration.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      NEW COMPONENTS                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Models/                                                     │
│  ├── edit-history.swift        ← Phase 1: Undo/redo stack   │
│  ├── prompt-history.swift      ← Phase 2: SwiftData models  │
│  └── color-palette.swift       ← Phase 3: Extracted colors  │
│                                                              │
│  Services/                                                   │
│  ├── color-extraction-service.swift  ← Phase 3: Local Swift │
│  ├── prompt-suggestion-service.swift ← Phase 4: Replicate   │
│  └── inpainting-service.swift        ← Phase 5: Replicate   │
│                                                              │
│  Views/Components/                                           │
│  ├── undo-redo-controls.swift      ← Phase 1                │
│  ├── prompt-history-menu.swift     ← Phase 2                │
│  ├── color-palette-strip.swift     ← Phase 3                │
│  ├── prompt-suggestions.swift      ← Phase 4                │
│  ├── mask-canvas.swift             ← Phase 5                │
│  └── inpaint-toolbar.swift         ← Phase 5                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Undo/Redo (Editor Only)

**Goal:** Let users undo/redo editor changes (padding, rotate, flip, background).

**Scope:** Memory-only, no persistence. Clears when switching variations.

### Files to Create

#### `Models/edit-history.swift`

```swift
import SwiftUI

// MARK: - Edit Snapshot
/// Immutable copy of editor state at a point in time

struct EditorStateSnapshot {
    let backgroundColor: Color
    let padding: CGFloat
    let rotation: EditorState.Rotation
    let flipHorizontal: Bool
    let flipVertical: Bool
}

extension EditorState {
    /// Create snapshot of current state
    func snapshot() -> EditorStateSnapshot {
        EditorStateSnapshot(
            backgroundColor: backgroundColor,
            padding: padding,
            rotation: rotation,
            flipHorizontal: flipHorizontal,
            flipVertical: flipVertical
        )
    }

    /// Restore state from snapshot
    func apply(_ snapshot: EditorStateSnapshot) {
        backgroundColor = snapshot.backgroundColor
        padding = snapshot.padding
        rotation = snapshot.rotation
        flipHorizontal = snapshot.flipHorizontal
        flipVertical = snapshot.flipVertical
    }
}

// MARK: - Edit History
/// Manages undo/redo stacks for editor operations

@Observable
final class EditHistory {
    private(set) var undoStack: [EditorStateSnapshot] = []
    private(set) var redoStack: [EditorStateSnapshot] = []

    private let maxHistory = 20

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Push current state before making a change
    func push(_ snapshot: EditorStateSnapshot) {
        undoStack.append(snapshot)
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        // Clear redo stack on new action
        redoStack.removeAll()
    }

    /// Pop and return the previous state
    func undo(current: EditorStateSnapshot) -> EditorStateSnapshot? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    /// Pop and return the next state
    func redo(current: EditorStateSnapshot) -> EditorStateSnapshot? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    /// Clear all history (when switching images)
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
```

#### `Views/Components/undo-redo-controls.swift`

```swift
import SwiftUI

struct UndoRedoControls: View {
    let canUndo: Bool
    let canRedo: Bool
    var onUndo: () -> Void
    var onRedo: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(!canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .help("Undo (⌘Z)")

            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(!canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("Redo (⇧⌘Z)")
        }
        .foregroundStyle(LogoForgeTheme.textSecondary)
    }
}
```

### Files to Modify

#### `Views/Components/editor-panel.swift`

Add to header:

```swift
struct EditorPanel: View {
    @Bindable var state: EditorState
    @Bindable var history: EditHistory  // NEW
    // ... existing props ...

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with undo/redo
            HStack {
                Text("Edit")
                    .font(LogoForgeTheme.body(16, weight: .semibold))
                    .foregroundStyle(LogoForgeTheme.textPrimary)

                Spacer()

                // NEW: Undo/Redo controls
                UndoRedoControls(
                    canUndo: history.canUndo,
                    canRedo: history.canRedo,
                    onUndo: performUndo,
                    onRedo: performRedo
                )
            }
            // ... rest unchanged ...
        }
    }

    // NEW: Undo/Redo actions
    private func performUndo() {
        if let previous = history.undo(current: state.snapshot()) {
            state.apply(previous)
        }
    }

    private func performRedo() {
        if let next = history.redo(current: state.snapshot()) {
            state.apply(next)
        }
    }
}
```

#### `Views/Screens/workspace-view.swift`

Add history state and wire up:

```swift
struct WorkspaceView: View {
    // ... existing state ...

    @State private var editHistory = EditHistory()  // NEW

    var body: some View {
        // ... existing layout ...

        // Pass history to EditorPanel
        EditorPanel(
            state: editorState,
            history: editHistory,  // NEW
            onApply: applyEdits,
            onReset: { editorState.reset() },
            onRemoveBackground: removeBackground
        )
    }

    // Modify: Clear history when switching variations
    .onChange(of: generationState.selectedVariationID) { _, newID in
        if let variation = generationState.variations.first(where: { $0.id == newID }) {
            editorState.loadImage(variation.image)
        }
        editHistory.clear()  // NEW: Reset history for new image
    }
}
```

#### `Models/editor-state.swift`

Add history tracking to edit operations:

```swift
// In each section that modifies state, push to history first
// Example for BackgroundColorSection - wrap the binding:

// Before: ColorPicker("", selection: $state.backgroundColor)
// After: Use onChange to track

.onChange(of: state.backgroundColor) { oldValue, newValue in
    // Push handled at EditorPanel level
}
```

### Testing Checkpoint

**Build & Test:**
1. Open a project with generated variations
2. Select a variation
3. Make edits: change padding, rotate, flip, change background
4. Press ⌘Z - should undo last change
5. Press ⇧⌘Z - should redo
6. Switch to different variation - history should clear
7. Verify max 20 undo steps

---

## Phase 2: Prompt History

**Goal:** Track all prompts globally + per-project iterations.

**Scope:** Persisted via SwiftData. Accessible from PromptBar.

### Files to Create

#### `Models/prompt-history.swift`

```swift
import SwiftData
import Foundation

// MARK: - Global Prompt History
/// Tracks all prompts across all projects

@Model
final class PromptHistoryEntry {
    var id: UUID
    var prompt: String
    var styleRawValue: String
    var modelRawValue: String
    var createdAt: Date
    var projectID: UUID?  // nil if project deleted

    var style: Style {
        Style(rawValue: styleRawValue) ?? .minimal
    }

    var model: AIModel {
        AIModel(rawValue: modelRawValue) ?? .nanaBananaPro
    }

    init(prompt: String, style: Style, model: AIModel, projectID: UUID? = nil) {
        self.id = UUID()
        self.prompt = prompt
        self.styleRawValue = style.rawValue
        self.modelRawValue = model.rawValue
        self.createdAt = Date()
        self.projectID = projectID
    }
}

// MARK: - Per-Project Prompt Iteration
/// Tracks prompt evolution within a single project

@Model
final class PromptIteration {
    var id: UUID
    var version: Int
    var prompt: String
    var createdAt: Date

    @Relationship
    var project: Project?

    init(version: Int, prompt: String) {
        self.id = UUID()
        self.version = version
        self.prompt = prompt
        self.createdAt = Date()
    }
}
```

#### `Services/prompt-history-service.swift`

```swift
import SwiftData
import Foundation

protocol PromptHistoryServiceProtocol {
    func record(prompt: String, style: Style, model: AIModel, projectID: UUID?)
    func getGlobalHistory(limit: Int) -> [PromptHistoryEntry]
    func getProjectIterations(projectID: UUID) -> [PromptIteration]
}

final class PromptHistoryService: PromptHistoryServiceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func record(prompt: String, style: Style, model: AIModel, projectID: UUID?) {
        // Skip empty or duplicate prompts
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check for recent duplicate
        let recent = getGlobalHistory(limit: 1).first
        if recent?.prompt == trimmed { return }

        // Insert global entry
        let entry = PromptHistoryEntry(
            prompt: trimmed,
            style: style,
            model: model,
            projectID: projectID
        )
        modelContext.insert(entry)

        // Insert project iteration if projectID provided
        if let projectID {
            addProjectIteration(prompt: trimmed, projectID: projectID)
        }

        try? modelContext.save()
    }

    func getGlobalHistory(limit: Int = 20) -> [PromptHistoryEntry] {
        var descriptor = FetchDescriptor<PromptHistoryEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getProjectIterations(projectID: UUID) -> [PromptIteration] {
        let descriptor = FetchDescriptor<PromptIteration>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.version, order: .ascending)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func addProjectIteration(prompt: String, projectID: UUID) {
        // Get current max version for this project
        let iterations = getProjectIterations(projectID: projectID)
        let nextVersion = (iterations.last?.version ?? 0) + 1

        let iteration = PromptIteration(version: nextVersion, prompt: prompt)

        // Find and link to project
        let projectDescriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectID }
        )
        if let project = try? modelContext.fetch(projectDescriptor).first {
            iteration.project = project
        }

        modelContext.insert(iteration)
    }
}
```

#### `Views/Components/prompt-history-menu.swift`

```swift
import SwiftUI

struct PromptHistoryMenu: View {
    let history: [PromptHistoryEntry]
    var onSelect: (String) -> Void

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(
                    history.isEmpty
                        ? LogoForgeTheme.textSecondary.opacity(0.5)
                        : LogoForgeTheme.textSecondary
                )
        }
        .buttonStyle(.borderless)
        .disabled(history.isEmpty)
        .help("Prompt history")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            PromptHistoryPopover(history: history) { prompt in
                onSelect(prompt)
                isOpen = false
            }
        }
    }
}

private struct PromptHistoryPopover: View {
    let history: [PromptHistoryEntry]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("RECENT PROMPTS")
                .font(LogoForgeTheme.body(11, weight: .medium))
                .foregroundStyle(LogoForgeTheme.textSecondary)
                .tracking(1.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(history) { entry in
                        PromptHistoryRow(entry: entry, onSelect: onSelect)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .frame(width: 300)
        .background(LogoForgeTheme.surface)
    }
}

private struct PromptHistoryRow: View {
    let entry: PromptHistoryEntry
    var onSelect: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect(entry.prompt)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.prompt)
                    .font(LogoForgeTheme.body(13))
                    .foregroundStyle(LogoForgeTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(entry.style.rawValue)
                    Text("•")
                    Text(entry.createdAt, style: .relative)
                }
                .font(LogoForgeTheme.body(11))
                .foregroundStyle(LogoForgeTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? LogoForgeTheme.hover : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
```

### Files to Modify

#### `Utilities/environment-keys.swift`

```swift
// Add new environment key
extension EnvironmentValues {
    // ... existing keys ...

    @Entry var promptHistoryService: PromptHistoryServiceProtocol? = nil
}
```

#### `logo_forgeApp.swift`

```swift
// Initialize and inject service
@main
struct logo_forgeApp: App {
    // ... existing setup ...

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                // ... existing environments ...
                .environment(\.promptHistoryService, promptHistoryService)
        }
        .modelContainer(for: [
            Project.self,
            SavedVariation.self,
            PromptHistoryEntry.self,  // NEW
            PromptIteration.self       // NEW
        ])
    }

    private var promptHistoryService: PromptHistoryService {
        PromptHistoryService(modelContext: modelContext)
    }
}
```

#### `Views/Components/prompt-bar.swift`

Add history button:

```swift
struct PromptBar: View {
    @Bindable var state: GenerationState
    var onGenerate: () -> Void

    @Environment(\.promptHistoryService) private var historyService
    @State private var history: [PromptHistoryEntry] = []

    var body: some View {
        HStack(spacing: 12) {
            // NEW: History button
            PromptHistoryMenu(history: history) { prompt in
                state.prompt = prompt
            }

            // Existing: Prompt input
            TextField("Describe your logo...", text: $state.prompt)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if state.canGenerate {
                        onGenerate()
                    }
                }

            // ... rest unchanged ...
        }
        .padding()
        .background(.bar)
        .onAppear {
            loadHistory()
        }
    }

    private func loadHistory() {
        history = historyService?.getGlobalHistory(limit: 20) ?? []
    }
}
```

#### `Views/Screens/workspace-view.swift`

Record prompt on generation:

```swift
// In generate() function, after successful generation:

private func generate() async {
    // ... existing generation code ...

    // After success, record to history
    if generationState.status == .completed {
        promptHistoryService?.record(
            prompt: prompt,
            style: style,
            model: model,
            projectID: selectedProjectID
        )
    }
}
```

### Testing Checkpoint

**Build & Test:**
1. Generate a logo with any prompt
2. Click clock icon in prompt bar - should show your prompt
3. Generate again with different prompt
4. History should show both, most recent first
5. Click a history entry - should fill prompt field
6. Close and reopen app - history should persist
7. Check that duplicates aren't stored

---

## Phase 3: Color Palette Extraction

**Goal:** Extract dominant colors from generated logos.

**Scope:** Pure Swift, no API cost. Updates when variation selected.

### Files to Create

#### `Models/color-palette.swift`

```swift
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
```

#### `Services/color-extraction-service.swift`

```swift
import AppKit
import SwiftUI

protocol ColorExtractionServiceProtocol {
    func extract(from image: NSImage, maxColors: Int) -> ColorPalette
}

final class ColorExtractionService: ColorExtractionServiceProtocol {

    /// Extract dominant colors using k-means clustering
    func extract(from image: NSImage, maxColors: Int = 6) -> ColorPalette {
        guard let pixels = getPixels(from: image) else {
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
              let bitmap = NSBitmapImageRep(data: tiffData) else {
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
```

#### `Views/Components/color-palette-strip.swift`

```swift
import SwiftUI

struct ColorPaletteStrip: View {
    let palette: ColorPalette?

    @State private var copiedColorID: UUID?

    var body: some View {
        if let palette, !palette.colors.isEmpty {
            HStack(spacing: 16) {
                // Label
                Text("PALETTE")
                    .font(LogoForgeTheme.body(11, weight: .medium))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
                    .tracking(1.5)

                // Color swatches
                HStack(spacing: 8) {
                    ForEach(Array(palette.colors.enumerated()), id: \.element.id) { index, color in
                        ColorSwatch(
                            color: color,
                            isCopied: copiedColorID == color.id
                        ) {
                            copyToClipboard(color.hex)
                            showCopiedFeedback(for: color.id)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .animation(
                            LogoForgeTheme.stagger(index: index),
                            value: palette.id
                        )
                    }
                }

                Spacer()

                // Copy all button
                Button {
                    let allHex = palette.colors.map(\.hex).joined(separator: ", ")
                    copyToClipboard(allHex)
                } label: {
                    Text("Copy All")
                        .font(LogoForgeTheme.body(12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(LogoForgeTheme.canvas)
        }
    }

    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private func showCopiedFeedback(for id: UUID) {
        copiedColorID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedColorID == id {
                copiedColorID = nil
            }
        }
    }
}

struct ColorSwatch: View {
    let color: ExtractedColor
    let isCopied: Bool
    var onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.color)
                    .frame(width: 24, height: 24)
                    .shadow(
                        color: .black.opacity(0.2),
                        radius: isHovered ? 4 : 2,
                        y: isHovered ? 2 : 1
                    )

                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .animation(LogoForgeTheme.quickEase, value: isHovered)
        .onHover { isHovered = $0 }
        .help(color.hex)
    }
}
```

### Files to Modify

#### `Utilities/environment-keys.swift`

```swift
extension EnvironmentValues {
    // ... existing keys ...

    @Entry var colorExtractionService: ColorExtractionServiceProtocol = ColorExtractionService()
}
```

#### `Views/Screens/workspace-view.swift`

Add palette state and extraction:

```swift
struct WorkspaceView: View {
    // ... existing state ...

    @State private var colorPalette: ColorPalette?  // NEW
    @Environment(\.colorExtractionService) private var colorExtractionService  // NEW

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HeroArea(...)

                // Variation strip
                if !generationState.variations.isEmpty {
                    VariationStrip(...)
                }

                // NEW: Color palette strip
                ColorPaletteStrip(palette: colorPalette)

                // ... rest unchanged ...
            }
        }
        // ... existing modifiers ...

        // NEW: Extract colors when selection changes
        .onChange(of: generationState.selectedVariationID) { _, newID in
            // ... existing code ...

            // Extract colors from selected variation
            if let variation = generationState.variations.first(where: { $0.id == newID }) {
                colorPalette = colorExtractionService.extract(from: variation.image)
            } else {
                colorPalette = nil
            }
        }
    }
}
```

### Testing Checkpoint

**Build & Test:**
1. Generate a logo with distinct colors
2. Color palette strip should appear below variations
3. Should show 4-6 dominant colors
4. Hover on swatch - should show hex code tooltip
5. Click swatch - should copy hex to clipboard
6. Click "Copy All" - should copy all hex codes
7. Switch variations - palette should update
8. Test with colorful vs monochrome logos

---

## Phase 4: Prompt Suggestions

**Goal:** AI-powered prompt improvements via Replicate LLM.

**Scope:** On-demand "Improve" button in PromptBar.

### Files to Create

#### `Services/prompt-suggestion-service.swift`

```swift
import Foundation

protocol PromptSuggestionServiceProtocol: Sendable {
    func suggest(prompt: String, style: Style, count: Int) async throws -> [String]
    var costPerRequest: Decimal { get }
}

final class PromptSuggestionService: PromptSuggestionServiceProtocol, Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let replicateModel = "meta/meta-llama-3-8b-instruct"
    private let keychainService: KeychainService

    let costPerRequest: Decimal = 0.002

    private let pollInterval: Duration = .seconds(1)
    private let maxWaitTime: Duration = .seconds(30)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    func suggest(prompt: String, style: Style, count: Int = 3) async throws -> [String] {
        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        let systemPrompt = """
        You are an expert logo designer. Improve the user's logo prompt to be more specific and effective.

        Guidelines:
        - Add specific visual details (shapes, symbols, composition)
        - Suggest color themes if not specified
        - Include style keywords that work well for logo generation
        - Keep prompts concise (under 50 words)
        - The style is: \(style.rawValue)

        Return exactly \(count) improved prompts, one per line. No numbering, no explanations.
        """

        let userPrompt = "Improve this logo prompt: \"\(prompt)\""

        // Create prediction
        let predictionID = try await createPrediction(
            system: systemPrompt,
            user: userPrompt,
            apiKey: apiKey
        )

        // Poll for completion
        let output = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Parse output into array
        let suggestions = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(count)

        return Array(suggestions)
    }

    // MARK: - Private

    private func createPrediction(system: String, user: String, apiKey: String) async throws -> String {
        let url = baseURL.appending(path: "models/\(replicateModel)/predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": [
                "prompt": user,
                "system_prompt": system,
                "max_tokens": 500,
                "temperature": 0.7
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)
            return prediction.id
        case 401:
            throw AppError.invalidAPIKey
        case 429:
            throw AppError.rateLimited(retryAfter: 30)
        default:
            throw AppError.generationFailed("Suggestion failed: HTTP \(httpResponse.statusCode)")
        }
    }

    private func pollForCompletion(predictionID: String, apiKey: String) async throws -> String {
        let url = baseURL.appending(path: "predictions/\(predictionID)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let startTime = Date()

        while true {
            if Date().timeIntervalSince(startTime) > Double(maxWaitTime.components.seconds) {
                throw AppError.generationFailed("Suggestion timed out")
            }

            try await Task.sleep(for: pollInterval)

            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(LLMPrediction.self, from: data)

            switch prediction.status {
            case "succeeded":
                // LLM output is an array of strings, join them
                return prediction.output?.joined() ?? ""
            case "failed":
                throw AppError.generationFailed(prediction.error ?? "Suggestion failed")
            case "canceled":
                throw AppError.generationFailed("Suggestion was canceled")
            default:
                continue  // Still processing
            }
        }
    }
}

// MARK: - LLM Response Model

private struct LLMPrediction: Decodable {
    let id: String
    let status: String
    let output: [String]?
    let error: String?
}
```

#### `Views/Components/prompt-suggestions.swift`

```swift
import SwiftUI

struct PromptSuggestionsButton: View {
    let currentPrompt: String
    let style: Style
    var onSelect: (String) -> Void

    @Environment(\.promptSuggestionService) private var service

    @State private var isLoading = false
    @State private var suggestions: [String] = []
    @State private var isOpen = false
    @State private var error: String?

    var body: some View {
        Button {
            Task { await loadSuggestions() }
        } label: {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                }
                Text("Improve")
            }
        }
        .buttonStyle(.bordered)
        .disabled(currentPrompt.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        .help("Get AI-powered prompt suggestions (~$0.002)")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            SuggestionsPopover(
                suggestions: suggestions,
                error: error,
                onSelect: { suggestion in
                    onSelect(suggestion)
                    isOpen = false
                },
                onKeepOriginal: { isOpen = false }
            )
        }
    }

    private func loadSuggestions() async {
        isLoading = true
        error = nil

        do {
            suggestions = try await service.suggest(
                prompt: currentPrompt,
                style: style,
                count: 3
            )
            isOpen = true
        } catch {
            self.error = error.localizedDescription
            isOpen = true
        }

        isLoading = false
    }
}

private struct SuggestionsPopover: View {
    let suggestions: [String]
    let error: String?
    var onSelect: (String) -> Void
    var onKeepOriginal: () -> Void

    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SUGGESTIONS")
                    .font(LogoForgeTheme.body(11, weight: .medium))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
                    .tracking(1.5)

                Spacer()

                Text("~$0.002")
                    .font(LogoForgeTheme.body(10))
                    .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if let error {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(LogoForgeTheme.error)
                    Text(error)
                        .font(LogoForgeTheme.body(12))
                        .foregroundStyle(LogoForgeTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                // Suggestions list
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: selectedIndex == index
                        ) {
                            selectedIndex = index
                            onSelect(suggestion)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(
                            .easeOut(duration: 0.2).delay(Double(index) * 0.1),
                            value: suggestions
                        )
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Keep Original", action: onKeepOriginal)
                    .buttonStyle(.borderless)
                    .foregroundStyle(LogoForgeTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(LogoForgeTheme.surface)
    }
}

private struct SuggestionRow: View {
    let suggestion: String
    let isSelected: Bool
    var onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? LogoForgeTheme.success : LogoForgeTheme.textSecondary)
                    .font(.system(size: 14))

                Text(suggestion)
                    .font(LogoForgeTheme.body(13))
                    .foregroundStyle(LogoForgeTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? LogoForgeTheme.hover : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
```

### Files to Modify

#### `Utilities/environment-keys.swift`

```swift
extension EnvironmentValues {
    // ... existing keys ...

    @Entry var promptSuggestionService: PromptSuggestionServiceProtocol = PromptSuggestionService()
}
```

#### `Views/Components/prompt-bar.swift`

Add improve button:

```swift
struct PromptBar: View {
    @Bindable var state: GenerationState
    var onGenerate: () -> Void

    // ... existing environment/state ...

    var body: some View {
        HStack(spacing: 12) {
            // History button
            PromptHistoryMenu(history: history) { prompt in
                state.prompt = prompt
            }

            // Prompt input
            TextField("Describe your logo...", text: $state.prompt)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if state.canGenerate {
                        onGenerate()
                    }
                }

            // NEW: Improve button
            PromptSuggestionsButton(
                currentPrompt: state.prompt,
                style: state.selectedStyle
            ) { improved in
                state.prompt = improved
            }

            // Style picker
            StylePicker(selection: $state.selectedStyle)

            // ... rest unchanged ...
        }
        .padding()
        .background(.bar)
    }
}
```

### Testing Checkpoint

**Build & Test:**
1. Type a simple prompt like "mountain logo"
2. Click "Improve" button
3. Should show loading spinner briefly
4. Popover appears with 3 suggestions
5. Click a suggestion - prompt field updates
6. Click "Keep Original" - popover closes, no change
7. Test with empty prompt - button should be disabled
8. Test error handling (disconnect network)

---

## Phase 5: AI Inpainting

**Goal:** Edit specific regions of logo without full regeneration.

**Scope:** Brush-based masking, model selection (Ideogram/Flux).

### Files to Create

#### Update `Models/ai-model.swift`

Add Flux Fill Pro and capabilities:

```swift
enum AIModel: String, CaseIterable, Identifiable, Codable {
    case ideogramV3 = "Ideogram v3"
    case nanaBananaPro = "Nano Banana Pro"
    case fluxFillPro = "Flux Fill Pro"

    var id: String { rawValue }

    var replicateModel: String {
        switch self {
        case .ideogramV3: return "ideogram-ai/ideogram-v3-balanced"
        case .nanaBananaPro: return "google/nano-banana-pro"
        case .fluxFillPro: return "black-forest-labs/flux-fill-pro"
        }
    }

    var costPerImage: Decimal {
        switch self {
        case .ideogramV3: return 0.08
        case .nanaBananaPro: return 0.15
        case .fluxFillPro: return 0.05
        }
    }

    var supportsGeneration: Bool {
        switch self {
        case .ideogramV3, .nanaBananaPro: return true
        case .fluxFillPro: return false
        }
    }

    var supportsInpainting: Bool {
        switch self {
        case .ideogramV3, .fluxFillPro: return true
        case .nanaBananaPro: return false
        }
    }

    var shortLabel: String {
        switch self {
        case .ideogramV3: return "Text"
        case .nanaBananaPro: return "Abstract"
        case .fluxFillPro: return "Flux"
        }
    }

    var inpaintDescription: String {
        switch self {
        case .ideogramV3: return "Best for text edits"
        case .fluxFillPro: return "Best for seamless blending"
        case .nanaBananaPro: return ""
        }
    }

    static var generationModels: [AIModel] {
        allCases.filter { $0.supportsGeneration }
    }

    static var inpaintingModels: [AIModel] {
        allCases.filter { $0.supportsInpainting }
    }
}
```

#### `Services/inpainting-service.swift`

```swift
import Foundation
import AppKit

protocol InpaintingServiceProtocol: Sendable {
    func inpaint(
        image: NSImage,
        mask: NSImage,
        prompt: String,
        model: AIModel
    ) async throws -> NSImage
}

final class InpaintingService: InpaintingServiceProtocol, Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let keychainService: KeychainService

    private let pollInterval: Duration = .seconds(2)
    private let maxWaitTime: Duration = .seconds(120)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    func inpaint(
        image: NSImage,
        mask: NSImage,
        prompt: String,
        model: AIModel
    ) async throws -> NSImage {
        guard model.supportsInpainting else {
            throw AppError.generationFailed("Model doesn't support inpainting")
        }

        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        // Convert images to base64
        guard let imageData = imageToBase64PNG(image),
              let maskData = imageToBase64PNG(mask) else {
            throw AppError.generationFailed("Failed to encode images")
        }

        // Create prediction based on model
        let predictionID = try await createPrediction(
            imageData: imageData,
            maskData: maskData,
            prompt: prompt,
            model: model,
            apiKey: apiKey
        )

        // Poll for completion
        let resultURL = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Download result
        return try await downloadImage(from: resultURL)
    }

    // MARK: - Private

    private func imageToBase64PNG(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return "data:image/png;base64," + pngData.base64EncodedString()
    }

    private func createPrediction(
        imageData: String,
        maskData: String,
        prompt: String,
        model: AIModel,
        apiKey: String
    ) async throws -> String {
        let url = baseURL.appending(path: "models/\(model.replicateModel)/predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build input based on model
        let input: [String: Any]

        switch model {
        case .ideogramV3:
            input = [
                "prompt": prompt,
                "image": imageData,
                "mask": maskData,
                "magic_prompt_option": "AUTO"
            ]
        case .fluxFillPro:
            input = [
                "prompt": prompt,
                "image": imageData,
                "mask": maskData
            ]
        default:
            throw AppError.generationFailed("Unsupported inpainting model")
        }

        let body: [String: Any] = ["input": input]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)
            return prediction.id
        case 401:
            throw AppError.invalidAPIKey
        case 429:
            throw AppError.rateLimited(retryAfter: 30)
        default:
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.generationFailed("Inpainting failed: \(responseString)")
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
            let prediction = try JSONDecoder().decode(ReplicatePrediction.self, from: data)

            switch prediction.status {
            case .succeeded:
                guard let urlString = prediction.output,
                      let url = URL(string: urlString) else {
                    throw AppError.generationFailed("No output URL from inpainting")
                }
                return url
            case .failed:
                throw AppError.generationFailed(prediction.error ?? "Inpainting failed")
            case .canceled:
                throw AppError.generationFailed("Inpainting was canceled")
            case .starting, .processing:
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
            throw AppError.generationFailed("Invalid inpainted image data")
        }

        return image
    }
}
```

#### `Views/Components/mask-canvas.swift`

```swift
import SwiftUI

struct MaskCanvas: View {
    let sourceImage: NSImage
    @Binding var brushSize: CGFloat
    @Binding var isErasing: Bool

    var onMaskUpdated: (NSImage?) -> Void

    @State private var paths: [MaskPath] = []
    @State private var currentPath: [CGPoint] = []
    @State private var imageFrame: CGRect = .zero

    private struct MaskPath {
        let points: [CGPoint]
        let isErasing: Bool
        let brushSize: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Source image
                Image(nsImage: sourceImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(
                        GeometryReader { imgGeo in
                            Color.clear.onAppear {
                                imageFrame = imgGeo.frame(in: .local)
                            }
                        }
                    )

                // Mask overlay
                Canvas { context, size in
                    // Draw all completed paths
                    for path in paths {
                        drawPath(path, in: &context)
                    }

                    // Draw current path
                    if !currentPath.isEmpty {
                        let current = MaskPath(
                            points: currentPath,
                            isErasing: isErasing,
                            brushSize: brushSize
                        )
                        drawPath(current, in: &context)
                    }
                }
                .allowsHitTesting(false)

                // Gesture capture layer
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                currentPath.append(value.location)
                            }
                            .onEnded { _ in
                                if !currentPath.isEmpty {
                                    paths.append(MaskPath(
                                        points: currentPath,
                                        isErasing: isErasing,
                                        brushSize: brushSize
                                    ))
                                    currentPath = []
                                    onMaskUpdated(renderMaskImage(size: geo.size))
                                }
                            }
                    )

                // Brush cursor
                BrushCursor(size: brushSize, isErasing: isErasing)
            }
        }
    }

    private func drawPath(_ path: MaskPath, in context: inout GraphicsContext) {
        guard path.points.count > 1 else { return }

        var bezier = Path()
        bezier.move(to: path.points[0])

        for point in path.points.dropFirst() {
            bezier.addLine(to: point)
        }

        let color: Color = path.isErasing ? .black : LogoForgeTheme.error.opacity(0.5)

        context.stroke(
            bezier,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: path.brushSize,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func renderMaskImage(size: CGSize) -> NSImage {
        let maskImage = NSImage(size: size)
        maskImage.lockFocus()

        // Fill with black (keep)
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Draw paths in white (edit region) or black (erased)
        for path in paths {
            let bezier = NSBezierPath()
            guard let first = path.points.first else { continue }

            bezier.move(to: first)
            for point in path.points.dropFirst() {
                bezier.line(to: point)
            }

            bezier.lineWidth = path.brushSize
            bezier.lineCapStyle = .round
            bezier.lineJoinStyle = .round

            if path.isErasing {
                NSColor.black.setStroke()
            } else {
                NSColor.white.setStroke()
            }

            bezier.stroke()
        }

        maskImage.unlockFocus()
        return maskImage
    }

    func clear() {
        paths = []
        currentPath = []
        onMaskUpdated(nil)
    }
}

struct BrushCursor: View {
    let size: CGFloat
    let isErasing: Bool

    @State private var position: CGPoint = .zero

    var body: some View {
        Circle()
            .stroke(isErasing ? Color.white : LogoForgeTheme.error, lineWidth: 1.5)
            .frame(width: size, height: size)
            .position(position)
            .allowsHitTesting(false)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    position = location
                case .ended:
                    break
                }
            }
    }
}
```

#### `Views/Components/inpaint-toolbar.swift`

```swift
import SwiftUI

struct InpaintToolbar: View {
    @Binding var brushSize: CGFloat
    @Binding var isErasing: Bool
    @Binding var selectedModel: AIModel
    @Binding var prompt: String

    let isProcessing: Bool
    var onClear: () -> Void
    var onCancel: () -> Void
    var onInpaint: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Top row: Tools
            HStack(spacing: 16) {
                // Brush/Eraser toggle
                Picker("Tool", selection: $isErasing) {
                    Label("Brush", systemImage: "paintbrush.fill").tag(false)
                    Label("Eraser", systemImage: "eraser.fill").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)

                Divider().frame(height: 24)

                // Brush size
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.system(size: 8))

                    Slider(value: $brushSize, in: 4...100)
                        .frame(width: 120)

                    Image(systemName: "circle.fill")
                        .font(.system(size: 14))

                    Text("\(Int(brushSize))px")
                        .font(LogoForgeTheme.body(12))
                        .foregroundStyle(LogoForgeTheme.textSecondary)
                        .monospacedDigit()
                        .frame(width: 40)
                }

                Divider().frame(height: 24)

                Button("Clear Mask", action: onClear)
                    .buttonStyle(.bordered)

                Spacer()
            }

            Divider()

            // Bottom row: Model + Prompt + Actions
            HStack(spacing: 16) {
                // Model picker
                HStack(spacing: 8) {
                    Text("Model:")
                        .font(LogoForgeTheme.body(13))
                        .foregroundStyle(LogoForgeTheme.textSecondary)

                    Picker("", selection: $selectedModel) {
                        ForEach(AIModel.inpaintingModels) { model in
                            Text(model.shortLabel).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                Divider().frame(height: 24)

                // Prompt
                TextField("Describe what should appear...", text: $prompt)
                    .textFieldStyle(.roundedBorder)

                // Cost indicator
                Text("~$\(selectedModel.costPerImage)")
                    .font(LogoForgeTheme.body(11))
                    .foregroundStyle(LogoForgeTheme.textSecondary)

                // Actions
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Button {
                    onInpaint()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Inpaint")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(prompt.isEmpty || isProcessing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(LogoForgeTheme.surface)
    }
}
```

#### `Views/Components/inpaint-mode-view.swift`

```swift
import SwiftUI

struct InpaintModeView: View {
    let sourceImage: NSImage
    var onComplete: (NSImage) -> Void
    var onCancel: () -> Void

    @Environment(\.inpaintingService) private var inpaintingService

    @State private var brushSize: CGFloat = 24
    @State private var isErasing = false
    @State private var selectedModel: AIModel = .ideogramV3
    @State private var prompt = ""
    @State private var mask: NSImage?
    @State private var isProcessing = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Inpaint Mode")
                    .font(LogoForgeTheme.body(14, weight: .medium))
                    .foregroundStyle(LogoForgeTheme.textPrimary)

                Spacer()

                Text("Paint over the area you want to edit")
                    .font(LogoForgeTheme.body(12))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(LogoForgeTheme.surface)

            Divider()

            // Canvas area
            MaskCanvas(
                sourceImage: sourceImage,
                brushSize: $brushSize,
                isErasing: $isErasing
            ) { updatedMask in
                mask = updatedMask
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LogoForgeTheme.canvas)

            // Error display
            if let error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(LogoForgeTheme.error)
                    Text(error)
                        .font(LogoForgeTheme.body(12))
                        .foregroundStyle(LogoForgeTheme.error)
                    Spacer()
                    Button("Dismiss") { self.error = nil }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(LogoForgeTheme.error.opacity(0.1))
            }

            Divider()

            // Toolbar
            InpaintToolbar(
                brushSize: $brushSize,
                isErasing: $isErasing,
                selectedModel: $selectedModel,
                prompt: $prompt,
                isProcessing: isProcessing,
                onClear: clearMask,
                onCancel: onCancel,
                onInpaint: performInpaint
            )
        }
    }

    private func clearMask() {
        mask = nil
        // Note: Need to add a way to clear MaskCanvas paths
    }

    private func performInpaint() {
        guard let mask else {
            error = "Please paint the area you want to edit"
            return
        }

        isProcessing = true
        error = nil

        Task {
            do {
                let result = try await inpaintingService.inpaint(
                    image: sourceImage,
                    mask: mask,
                    prompt: prompt,
                    model: selectedModel
                )

                await MainActor.run {
                    isProcessing = false
                    onComplete(result)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}
```

### Files to Modify

#### `Utilities/environment-keys.swift`

```swift
extension EnvironmentValues {
    // ... existing keys ...

    @Entry var inpaintingService: InpaintingServiceProtocol = InpaintingService()
}
```

#### `Views/Components/editor-panel.swift`

Add inpaint button to AI Tools section:

```swift
private struct AIToolsSection: View {
    // ... existing props ...
    var onInpaint: () -> Void  // NEW

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Tools")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Existing: Remove Background button
            Button(action: onRemove) { ... }

            // NEW: Inpaint button
            Button(action: onInpaint) {
                HStack(spacing: 6) {
                    Image(systemName: "paintbrush.pointed.fill")
                    Text("Inpaint Region")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .help("Edit specific parts of the logo (~$0.05-0.08)")
        }
    }
}
```

#### `Views/Screens/workspace-view.swift`

Add inpaint mode:

```swift
struct WorkspaceView: View {
    // ... existing state ...

    @State private var isInpaintMode = false  // NEW

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // NEW: Conditional hero vs inpaint mode
                if isInpaintMode, let variation = selectedVariation {
                    InpaintModeView(
                        sourceImage: variation.image,
                        onComplete: { newImage in
                            handleInpaintComplete(newImage)
                        },
                        onCancel: { isInpaintMode = false }
                    )
                } else {
                    // Existing hero area
                    HeroArea(...)

                    // ... variation strip, palette, etc ...
                }

                // Only show prompt bar when not inpainting
                if !isInpaintMode {
                    PromptBar(...)
                    ExportBar(...)
                }
            }

            // Only show editor when not inpainting
            if selectedVariation != nil && !isInpaintMode {
                EditorPanel(
                    // ... existing props ...
                    onInpaint: { isInpaintMode = true }  // NEW
                )
            }
        }
    }

    // NEW: Handle inpaint result
    private func handleInpaintComplete(_ newImage: NSImage) {
        guard let variationID = generationState.selectedVariationID,
              let index = generationState.variations.firstIndex(where: { $0.id == variationID }) else {
            isInpaintMode = false
            return
        }

        // Replace variation with inpainted result
        let variation = generationState.variations[index]
        let newVariation = GeneratedVariation(
            image: newImage,
            prompt: variation.prompt,
            style: variation.style
        )

        generationState.variations[index] = newVariation
        generationState.selectedVariationID = newVariation.id

        // Update color palette
        colorPalette = colorExtractionService.extract(from: newImage)

        // Save to project if exists
        if let project = currentProject {
            do {
                let imagePath = try projectService.saveImage(newImage, to: project, index: index)
                if index < project.variations.count {
                    project.variations[index].imagePath = imagePath
                }
                project.updatedAt = Date()
            } catch {
                print("Failed to save inpainted variation: \(error)")
            }
        }

        isInpaintMode = false
    }
}
```

### Testing Checkpoint

**Build & Test:**
1. Generate a logo
2. Select a variation
3. In Editor panel, click "Inpaint Region"
4. UI should switch to inpaint mode
5. Paint over an area (e.g., text part of logo)
6. Adjust brush size with slider
7. Toggle eraser to remove parts of mask
8. Switch between Ideogram and Flux models
9. Enter prompt like "a golden crown"
10. Click Inpaint - should process and update logo
11. Cancel should return to normal view
12. Test error handling (empty mask, empty prompt)

---

## Summary

### New Files (13)

| File | Phase | Purpose |
|------|-------|---------|
| `Models/edit-history.swift` | 1 | Undo/redo stack |
| `Views/Components/undo-redo-controls.swift` | 1 | Undo/redo buttons |
| `Models/prompt-history.swift` | 2 | SwiftData models |
| `Services/prompt-history-service.swift` | 2 | History persistence |
| `Views/Components/prompt-history-menu.swift` | 2 | History popover |
| `Models/color-palette.swift` | 3 | Extracted color types |
| `Services/color-extraction-service.swift` | 3 | K-means extraction |
| `Views/Components/color-palette-strip.swift` | 3 | Palette display |
| `Services/prompt-suggestion-service.swift` | 4 | Replicate LLM |
| `Views/Components/prompt-suggestions.swift` | 4 | Improve button |
| `Services/inpainting-service.swift` | 5 | Replicate inpainting |
| `Views/Components/mask-canvas.swift` | 5 | Brush drawing |
| `Views/Components/inpaint-toolbar.swift` | 5 | Inpaint controls |
| `Views/Components/inpaint-mode-view.swift` | 5 | Full inpaint UI |

### Modified Files (7)

| File | Phases | Changes |
|------|--------|---------|
| `Models/ai-model.swift` | 5 | Add Flux, capabilities |
| `Models/editor-state.swift` | 1 | Snapshot methods |
| `Views/Components/editor-panel.swift` | 1, 5 | Undo/redo, inpaint button |
| `Views/Components/prompt-bar.swift` | 2, 4 | History, improve button |
| `Views/Screens/workspace-view.swift` | 1-5 | All integrations |
| `Utilities/environment-keys.swift` | 2-5 | New service keys |
| `logo_forgeApp.swift` | 2 | SwiftData models |

### Cost Summary

| Feature | API Cost |
|---------|----------|
| Undo/Redo | Free (local) |
| Prompt History | Free (local) |
| Color Palette | Free (local) |
| Prompt Suggestions | ~$0.002/request |
| Inpainting (Ideogram) | ~$0.08/image |
| Inpainting (Flux) | ~$0.05/image |

---

*Plan created: 2026-01-02*
