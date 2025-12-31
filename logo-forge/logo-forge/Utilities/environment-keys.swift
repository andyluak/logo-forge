import SwiftUI

// MARK: - Environment Keys
// Using concrete types to avoid existential protocol issues

private struct KeychainServiceKey: EnvironmentKey {
    static let defaultValue = KeychainService()
}

private struct ReplicateServiceKey: EnvironmentKey {
    static let defaultValue = ReplicateService()
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
}
