import SwiftUI

// MARK: - Editor Panel
// Sidebar panel with editing controls
// Shows when a variation is selected

struct EditorPanel: View {
    @Bindable var state: EditorState
    @Bindable var history: EditHistory
    var onApply: () -> Void
    var onReset: () -> Void
    var onRemoveBackground: () async throws -> Void
    var onInpaint: () -> Void

    @State private var isRemovingBackground = false
    @State private var removeBackgroundError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with undo/redo
            HStack {
                Text("Edit")
                    .font(LogoForgeTheme.body(16, weight: .semibold))
                    .foregroundStyle(LogoForgeTheme.textPrimary)

                Spacer()

                UndoRedoControls(
                    canUndo: history.canUndo,
                    canRedo: history.canRedo,
                    onUndo: performUndo,
                    onRedo: performRedo
                )
            }

            Divider()
                .background(LogoForgeTheme.border)

            // AI Tools Section
            AIToolsSection(
                isRemovingBackground: isRemovingBackground,
                error: removeBackgroundError,
                onRemoveBackground: {
                    Task {
                        isRemovingBackground = true
                        removeBackgroundError = nil
                        do {
                            try await onRemoveBackground()
                        } catch {
                            removeBackgroundError = error.localizedDescription
                        }
                        isRemovingBackground = false
                    }
                },
                onInpaint: onInpaint
            )

            Divider()

            // Background Color
            BackgroundColorSection(color: $state.backgroundColor)

            Divider()

            // Padding
            PaddingSection(padding: $state.padding)

            Divider()

            // Transform (Rotate, Flip & Crop)
            TransformSection(
                rotation: $state.rotation,
                flipH: $state.flipHorizontal,
                flipV: $state.flipVertical,
                isCropping: $state.isCropping,
                cropRect: $state.cropRect
            )

            Divider()

            // Actions
            ActionButtons(
                hasChanges: state.hasChanges,
                onApply: onApply,
                onReset: onReset
            )

            Spacer()
        }
        .padding()
        .frame(width: 220)
        .background(LogoForgeTheme.surface)
        // Track changes for undo/redo
        .onChange(of: state.backgroundColor) { oldValue, _ in
            pushSnapshot(withBackgroundColor: oldValue)
        }
        .onChange(of: state.padding) { oldValue, _ in
            pushSnapshot(withPadding: oldValue)
        }
        .onChange(of: state.rotation) { oldValue, _ in
            pushSnapshot(withRotation: oldValue)
        }
        .onChange(of: state.flipHorizontal) { oldValue, _ in
            pushSnapshot(withFlipH: oldValue)
        }
        .onChange(of: state.flipVertical) { oldValue, _ in
            pushSnapshot(withFlipV: oldValue)
        }
        .onChange(of: state.cropRect) { oldValue, _ in
            pushSnapshot(withCropRect: oldValue)
        }
    }

    // MARK: - History Tracking

    private func pushSnapshot(withBackgroundColor color: Color) {
        let snapshot = EditorStateSnapshot(
            backgroundColor: color,
            padding: state.padding,
            rotation: state.rotation,
            flipHorizontal: state.flipHorizontal,
            flipVertical: state.flipVertical,
            cropRect: state.cropRect
        )
        history.push(snapshot)
    }

    private func pushSnapshot(withPadding padding: CGFloat) {
        let snapshot = EditorStateSnapshot(
            backgroundColor: state.backgroundColor,
            padding: padding,
            rotation: state.rotation,
            flipHorizontal: state.flipHorizontal,
            flipVertical: state.flipVertical,
            cropRect: state.cropRect
        )
        history.push(snapshot)
    }

    private func pushSnapshot(withRotation rotation: EditorState.Rotation) {
        let snapshot = EditorStateSnapshot(
            backgroundColor: state.backgroundColor,
            padding: state.padding,
            rotation: rotation,
            flipHorizontal: state.flipHorizontal,
            flipVertical: state.flipVertical,
            cropRect: state.cropRect
        )
        history.push(snapshot)
    }

    private func pushSnapshot(withFlipH flipH: Bool) {
        let snapshot = EditorStateSnapshot(
            backgroundColor: state.backgroundColor,
            padding: state.padding,
            rotation: state.rotation,
            flipHorizontal: flipH,
            flipVertical: state.flipVertical,
            cropRect: state.cropRect
        )
        history.push(snapshot)
    }

    private func pushSnapshot(withFlipV flipV: Bool) {
        let snapshot = EditorStateSnapshot(
            backgroundColor: state.backgroundColor,
            padding: state.padding,
            rotation: state.rotation,
            flipHorizontal: state.flipHorizontal,
            flipVertical: flipV,
            cropRect: state.cropRect
        )
        history.push(snapshot)
    }

    private func pushSnapshot(withCropRect cropRect: CGRect?) {
        let snapshot = EditorStateSnapshot(
            backgroundColor: state.backgroundColor,
            padding: state.padding,
            rotation: state.rotation,
            flipHorizontal: state.flipHorizontal,
            flipVertical: state.flipVertical,
            cropRect: cropRect
        )
        history.push(snapshot)
    }

    // MARK: - Undo/Redo Actions

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

// MARK: - AI Tools Section

private struct AIToolsSection: View {
    let isRemovingBackground: Bool
    let error: String?
    let onRemoveBackground: () -> Void
    let onInpaint: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Tools")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Remove Background button
            Button(action: onRemoveBackground) {
                HStack(spacing: 6) {
                    if isRemovingBackground {
                        ProgressView()
                            .controlSize(.small)
                        Text("Removing...")
                    } else {
                        Image(systemName: "wand.and.rays")
                        Text("Remove Background")
                    }
                    Spacer()
                    Text("~$0.01")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isRemovingBackground)
            .help("Use AI to remove the background (~$0.01)")

            // Inpaint button
            Button(action: onInpaint) {
                HStack(spacing: 6) {
                    Image(systemName: "paintbrush.pointed")
                    Text("Inpaint Region")
                    Spacer()
                    Text("~$0.05")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isRemovingBackground)
            .help("Paint over areas to modify with AI (~$0.05)")

            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Background Color Section

private struct BackgroundColorSection: View {
    @Binding var color: Color

    // Preset colors for quick selection
    private let presets: [Color] = [
        .clear, .white, .black,
        .red, .orange, .yellow,
        .green, .blue, .purple
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Color picker
            HStack {
                ColorPicker("", selection: $color, supportsOpacity: true)
                    .labelsHidden()

                Text(color == .clear ? "Transparent" : "Custom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Preset colors grid
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 4), count: 5), spacing: 4) {
                ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                    Button {
                        color = preset
                    } label: {
                        ZStack {
                            // Checkerboard for transparent
                            if preset == .clear {
                                SmallCheckerboardPattern()
                            }

                            RoundedRectangle(cornerRadius: 4)
                                .fill(preset)

                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(color == preset ? Color.accentColor : Color.clear, lineWidth: 2)
                        }
                        .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Padding Section

private struct PaddingSection: View {
    @Binding var padding: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Padding")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(padding))px")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: $padding, in: 0...100, step: 1)
        }
    }
}

// MARK: - Transform Section

private struct TransformSection: View {
    @Binding var rotation: EditorState.Rotation
    @Binding var flipH: Bool
    @Binding var flipV: Bool
    @Binding var isCropping: Bool
    @Binding var cropRect: CGRect?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transform")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Rotation buttons
            HStack(spacing: 8) {
                Button {
                    rotation = rotation.rotatedCounterClockwise()
                } label: {
                    Label("Rotate Left", systemImage: "rotate.left")
                        .labelStyle(.iconOnly)
                }
                .help("Rotate 90° counter-clockwise")

                Button {
                    rotation = rotation.rotatedClockwise()
                } label: {
                    Label("Rotate Right", systemImage: "rotate.right")
                        .labelStyle(.iconOnly)
                }
                .help("Rotate 90° clockwise")

                Spacer()

                // Rotation indicator
                if rotation != .none {
                    Text("\(Int(rotation.degrees))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .buttonStyle(.bordered)

            // Flip toggles + Crop
            HStack(spacing: 8) {
                Toggle(isOn: $flipH) {
                    Label("Flip H", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .labelStyle(.iconOnly)
                }
                .toggleStyle(.button)
                .help("Flip horizontally")

                Toggle(isOn: $flipV) {
                    Label("Flip V", systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                        .labelStyle(.iconOnly)
                }
                .toggleStyle(.button)
                .help("Flip vertically")

                Spacer()

                // Crop button
                Toggle(isOn: $isCropping) {
                    Label("Crop", systemImage: "crop")
                        .labelStyle(.iconOnly)
                }
                .toggleStyle(.button)
                .help(isCropping ? "Exit crop mode" : "Enter crop mode")
            }

            // Crop indicator / clear
            if cropRect != nil {
                HStack {
                    Text("Crop applied")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Clear") {
                        cropRect = nil
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}

// MARK: - Action Buttons

private struct ActionButtons: View {
    let hasChanges: Bool
    let onApply: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack {
            Button("Reset", action: onReset)
                .disabled(!hasChanges)

            Spacer()

            Button("Apply", action: onApply)
                .buttonStyle(.borderedProminent)
                .disabled(!hasChanges)
        }
    }
}

// MARK: - Small Checkerboard Pattern (for color picker transparent preview)

private struct SmallCheckerboardPattern: View {
    var body: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 4
            let rows = Int(size.height / squareSize)
            let cols = Int(size.width / squareSize)

            for row in 0..<rows {
                for col in 0..<cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? .white : .gray.opacity(0.3))
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditorPanel(
        state: EditorState(),
        history: EditHistory(),
        onApply: { },
        onReset: { },
        onRemoveBackground: { },
        onInpaint: { }
    )
}
