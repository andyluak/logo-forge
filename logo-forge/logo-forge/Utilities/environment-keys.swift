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
}
