import SwiftUI
import SwiftData

// MARK: - Workspace View

struct WorkspaceView: View {
    @Binding var selectedProjectID: UUID?

    @Environment(AppState.self) private var appState
    @Environment(\.replicateService) private var replicateService
    @Environment(\.projectService) private var projectService
    @Environment(\.backgroundRemovalService) private var backgroundRemovalService
    @Environment(\.modelContext) private var modelContext

    @Query private var projects: [Project]

    @State private var generationState = GenerationState()
    @State private var editorState = EditorState()
    @State private var editHistory = EditHistory()
    @State private var colorPalette: ColorPalette?
    @State private var showExportSheet = false
    @State private var exportOptions = ExportOptions()
    @State private var isInpaintMode = false

    private let colorExtractionService = ColorExtractionService()

    /// Currently loaded project (if any)
    private var currentProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return projects.first { $0.id == id }
    }

    /// Currently selected variation
    private var selectedVariation: GeneratedVariation? {
        guard let id = generationState.selectedVariationID else { return nil }
        return generationState.variations.first { $0.id == id }
    }

    /// Is currently generating
    private var isGenerating: Bool {
        switch generationState.status {
        case .generating, .preparing:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Main content area - new hero-focused layout
                VStack(spacing: 0) {
                    // Hero area - the logo takes center stage
                    HeroArea(
                        image: selectedVariation?.image,
                        editorState: editorState,
                        isGenerating: isGenerating,
                        progress: generationState.status
                    )
                    .frame(minHeight: 300)

                    // Variation strip - horizontal thumbnails
                    if !generationState.variations.isEmpty {
                        Divider()
                            .background(LogoForgeTheme.border)

                        VariationStrip(
                            variations: generationState.variations,
                            selectedID: $generationState.selectedVariationID
                        ) { variationID in
                            Task { await regenerateSingle(variationID) }
                        }
                        .frame(height: 140)

                        // Color palette strip
                        ColorPaletteStrip(palette: colorPalette)
                    }

                    Divider()
                        .background(LogoForgeTheme.border)

                    // Reference images (collapsible)
                    if !generationState.referenceImages.isEmpty {
                        ReferenceImagesBar(images: $generationState.referenceImages)
                            .padding(.horizontal)
                            .padding(.vertical, 8)

                        Divider()
                            .background(LogoForgeTheme.border)
                    }

                    // Prompt bar - bottom anchored, command-line feel
                    PromptBar(state: generationState) {
                        Task { await generate() }
                    }
                    .background(LogoForgeTheme.canvas)

                    Divider()
                        .background(LogoForgeTheme.border)

                    // Export bar
                    ExportBar(selectedImage: selectedVariation?.image)
                }
                .background(LogoForgeTheme.canvas)

                // Editor panel (shown when variation selected)
                if selectedVariation != nil {
                    Divider()
                        .background(LogoForgeTheme.border)

                    EditorPanel(
                        state: editorState,
                        history: editHistory,
                        onApply: applyEdits,
                        onReset: { editorState.reset() },
                        onRemoveBackground: removeBackground,
                        onInpaint: { isInpaintMode = true }
                    )
                }
            }
            .background(LogoForgeTheme.canvas)

            // Inpaint mode overlay
            if isInpaintMode, let image = selectedVariation?.image {
                InpaintModeView(
                    sourceImage: image,
                    onComplete: { result in
                        handleInpaintResult(result)
                        isInpaintMode = false
                    },
                    onCancel: {
                        isInpaintMode = false
                    }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: selectedProjectID) { _, newID in
            if let newID, let project = projects.first(where: { $0.id == newID }) {
                loadProject(project)
            }
        }
        .onChange(of: generationState.selectedVariationID) { _, newID in
            // When selection changes, load image into editor
            if let newID,
               let variation = generationState.variations.first(where: { $0.id == newID }) {
                editorState.loadImage(variation.image)
                // Extract color palette from selected variation
                colorPalette = colorExtractionService.extract(from: variation.image)
            } else {
                colorPalette = nil
            }
            // Clear undo/redo history for new image
            editHistory.clear()
        }
    }

    // MARK: - Editor Actions

    private func applyEdits() {
        guard let variationID = generationState.selectedVariationID,
              let index = generationState.variations.firstIndex(where: { $0.id == variationID }),
              let originalImage = editorState.originalImage else {
            return
        }

        // Apply edits to create new image
        let editedImage = ImageProcessor.process(originalImage, with: editorState)

        // Update the variation with the edited image
        let variation = generationState.variations[index]
        let newVariation = GeneratedVariation(
            image: editedImage,
            prompt: variation.prompt,
            style: variation.style
        )
        generationState.variations[index] = newVariation
        generationState.selectedVariationID = newVariation.id

        // Save to disk if we have a project
        if let project = currentProject {
            do {
                let imagePath = try projectService.saveImage(editedImage, to: project, index: index)
                if index < project.variations.count {
                    project.variations[index].imagePath = imagePath
                }
                project.updatedAt = Date()
            } catch {
                print("Failed to save edited variation: \(error)")
            }
        }

        // Reset editor state (the edited image becomes the new original)
        editorState.loadImage(editedImage)
    }

    // MARK: - Background Removal

    private func removeBackground() async throws {
        guard let variationID = generationState.selectedVariationID,
              generationState.variations.first(where: { $0.id == variationID }) != nil,
              let originalImage = editorState.originalImage else {
            return
        }

        // Call the AI background removal service
        let processedImage = try await backgroundRemovalService.removeBackground(from: originalImage)

        // Create new variation (preserve original)
        let newVariation = GeneratedVariation(
            image: processedImage,
            prompt: generationState.prompt,
            style: generationState.selectedStyle
        )

        await MainActor.run {
            // Append as new variation instead of replacing
            generationState.variations.append(newVariation)
            generationState.selectedVariationID = newVariation.id

            // Save to disk if we have a project
            if let project = currentProject {
                do {
                    let newIndex = project.variations.count
                    let imagePath = try projectService.saveImage(processedImage, to: project, index: newIndex)
                    let savedVariation = SavedVariation(imagePath: imagePath)
                    savedVariation.project = project
                    project.variations.append(savedVariation)
                    project.updatedAt = Date()
                } catch {
                    print("Failed to save background-removed variation: \(error)")
                }
            }

            // Update editor with the new image
            editorState.loadImage(processedImage)
        }
    }

    // MARK: - Inpaint Result Handler

    private func handleInpaintResult(_ result: NSImage) {
        guard generationState.selectedVariationID != nil else {
            return
        }

        // Create new variation with inpainted image (preserve original)
        let newVariation = GeneratedVariation(
            image: result,
            prompt: generationState.prompt,
            style: generationState.selectedStyle
        )

        // Append as new variation instead of replacing
        generationState.variations.append(newVariation)
        generationState.selectedVariationID = newVariation.id

        // Save to disk if we have a project
        if let project = currentProject {
            do {
                let newIndex = project.variations.count
                let imagePath = try projectService.saveImage(result, to: project, index: newIndex)
                let savedVariation = SavedVariation(imagePath: imagePath)
                savedVariation.project = project
                project.variations.append(savedVariation)
                project.updatedAt = Date()
            } catch {
                print("Failed to save inpainted variation: \(error)")
            }
        }

        // Update editor with the new image
        editorState.loadImage(result)

        // Extract new color palette
        colorPalette = colorExtractionService.extract(from: result)
    }

    // MARK: - Project Loading

    private func loadProject(_ project: Project) {
        generationState.prompt = project.prompt
        generationState.selectedStyle = project.style
        generationState.selectedModel = project.model
        generationState.status = .idle
        generationState.error = nil

        // Load saved variations from disk
        let images = projectService.loadAllImages(for: project)
        generationState.variations = images.enumerated().map { index, image in
            GeneratedVariation(
                image: image,
                prompt: project.prompt,
                style: project.style
            )
        }

        if let first = generationState.variations.first {
            generationState.selectedVariationID = first.id
        } else {
            generationState.selectedVariationID = nil
        }
    }

    // MARK: - Generation Logic

    private func generate() async {
        generationState.status = .preparing
        generationState.error = nil
        // Keep existing variations when generating more in the same project
        let existingVariations = currentProject != nil ? generationState.variations : []

        let referenceData = prepareReferenceImages()
        let count = generationState.variationCount
        let prompt = generationState.prompt
        let style = generationState.selectedStyle
        let model = generationState.selectedModel

        generationState.status = .generating(completed: 0, total: count)

        do {
            let images = try await withThrowingTaskGroup(of: NSImage.self) { group in
                for _ in 0..<count {
                    group.addTask {
                        try await self.replicateService.generate(
                            prompt: prompt,
                            style: style,
                            references: referenceData,
                            model: model
                        )
                    }
                }

                var results: [NSImage] = []
                for try await image in group {
                    results.append(image)
                    await MainActor.run {
                        generationState.status = .generating(
                            completed: results.count,
                            total: count
                        )
                    }
                }
                return results
            }

            let newVariations = images.map { image in
                GeneratedVariation(
                    image: image,
                    prompt: prompt,
                    style: style
                )
            }
            // Append new variations to existing ones
            generationState.variations = existingVariations + newVariations
            generationState.status = .completed

            // Select the first new variation
            if let first = newVariations.first {
                generationState.selectedVariationID = first.id
            }

            // Record prompt to history
            let historyService = PromptHistoryService(modelContext: modelContext)
            historyService.record(
                prompt: prompt,
                style: style,
                model: model,
                projectID: selectedProjectID
            )

            // Auto-save to project
            await saveToProject(images: images, prompt: prompt, style: style, model: model)

        } catch let error as AppError {
            generationState.error = error
            generationState.status = .failed
        } catch {
            generationState.error = .generationFailed(error.localizedDescription)
            generationState.status = .failed
        }
    }

    // MARK: - Auto-Save

    private func saveToProject(images: [NSImage], prompt: String, style: Style, model: AIModel) async {
        await MainActor.run {
            let project: Project

            // Use existing project if selected, otherwise create new
            if let existingProject = currentProject {
                project = existingProject
                // Update project with new prompt/style/model
                project.prompt = prompt
                project.style = style
                project.model = model
                project.updatedAt = Date()
            } else {
                // Create new project
                let projectName = Project.nameFromPrompt(prompt)
                project = Project(name: projectName, prompt: prompt, style: style, model: model)
                modelContext.insert(project)
            }

            // Get starting index for new variations
            let startIndex = project.variations.count

            // Save images to disk and create SavedVariation records
            for (index, image) in images.enumerated() {
                do {
                    let imagePath = try projectService.saveImage(image, to: project, index: startIndex + index)
                    let variation = SavedVariation(imagePath: imagePath)
                    variation.project = project
                    project.variations.append(variation)
                } catch {
                    print("Failed to save variation \(index): \(error)")
                }
            }

            // Select the project
            selectedProjectID = project.id
        }
    }

    // MARK: - Regenerate Single

    private func regenerateSingle(_ variationID: UUID) async {
        guard let index = generationState.variations.firstIndex(where: { $0.id == variationID }) else {
            return
        }

        let referenceData = prepareReferenceImages()
        let prompt = generationState.prompt
        let style = generationState.selectedStyle
        let model = generationState.selectedModel

        do {
            let image = try await replicateService.generate(
                prompt: prompt,
                style: style,
                references: referenceData,
                model: model
            )

            let newVariation = GeneratedVariation(
                image: image,
                prompt: prompt,
                style: style
            )

            generationState.variations[index] = newVariation
            generationState.selectedVariationID = newVariation.id

            // Update saved variation on disk if we have a project
            if let project = currentProject {
                do {
                    let imagePath = try projectService.saveImage(image, to: project, index: index)
                    if index < project.variations.count {
                        project.variations[index].imagePath = imagePath
                    }
                    project.updatedAt = Date()
                } catch {
                    print("Failed to save regenerated variation: \(error)")
                }
            }

        } catch let error as AppError {
            appState.showToast(error.localizedDescription ?? "Regeneration failed")
        } catch {
            appState.showToast("Regeneration failed")
        }
    }

    // MARK: - Image Preparation

    private func prepareReferenceImages() -> [Data] {
        generationState.referenceImages.compactMap { image in
            let maxSize: CGFloat = 1024
            let resized = resizeImageIfNeeded(image, maxSize: maxSize)
            return resized.tiffRepresentation.flatMap { tiff in
                NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            }
        }
    }

    private func resizeImageIfNeeded(_ image: NSImage, maxSize: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > maxSize || size.height > maxSize else {
            return image
        }

        let scale = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }
}

// MARK: - Export Bar

struct ExportBar: View {
    let selectedImage: NSImage?

    @Environment(\.exportService) private var exportService

    @State private var selectedBundles: Set<ExportBundle> = [.iOS, .android]
    @State private var isExporting = false
    @State private var exportProgress: ExportProgress?
    @State private var showingSuccess = false
    @State private var exportedURL: URL?
    @State private var errorMessage: String?
    @State private var showingError = false

    private var canExport: Bool {
        selectedImage != nil && !selectedBundles.isEmpty && !isExporting
    }

    var body: some View {
        HStack(spacing: 16) {
            // Bundle toggles
            ForEach(ExportBundle.allCases) { bundle in
                Toggle(isOn: Binding(
                    get: { selectedBundles.contains(bundle) },
                    set: { isSelected in
                        if isSelected {
                            selectedBundles.insert(bundle)
                        } else {
                            selectedBundles.remove(bundle)
                        }
                    }
                )) {
                    Label(bundle.rawValue, systemImage: iconForBundle(bundle))
                        .labelStyle(.titleAndIcon)
                }
            }

            Spacer()

            // Progress or Export button
            if isExporting, let progress = exportProgress {
                HStack(spacing: 8) {
                    ProgressView(value: progress.percentage)
                        .frame(width: 100)

                    Text(progress.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if showingSuccess, let url = exportedURL {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                    }
                    .buttonStyle(.link)
                }
            } else {
                Button {
                    Task { await performExport() }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canExport)
            }
        }
        .toggleStyle(.checkbox)
        .padding()
        .background(.bar)
        .alert("Export Failed", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Export Logic

    private func performExport() async {
        print("🚀 performExport() called")
        print("   selectedImage: \(selectedImage != nil ? "exists (\(selectedImage!.size))" : "nil")")
        print("   selectedBundles: \(selectedBundles.map { $0.rawValue })")

        guard let image = selectedImage else {
            print("❌ No image selected - returning early")
            errorMessage = "No image selected. Please select a variation first."
            showingError = true
            return
        }

        print("✅ Image confirmed: \(image.size)")

        // Show save panel on main thread
        print("📂 Opening NSOpenPanel...")
        let destination: URL? = await MainActor.run {
            let panel = NSOpenPanel()
            panel.title = "Choose Export Location"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Export Here"

            let response = panel.runModal()
            print("   Panel response: \(response == .OK ? "OK" : "Cancel")")

            guard response == .OK else {
                print("   User cancelled panel")
                return nil
            }

            print("   Selected URL: \(panel.url?.path ?? "nil")")
            return panel.url
        }

        guard let destination else {
            print("❌ No destination selected - user cancelled")
            return
        }

        print("✅ Destination confirmed: \(destination.path)")
        print("🔄 Starting export...")

        isExporting = true
        showingSuccess = false
        exportedURL = nil
        errorMessage = nil

        do {
            print("   Calling exportService.export()...")
            let url = try await exportService.export(
                image: image,
                to: selectedBundles,
                destination: destination
            ) { progress in
                Task { @MainActor in
                    self.exportProgress = progress
                }
            }

            print("✅ Export completed successfully!")
            print("   Output folder: \(url.path)")

            isExporting = false
            exportedURL = url
            showingSuccess = true

            // Auto-hide success after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showingSuccess = false
            }

        } catch {
            print("❌ Export failed with error:")
            print("   \(error)")
            print("   Localized: \(error.localizedDescription)")

            isExporting = false
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func iconForBundle(_ bundle: ExportBundle) -> String {
        bundle.iconName
    }
}

#Preview {
    WorkspaceView(selectedProjectID: .constant(nil))
        .environment(AppState())
        .modelContainer(for: [Project.self, SavedVariation.self], inMemory: true)
}
