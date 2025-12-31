//
//  ContentView.swift
//  logo-forge
//
//  Created by Alexandru Tirim on 31.12.2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedProjectID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedProjectID: $selectedProjectID)
        } detail: {
            WorkspaceView()
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
