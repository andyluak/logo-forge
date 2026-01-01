import Foundation
import AppKit

// MARK: - Project Service
// Handles file system operations for projects
// - Creates project directories
// - Saves/loads images to disk
// - Manages the Logo Forge documents folder

final class ProjectService: Sendable {
    /// Base directory: ~/Documents/Logo Forge/
    private var baseURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appending(path: "Logo Forge")
    }

    /// Projects directory: ~/Documents/Logo Forge/Projects/
    private var projectsURL: URL {
        baseURL.appending(path: "Projects")
    }

    init() {
        // Ensure directories exist on init
        ensureDirectoriesExist()
    }

    // MARK: - Directory Management

    /// Create base directories if they don't exist
    private func ensureDirectoriesExist() {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: projectsURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create Logo Forge directories: \(error)")
        }
    }

    /// Get the directory URL for a specific project
    func projectDirectory(for project: Project) -> URL {
        projectsURL.appending(path: project.directoryName)
    }

    /// Create directory for a new project
    func createProjectDirectory(for project: Project) throws {
        let url = projectDirectory(for: project)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    /// Delete project directory and all its contents
    func deleteProjectDirectory(for project: Project) throws {
        let url = projectDirectory(for: project)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Image Operations

    /// Save an NSImage to a project's directory
    /// Returns the relative path (filename) for storage in SwiftData
    func saveImage(_ image: NSImage, to project: Project, index: Int) throws -> String {
        let projectDir = projectDirectory(for: project)

        // Ensure project directory exists
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)

        // Create filename
        let filename = "variation-\(index).png"
        let fileURL = projectDir.appending(path: filename)

        // Convert NSImage to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ProjectServiceError.imageConversionFailed
        }

        // Write to disk
        try pngData.write(to: fileURL)

        return filename
    }

    /// Load an image from a project's directory
    func loadImage(from relativePath: String, in project: Project) -> NSImage? {
        let projectDir = projectDirectory(for: project)
        let fileURL = projectDir.appending(path: relativePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        return NSImage(contentsOf: fileURL)
    }

    /// Load all variation images for a project
    func loadAllImages(for project: Project) -> [NSImage] {
        project.variations
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { loadImage(from: $0.imagePath, in: project) }
    }
}

// MARK: - Errors

enum ProjectServiceError: LocalizedError {
    case imageConversionFailed
    case directoryCreationFailed

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image to PNG"
        case .directoryCreationFailed:
            return "Failed to create project directory"
        }
    }
}
