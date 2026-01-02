import SwiftData
import Foundation

// MARK: - Global Prompt History
/// Tracks all prompts across all projects

@Model
final class PromptHistoryEntry {
    var id: UUID
    var prompt: String
    var styleRawValue: String
    var modelRawValue: String
    var createdAt: Date
    var projectID: UUID?  // nil if project deleted

    var style: Style {
        Style(rawValue: styleRawValue) ?? .minimal
    }

    var model: AIModel {
        AIModel(rawValue: modelRawValue) ?? .nanaBananaPro
    }

    init(prompt: String, style: Style, model: AIModel, projectID: UUID? = nil) {
        self.id = UUID()
        self.prompt = prompt
        self.styleRawValue = style.rawValue
        self.modelRawValue = model.rawValue
        self.createdAt = Date()
        self.projectID = projectID
    }
}

// MARK: - Per-Project Prompt Iteration
/// Tracks prompt evolution within a single project

@Model
final class PromptIteration {
    var id: UUID
    var version: Int
    var prompt: String
    var createdAt: Date

    @Relationship
    var project: Project?

    init(version: Int, prompt: String) {
        self.id = UUID()
        self.version = version
        self.prompt = prompt
        self.createdAt = Date()
    }
}
