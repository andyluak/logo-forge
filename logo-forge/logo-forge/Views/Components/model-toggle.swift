import SwiftUI

// MARK: - Model Toggle
// Segmented control for choosing between AI models
// "Text" (Ideogram v3) vs "Abstract" (Nano Banana Pro)

struct ModelToggle: View {
    @Binding var selection: AIModel

    var body: some View {
        HStack(spacing: 0) {
            ToggleSegment(
                label: AIModel.ideogramV3.shortLabel,
                isSelected: selection == .ideogramV3,
                position: .left
            ) {
                selection = .ideogramV3
            }
            .help("\(AIModel.ideogramV3.rawValue)\n\(AIModel.ideogramV3.description)")

            ToggleSegment(
                label: AIModel.nanaBananaPro.shortLabel,
                isSelected: selection == .nanaBananaPro,
                position: .right
            ) {
                selection = .nanaBananaPro
            }
            .help("\(AIModel.nanaBananaPro.rawValue)\n\(AIModel.nanaBananaPro.description)")
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

// MARK: - Toggle Segment

struct ToggleSegment: View {
    enum Position { case left, right }

    let label: String
    let isSelected: Bool
    let position: Position
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(
                    isSelected ? Color(nsColor: .windowBackgroundColor) : .secondary
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary)
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var model: AIModel = .nanaBananaPro

        var body: some View {
            VStack(spacing: 20) {
                ModelToggle(selection: $model)

                Text("Selected: \(model.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(model.description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .frame(width: 300)
        }
    }

    return PreviewWrapper()
}
