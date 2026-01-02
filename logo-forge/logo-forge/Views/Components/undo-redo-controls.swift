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

#Preview {
    UndoRedoControls(
        canUndo: true,
        canRedo: false,
        onUndo: {},
        onRedo: {}
    )
    .padding()
}
