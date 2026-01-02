import SwiftUI

// MARK: - Inpaint Toolbar
/// Controls for mask painting: brush size, eraser, soft edges, actions

struct InpaintToolbar: View {
    @Bindable var maskState: MaskCanvasState
    @Binding var selectedModel: AIModel
    @Binding var prompt: String

    var onApply: () -> Void
    var onCancel: () -> Void

    @State private var isGenerating = false

    var body: some View {
        VStack(spacing: 0) {
            // Main toolbar row
            HStack(spacing: 16) {
                // Brush controls
                brushControls

                Divider()
                    .frame(height: 24)

                // Mode toggles
                modeToggles

                Divider()
                    .frame(height: 24)

                // Mask controls
                maskControls

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(LogoForgeTheme.surface)

            // Prompt input row
            promptRow
        }
    }

    // MARK: - Brush Controls

    private var brushControls: some View {
        HStack(spacing: 12) {
            // Brush size indicator
            ZStack {
                Circle()
                    .fill(maskState.isErasing ? Color.clear : Color.red.opacity(0.3))
                    .strokeBorder(
                        maskState.isErasing ? Color.white : Color.red,
                        lineWidth: 1
                    )
                    .frame(
                        width: min(maskState.brushSize / 2, 24),
                        height: min(maskState.brushSize / 2, 24)
                    )
            }
            .frame(width: 24, height: 24)

            // Brush size slider
            VStack(alignment: .leading, spacing: 2) {
                Text("SIZE")
                    .font(LogoForgeTheme.body(9, weight: .medium))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
                    .tracking(1)

                Slider(value: $maskState.brushSize, in: 5...100)
                    .frame(width: 100)
            }

            // Size value
            Text("\(Int(maskState.brushSize))px")
                .font(LogoForgeTheme.body(11))
                .foregroundStyle(LogoForgeTheme.textSecondary)
                .monospacedDigit()
                .frame(width: 40, alignment: .leading)
        }
    }

    // MARK: - Mode Toggles

    private var modeToggles: some View {
        HStack(spacing: 8) {
            // Brush mode
            ToolbarToggle(
                icon: "paintbrush.fill",
                label: "Brush",
                isActive: !maskState.isErasing
            ) {
                maskState.isErasing = false
            }

            // Eraser mode
            ToolbarToggle(
                icon: "eraser.fill",
                label: "Eraser",
                isActive: maskState.isErasing
            ) {
                maskState.isErasing = true
            }

            Divider()
                .frame(height: 24)

            // Soft edges toggle
            ToolbarToggle(
                icon: "circle.lefthalf.filled",
                label: "Soft",
                isActive: maskState.softEdges,
                isToggle: true
            ) {
                maskState.softEdges.toggle()
            }
        }
    }

    // MARK: - Mask Controls

    private var maskControls: some View {
        HStack(spacing: 8) {
            // Opacity slider
            VStack(alignment: .leading, spacing: 2) {
                Text("OVERLAY")
                    .font(LogoForgeTheme.body(9, weight: .medium))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
                    .tracking(1)

                Slider(value: $maskState.maskOpacity, in: 0.1...1.0)
                    .frame(width: 80)
            }

            // Clear button
            Button {
                maskState.clear()
            } label: {
                Label("Clear", systemImage: "xmark.circle")
                    .font(LogoForgeTheme.body(11))
            }
            .buttonStyle(.borderless)
            .disabled(!maskState.hasMask)

            // Undo button
            Button {
                maskState.undoLastStroke()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("z", modifiers: .command)
            .disabled(maskState.strokes.isEmpty)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Cancel", action: onCancel)
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape)

            Button {
                onApply()
            } label: {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Inpaint")
                }
                .frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!maskState.hasMask || prompt.isEmpty)
        }
    }

    // MARK: - Prompt Row

    private var promptRow: some View {
        HStack(spacing: 12) {
            // Model picker
            InpaintModelPicker(selection: $selectedModel)

            // Prompt field
            TextField("Describe what to generate in masked area...", text: $prompt)
                .textFieldStyle(.roundedBorder)

            // Cost indicator
            Text("~$\(String(format: "%.2f", Double(truncating: selectedModel.costPerImage as NSNumber)))")
                .font(LogoForgeTheme.body(10))
                .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(LogoForgeTheme.surface.opacity(0.5))
    }
}

// MARK: - Toolbar Toggle Button

private struct ToolbarToggle: View {
    let icon: String
    let label: String
    let isActive: Bool
    var isToggle: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(LogoForgeTheme.body(9))
            }
            .frame(width: 44, height: 40)
            .background(isActive ? LogoForgeTheme.selected : .clear)
            .foregroundStyle(isActive ? LogoForgeTheme.paper : LogoForgeTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inpaint Model Picker

struct InpaintModelPicker: View {
    @Binding var selection: AIModel

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(AIModel.inpaintingModels, id: \.self) { model in
                VStack(alignment: .leading) {
                    Text(model.rawValue)
                    if !model.inpaintDescription.isEmpty {
                        Text(model.inpaintDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tag(model)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 140)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()

        InpaintToolbar(
            maskState: MaskCanvasState(),
            selectedModel: .constant(.fluxFillPro),
            prompt: .constant(""),
            onApply: {},
            onCancel: {}
        )
    }
    .background(LogoForgeTheme.canvas)
}
