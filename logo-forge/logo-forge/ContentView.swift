//
//  ContentView.swift
//  logo-forge
//
//  Created by Alexandru Tirim on 31.12.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedProjectID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedProjectID: $selectedProjectID)
                .background(LogoForgeTheme.surface)
        } detail: {
            WorkspaceView(selectedProjectID: $selectedProjectID)
        }
        .frame(minWidth: 1000, minHeight: 750)
        .background(LogoForgeTheme.canvas)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Project.self, SavedVariation.self], inMemory: true)
}
