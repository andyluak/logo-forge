import SwiftUI

// MARK: - Variations Grid
// Displays generated logo variations in a responsive grid
// Shows different states: empty, generating, results, error

struct VariationsGrid: View {
    @Bindable var state: GenerationState
    var editorState: EditorState?  // Optional - for live preview of edits
    var onRegenerate: (UUID) -> Void

    // Responsive grid: 2 columns minimum, adapts to width
    private let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 400), spacing: 16)
    ]

    var body: some View {
        Group {
            switch state.status {
            case .idle where state.variations.isEmpty:
                emptyState

            case .preparing, .generating:
                generatingState

            case .failed:
                errorState

            default:
                resultsGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No variations yet")
                .font(.headline)

            Text("Enter a prompt and click Generate")
                .foregroundStyle(.secondary)
        }
    }

    private var generatingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(state.status.statusText)
                .font(.headline)

            Text("This may take 10-30 seconds")
                .foregroundStyle(.secondary)

            // Progress indicator for multiple variations
            if case .generating(let completed, let total) = state.status {
                HStack(spacing: 8) {
                    ForEach(0..<total, id: \.self) { index in
                        Circle()
                            .fill(index < completed ? Color.green : Color.secondary.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
    }

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text(state.error?.localizedDescription ?? "Generation failed")
                .font(.headline)

            if let suggestion = state.error?.recoverySuggestion {
                Text(suggestion)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                state.clearResults()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(state.variations) { variation in
                    let isSelected = state.selectedVariationID == variation.id
                    VariationCard(
                        variation: variation,
                        isSelected: isSelected,
                        // Show live preview only for selected card
                        editorState: isSelected ? editorState : nil,
                        onSelect: { state.selectVariation(variation.id) },
                        onRegenerate: { onRegenerate(variation.id) }
                    )
                }
            }
        }
    }
}

// MARK: - Variation Card
// Individual card for each generated variation
// Shows live preview of edits when selected

struct VariationCard: View {
    let variation: GeneratedVariation
    let isSelected: Bool
    var editorState: EditorState?  // For live preview when selected
    let onSelect: () -> Void
    let onRegenerate: () -> Void

    @State private var isHovering = false

    /// The image to display (with edits applied if selected and has changes)
    private var displayImage: NSImage {
        guard isSelected,
              let editorState,
              editorState.hasChanges else {
            return variation.image
        }
        // Apply edits for live preview
        return ImageProcessor.process(variation.image, with: editorState)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Image with live preview
            Image(nsImage: displayImage)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                // Show "Preview" badge when edits are being previewed
                .overlay(alignment: .topTrailing) {
                    if isSelected && editorState?.hasChanges == true {
                        Text("Preview")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(8)
                    }
                }

            // Actions (visible on hover)
            if isHovering || isSelected {
                HStack {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSelected)

                    Button {
                        onRegenerate()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .help("Regenerate this variation")
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Preview

#Preview("Empty") {
    VariationsGrid(state: GenerationState(), editorState: nil) { _ in }
}

#Preview("Generating") {
    let state = GenerationState()
    state.status = .generating(completed: 2, total: 4)
    return VariationsGrid(state: state, editorState: nil) { _ in }
}
