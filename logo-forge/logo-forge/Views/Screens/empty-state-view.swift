import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Welcome to Logo Forge")
                .font(.title)
                .fontWeight(.semibold)

            Text("Create a new project to get started")
                .foregroundStyle(.secondary)

            Button {
                // TODO: Create new project
            } label: {
                Label("New Project", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView()
}
