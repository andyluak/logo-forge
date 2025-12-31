//
//  logo_forgeApp.swift
//  logo-forge
//
//  Created by Alexandru Tirim on 31.12.2025.
//

import SwiftUI

@main
struct logo_forgeApp: App {
    @State private var appState = AppState()
    @State private var showOnboarding = false

    // Services - using concrete types
    private let keychainService = KeychainService()
    private let replicateService: ReplicateService

    init() {
        let keychain = KeychainService()
        self.replicateService = ReplicateService(keychainService: keychain)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                }
                .onAppear {
                    checkFirstRun()
                }
        }

        Settings {
            SettingsView()
        }
    }

    private func checkFirstRun() {
        if (try? keychainService.retrieve()) == nil {
            showOnboarding = true
        } else {
            appState.apiKeyValid = true
        }
    }
}
