import SwiftData
import Foundation

// MARK: - Prompt History Service
/// Manages recording and retrieving prompt history

final class PromptHistoryService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Record a prompt to global history
    func record(prompt: String, style: Style, model: AIModel, projectID: UUID?) {
        // Skip empty or duplicate prompts
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check for recent duplicate
        let recent = getGlobalHistory(limit: 1).first
        if recent?.prompt == trimmed { return }

        // Insert global entry
        let entry = PromptHistoryEntry(
            prompt: trimmed,
            style: style,
            model: model,
            projectID: projectID
        )
        modelContext.insert(entry)

        // Insert project iteration if projectID provided
        if let projectID {
            addProjectIteration(prompt: trimmed, projectID: projectID)
        }

        try? modelContext.save()
    }

    /// Get recent prompts from global history
    func getGlobalHistory(limit: Int = 20) -> [PromptHistoryEntry] {
        var descriptor = FetchDescriptor<PromptHistoryEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Get prompt iterations for a specific project
    func getProjectIterations(projectID: UUID) -> [PromptIteration] {
        let descriptor = FetchDescriptor<PromptIteration>(
            predicate: #Predicate { $0.project?.id == projectID },
            sortBy: [SortDescriptor(\.version, order: .forward)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Private

    private func addProjectIteration(prompt: String, projectID: UUID) {
        // Get current max version for this project
        let iterations = getProjectIterations(projectID: projectID)
        let nextVersion = (iterations.last?.version ?? 0) + 1

        let iteration = PromptIteration(version: nextVersion, prompt: prompt)

        // Find and link to project
        let projectDescriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == projectID }
        )
        if let project = try? modelContext.fetch(projectDescriptor).first {
            iteration.project = project
        }

        modelContext.insert(iteration)
    }
}
