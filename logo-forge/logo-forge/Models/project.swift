import SwiftData
import Foundation

// MARK: - Project Model
// Represents a saved logo generation session
// Each generation creates a new project automatically

@Model
final class Project {
    var id: UUID
    var name: String
    var prompt: String
    var styleRawValue: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SavedVariation.project)
    var variations: [SavedVariation] = []

    var style: Style {
        get { Style(rawValue: styleRawValue) ?? .minimal }
        set { styleRawValue = newValue.rawValue }
    }

    init(name: String, prompt: String, style: Style) {
        self.id = UUID()
        self.name = name
        self.prompt = prompt
        self.styleRawValue = style.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Create project name from prompt (first few words)
    static func nameFromPrompt(_ prompt: String) -> String {
        let words = prompt.split(separator: " ").prefix(5)
        let name = words.joined(separator: " ")
        return name.isEmpty ? "Untitled Project" : String(name)
    }

    /// Directory name for this project's files
    var directoryName: String {
        id.uuidString
    }
}

// MARK: - SavedVariation Model
// Represents a single generated image within a project

@Model
final class SavedVariation {
    var id: UUID
    var imagePath: String  // Relative path from project directory
    var createdAt: Date

    var project: Project?

    init(imagePath: String) {
        self.id = UUID()
        self.imagePath = imagePath
        self.createdAt = Date()
    }
}
