import SwiftUI

struct SidebarView: View {
    @Binding var selectedProjectID: UUID?

    var body: some View {
        List(selection: $selectedProjectID) {
            Section("Projects") {
                Text("No projects yet")
                    .foregroundStyle(.secondary)
            }

            Section("History") {
                Text("No history")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button {
                    // TODO: Create new project
                } label: {
                    Label("New Project", systemImage: "plus")
                }
            }
        }
    }
}

#Preview {
    SidebarView(selectedProjectID: .constant(nil))
}
