import SwiftUI

// MARK: - Workspace View (Simplified for debugging)

struct WorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.replicateService) private var replicateService
    @State private var generationState = GenerationState()

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
    }

    // MARK: - Generation Logic

    private func generate() async {
        generationState.status = .preparing
        generationState.error = nil
        generationState.variations = []

        let referenceData = prepareReferenceImages()
        generationState.status = .generating(completed: 0, total: generationState.variationCount)

        do {
            let images = try await withThrowingTaskGroup(of: NSImage.self) { group in
                for _ in 0..<generationState.variationCount {
                    group.addTask {
                        try await self.replicateService.generate(
                            prompt: self.generationState.prompt,
                            style: self.generationState.selectedStyle,
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
                            total: generationState.variationCount
                        )
                    }
                }
                return results
            }

            generationState.variations = images.map { image in
                GeneratedVariation(
                    image: image,
                    prompt: generationState.prompt,
                    style: generationState.selectedStyle
                )
            }
            generationState.status = .completed

            if let first = generationState.variations.first {
                generationState.selectedVariationID = first.id
            }

        } catch let error as AppError {
            generationState.error = error
            generationState.status = .failed
        } catch {
            generationState.error = .generationFailed(error.localizedDescription)
            generationState.status = .failed
        }
    }

    private func regenerateSingle(_ variationID: UUID) async {
        guard let index = generationState.variations.firstIndex(where: { $0.id == variationID }) else {
            return
        }

        let referenceData = prepareReferenceImages()

        do {
            let image = try await replicateService.generate(
                prompt: generationState.prompt,
                style: generationState.selectedStyle,
                references: referenceData
            )

            let newVariation = GeneratedVariation(
                image: image,
                prompt: generationState.prompt,
                style: generationState.selectedStyle
            )

            generationState.variations[index] = newVariation
            generationState.selectedVariationID = newVariation.id

        } catch let error as AppError {
            appState.showToast(error.localizedDescription ?? "Regeneration failed")
        } catch {
            appState.showToast("Regeneration failed")
        }
    }

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
    WorkspaceView()
        .environment(AppState())
}
