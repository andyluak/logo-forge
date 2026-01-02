import SwiftUI

// MARK: - Edit Snapshot
/// Immutable copy of editor state at a point in time

struct EditorStateSnapshot {
    let backgroundColor: Color
    let padding: CGFloat
    let rotation: EditorState.Rotation
    let flipHorizontal: Bool
    let flipVertical: Bool
}

extension EditorState {
    /// Create snapshot of current state
    func snapshot() -> EditorStateSnapshot {
        EditorStateSnapshot(
            backgroundColor: backgroundColor,
            padding: padding,
            rotation: rotation,
            flipHorizontal: flipHorizontal,
            flipVertical: flipVertical
        )
    }

    /// Restore state from snapshot
    func apply(_ snapshot: EditorStateSnapshot) {
        backgroundColor = snapshot.backgroundColor
        padding = snapshot.padding
        rotation = snapshot.rotation
        flipHorizontal = snapshot.flipHorizontal
        flipVertical = snapshot.flipVertical
    }
}

// MARK: - Edit History
/// Manages undo/redo stacks for editor operations

@Observable
final class EditHistory {
    private(set) var undoStack: [EditorStateSnapshot] = []
    private(set) var redoStack: [EditorStateSnapshot] = []

    private let maxHistory = 20

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Push current state before making a change
    func push(_ snapshot: EditorStateSnapshot) {
        undoStack.append(snapshot)
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        // Clear redo stack on new action
        redoStack.removeAll()
    }

    /// Pop and return the previous state
    func undo(current: EditorStateSnapshot) -> EditorStateSnapshot? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    /// Pop and return the next state
    func redo(current: EditorStateSnapshot) -> EditorStateSnapshot? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }

    /// Clear all history (when switching images)
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
