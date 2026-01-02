import SwiftUI

// MARK: - Prompt Bar
// The main input area for logo generation
// Contains: prompt field, style picker, variation count, generate button

struct PromptBar: View {
    @Bindable var state: GenerationState
    var onGenerate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // History button
            PromptHistoryMenu { prompt in
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

            // Style picker with thumbnails
            StylePicker(selection: $state.selectedStyle)

            // Model toggle (Text vs Abstract)
            ModelToggle(selection: $state.selectedModel)

            // Variation count (1-4)
            VariationStepper(count: $state.variationCount)

            // Generate button
            GenerateButton(
                isGenerating: state.status.isGenerating,
                isDisabled: !state.canGenerate,
                statusText: state.status.statusText,
                action: onGenerate
            )
        }
        .padding()
        .background(.bar)
    }
}

// MARK: - Style Picker
// Dropdown with style options and placeholder thumbnails

struct StylePicker: View {
    @Binding var selection: Style

    var body: some View {
        Picker("Style", selection: $selection) {
            ForEach(Style.allCases) { style in
                HStack {
                    // Placeholder thumbnail (colored square for now)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForStyle(style))
                        .frame(width: 20, height: 20)

                    Text(style.rawValue)
                }
                .tag(style)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 140)
    }

    // Placeholder colors until real thumbnails are added
    private func colorForStyle(_ style: Style) -> Color {
        switch style {
        case .minimal: return .gray
        case .bold: return .red
        case .tech: return .blue
        case .vintage: return .brown
        case .playful: return .orange
        case .elegant: return .purple
        case .custom: return .secondary
        }
    }
}

// MARK: - Variation Stepper
// Controls how many variations to generate (1-4)

struct VariationStepper: View {
    @Binding var count: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("Variations:")
                .foregroundStyle(.secondary)

            Stepper(value: $count, in: 1...4) {
                Text("\(count)")
                    .monospacedDigit()
                    .frame(width: 20)
            }
            .labelsHidden()

            // Visual indicator
            HStack(spacing: 2) {
                ForEach(1...4, id: \.self) { i in
                    Circle()
                        .fill(i <= count ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
}

// MARK: - Generate Button
// Shows loading state during generation

struct GenerateButton: View {
    let isGenerating: Bool
    let isDisabled: Bool
    let statusText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                    Text(statusText)
                } else {
                    Image(systemName: "sparkles")
                    Text("Generate")
                }
            }
            .frame(minWidth: 100)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PromptBar(state: GenerationState()) { }
        Spacer()
    }
}
