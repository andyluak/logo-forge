import SwiftUI
import SwiftData

// MARK: - Sidebar View
// Shows project list grouped by date (Today, Yesterday, Last 7 Days, Older)

struct SidebarView: View {
    @Binding var selectedProjectID: UUID?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]

    var body: some View {
        List(selection: $selectedProjectID) {
            if projects.isEmpty {
                Section("Projects") {
                    Text("No projects yet")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                // Group projects by date
                if !todayProjects.isEmpty {
                    Section("Today") {
                        ForEach(todayProjects) { project in
                            ProjectRow(project: project)
                                .tag(project.id)
                        }
                    }
                }

                if !yesterdayProjects.isEmpty {
                    Section("Yesterday") {
                        ForEach(yesterdayProjects) { project in
                            ProjectRow(project: project)
                                .tag(project.id)
                        }
                    }
                }

                if !lastWeekProjects.isEmpty {
                    Section("Last 7 Days") {
                        ForEach(lastWeekProjects) { project in
                            ProjectRow(project: project)
                                .tag(project.id)
                        }
                    }
                }

                if !olderProjects.isEmpty {
                    Section("Older") {
                        ForEach(olderProjects) { project in
                            ProjectRow(project: project)
                                .tag(project.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
        .toolbar {
            ToolbarItem {
                Button {
                    createNewProject()
                } label: {
                    Label("New Project", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Date Grouping

    private var todayProjects: [Project] {
        projects.filter { Calendar.current.isDateInToday($0.updatedAt) }
    }

    private var yesterdayProjects: [Project] {
        projects.filter { Calendar.current.isDateInYesterday($0.updatedAt) }
    }

    private var lastWeekProjects: [Project] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        return projects.filter { project in
            let date = project.updatedAt
            let isInLastWeek = date >= weekAgo && date < now
            let isToday = calendar.isDateInToday(date)
            let isYesterday = calendar.isDateInYesterday(date)
            return isInLastWeek && !isToday && !isYesterday
        }
    }

    private var olderProjects: [Project] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        return projects.filter { $0.updatedAt < weekAgo }
    }

    // MARK: - Actions

    private func createNewProject() {
        let project = Project(
            name: "New Project",
            prompt: "",
            style: .minimal
        )
        modelContext.insert(project)
        selectedProjectID = project.id
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @State private var isRenaming = false
    @State private var editedName = ""
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail placeholder (first variation or icon)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LogoForgeTheme.surface)
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("Project name", text: $editedName)
                        .textFieldStyle(.plain)
                        .font(LogoForgeTheme.body(14))
                        .foregroundStyle(LogoForgeTheme.textPrimary)
                        .onSubmit {
                            project.name = editedName
                            isRenaming = false
                        }
                        .onExitCommand {
                            isRenaming = false
                        }
                } else {
                    Text(project.name)
                        .font(LogoForgeTheme.body(14))
                        .foregroundStyle(LogoForgeTheme.textPrimary)
                        .lineLimit(1)
                }

                Text("\(project.variations.count) variations")
                    .font(LogoForgeTheme.body(11))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? LogoForgeTheme.hover : .clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Rename") {
                editedName = project.name
                isRenaming = true
            }

            Divider()

            Button("Delete", role: .destructive) {
                deleteProject()
            }
        }
    }

    private func deleteProject() {
        // Delete files first
        let projectService = ProjectService()
        try? projectService.deleteProjectDirectory(for: project)

        // Then delete from SwiftData
        modelContext.delete(project)
    }
}

// MARK: - Preview

#Preview {
    SidebarView(selectedProjectID: .constant(nil))
        .modelContainer(for: [Project.self, SavedVariation.self], inMemory: true)
}
