import SwiftUI

// MARK: - Environment Keys
// Using concrete types to avoid existential protocol issues

private struct KeychainServiceKey: EnvironmentKey {
    static let defaultValue = KeychainService()
}

private struct ReplicateServiceKey: EnvironmentKey {
    static let defaultValue = ReplicateService()
}

private struct ProjectServiceKey: EnvironmentKey {
    static let defaultValue = ProjectService()
}

private struct ExportServiceKey: EnvironmentKey {
    static let defaultValue = ExportService()
}

private struct UpscalingServiceKey: EnvironmentKey {
    static let defaultValue = UpscalingService()
}

private struct VectorizationServiceKey: EnvironmentKey {
    static let defaultValue = VectorizationService()
}

private struct BackgroundRemovalServiceKey: EnvironmentKey {
    static let defaultValue = BackgroundRemovalService()
}

extension EnvironmentValues {
    var keychainService: KeychainService {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }

    var replicateService: ReplicateService {
        get { self[ReplicateServiceKey.self] }
        set { self[ReplicateServiceKey.self] = newValue }
    }

    var projectService: ProjectService {
        get { self[ProjectServiceKey.self] }
        set { self[ProjectServiceKey.self] = newValue }
    }

    var exportService: ExportService {
        get { self[ExportServiceKey.self] }
        set { self[ExportServiceKey.self] = newValue }
    }

    var upscalingService: UpscalingService {
        get { self[UpscalingServiceKey.self] }
        set { self[UpscalingServiceKey.self] = newValue }
    }

    var vectorizationService: VectorizationService {
        get { self[VectorizationServiceKey.self] }
        set { self[VectorizationServiceKey.self] = newValue }
    }

    var backgroundRemovalService: BackgroundRemovalService {
        get { self[BackgroundRemovalServiceKey.self] }
        set { self[BackgroundRemovalServiceKey.self] = newValue }
    }
}
