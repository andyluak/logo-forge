import SwiftUI
import SwiftData

// MARK: - Workspace View

struct WorkspaceView: View {
    @Binding var selectedProjectID: UUID?

    @Environment(AppState.self) private var appState
    @Environment(\.replicateService) private var replicateService
    @Environment(\.projectService) private var projectService
    @Environment(\.modelContext) private var modelContext

    @Query private var projects: [Project]

    @State private var generationState = GenerationState()

    /// Currently loaded project (if any)
    private var currentProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return projects.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            PromptBar(state: generationState) {
                Task { await generate() }
            }

            Divider()

            ReferenceImagesBar(images: $generationState.referenceImages)
                .padding(.horizontal)
                .padding(.top, 8)

            Divider()
                .padding(.top, 8)

            VariationsGrid(state: generationState) { variationID in
                Task { await regenerateSingle(variationID) }
            }

            Divider()

            ExportBarPlaceholder(hasSelection: generationState.selectedVariationID != nil)
        }
        .onChange(of: selectedProjectID) { _, newID in
            if let newID, let project = projects.first(where: { $0.id == newID }) {
                loadProject(project)
            }
        }
    }

    // MARK: - Project Loading

    private func loadProject(_ project: Project) {
        generationState.prompt = project.prompt
        generationState.selectedStyle = project.style
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
        generationState.variations = []

        let referenceData = prepareReferenceImages()
        let count = generationState.variationCount
        let prompt = generationState.prompt
        let style = generationState.selectedStyle

        generationState.status = .generating(completed: 0, total: count)

        do {
            let images = try await withThrowingTaskGroup(of: NSImage.self) { group in
                for _ in 0..<count {
                    group.addTask {
                        try await self.replicateService.generate(
                            prompt: prompt,
                            style: style,
                            references: referenceData
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

            generationState.variations = images.map { image in
                GeneratedVariation(
                    image: image,
                    prompt: prompt,
                    style: style
                )
            }
            generationState.status = .completed

            if let first = generationState.variations.first {
                generationState.selectedVariationID = first.id
            }

            // Auto-save to project
            await saveToProject(images: images, prompt: prompt, style: style)

        } catch let error as AppError {
            generationState.error = error
            generationState.status = .failed
        } catch {
            generationState.error = .generationFailed(error.localizedDescription)
            generationState.status = .failed
        }
    }

    // MARK: - Auto-Save

    private func saveToProject(images: [NSImage], prompt: String, style: Style) async {
        await MainActor.run {
            // Create new project (auto-project approach)
            let projectName = Project.nameFromPrompt(prompt)
            let project = Project(name: projectName, prompt: prompt, style: style)

            modelContext.insert(project)

            // Save images to disk and create SavedVariation records
            for (index, image) in images.enumerated() {
                do {
                    let imagePath = try projectService.saveImage(image, to: project, index: index)
                    let variation = SavedVariation(imagePath: imagePath)
                    variation.project = project
                    project.variations.append(variation)
                } catch {
                    print("Failed to save variation \(index): \(error)")
                }
            }

            // Select the new project
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

        do {
            let image = try await replicateService.generate(
                prompt: prompt,
                style: style,
                references: referenceData
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

// MARK: - Export Bar (Placeholder for Phase 5)

struct ExportBarPlaceholder: View {
    let hasSelection: Bool

    @State private var exportiOS = true
    @State private var exportAndroid = true
    @State private var exportFavicon = false
    @State private var exportSocial = false

    var body: some View {
        HStack {
            Toggle("iOS", isOn: $exportiOS)
            Toggle("Android", isOn: $exportAndroid)
            Toggle("Favicon", isOn: $exportFavicon)
            Toggle("Social", isOn: $exportSocial)

            Spacer()

            Button {
                // TODO: Implement export in Phase 5
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(!hasSelection)
        }
        .toggleStyle(.checkbox)
        .padding()
        .background(.bar)
    }
}

#Preview {
    WorkspaceView(selectedProjectID: .constant(nil))
        .environment(AppState())
        .modelContainer(for: [Project.self, SavedVariation.self], inMemory: true)
}
