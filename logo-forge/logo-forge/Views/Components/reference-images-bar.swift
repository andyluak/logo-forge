import SwiftUI
import UniformTypeIdentifiers

// MARK: - Reference Images Bar
// Drop zone for up to 14 reference images
// These get sent to the AI to guide the style

struct ReferenceImagesBar: View {
    @Binding var images: [NSImage]

    /// Maximum images allowed by the Nano Banana Pro model
    private let maxImages = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Label("Reference Images", systemImage: "photo.on.rectangle")
                    .font(.headline)

                Text("(\(images.count)/\(maxImages))")
                    .foregroundStyle(.secondary)

                Spacer()

                if !images.isEmpty {
                    Button("Clear All") {
                        images.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }

            // Drop zone / thumbnails
            if images.isEmpty {
                dropZone
            } else {
                thumbnailGrid
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    // MARK: - Drop Zone (when empty)

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.title)
                    .foregroundStyle(.secondary)

                Text("Drop images here")
                    .foregroundStyle(.secondary)

                Text("or")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Button("Browse...") {
                    openFilePicker()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(height: 120)
        .dropDestination(for: Data.self) { items, _ in
            handleDroppedData(items)
            return true
        }
    }

    // MARK: - Thumbnail Grid (when has images)

    private var thumbnailGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Existing thumbnails
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ReferenceThumbnail(image: image) {
                        images.remove(at: index)
                    }
                }

                // Add more button (if under limit)
                if images.count < maxImages {
                    addMoreButton
                }
            }
        }
        .frame(height: 80)
        // Also accept drops on the thumbnail area
        .dropDestination(for: Data.self) { items, _ in
            handleDroppedData(items)
            return true
        }
    }

    private var addMoreButton: some View {
        Button {
            openFilePicker()
        } label: {
            VStack {
                Image(systemName: "plus")
                    .font(.title2)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.secondary)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg]

        if panel.runModal() == .OK {
            for url in panel.urls {
                if let image = NSImage(contentsOf: url) {
                    addImage(image)
                }
            }
        }
    }

    private func handleDroppedData(_ items: [Data]) {
        for data in items {
            if let image = NSImage(data: data) {
                addImage(image)
            }
        }
    }

    private func addImage(_ image: NSImage) {
        guard images.count < maxImages else { return }
        images.append(image)
    }
}

// MARK: - Reference Thumbnail
// Individual thumbnail with remove button

struct ReferenceThumbnail: View {
    let image: NSImage
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Remove button (visible on hover)
            if isHovering {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Preview

#Preview("Empty") {
    ReferenceImagesBar(images: .constant([]))
        .padding()
}

#Preview("With Images") {
    // Create some placeholder images for preview
    let placeholders = (0..<3).map { _ in
        NSImage(size: NSSize(width: 100, height: 100))
    }
    return ReferenceImagesBar(images: .constant(placeholders))
        .padding()
}
