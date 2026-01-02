import SwiftUI
import SwiftData

struct PromptHistoryMenu: View {
    var onSelect: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isOpen = false
    @State private var history: [PromptHistoryEntry] = []

    var body: some View {
        Button {
            loadHistory()
            isOpen = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(LogoForgeTheme.textSecondary)
        }
        .buttonStyle(.borderless)
        .help("Prompt history")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            PromptHistoryPopover(history: history) { prompt in
                onSelect(prompt)
                isOpen = false
            }
        }
    }

    private func loadHistory() {
        let service = PromptHistoryService(modelContext: modelContext)
        history = service.getGlobalHistory(limit: 20)
    }
}

// MARK: - Popover Content

private struct PromptHistoryPopover: View {
    let history: [PromptHistoryEntry]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("RECENT PROMPTS")
                .font(LogoForgeTheme.body(11, weight: .medium))
                .foregroundStyle(LogoForgeTheme.textSecondary)
                .tracking(1.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // List or empty state
            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.5))
                    Text("No prompts yet")
                        .font(LogoForgeTheme.body(13))
                        .foregroundStyle(LogoForgeTheme.textSecondary)
                    Text("Generate a logo to start building history")
                        .font(LogoForgeTheme.body(11))
                        .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(history) { entry in
                            PromptHistoryRow(entry: entry, onSelect: onSelect)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 300)
        .background(LogoForgeTheme.surface)
    }
}

// MARK: - Row

private struct PromptHistoryRow: View {
    let entry: PromptHistoryEntry
    var onSelect: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect(entry.prompt)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.prompt)
                    .font(LogoForgeTheme.body(13))
                    .foregroundStyle(LogoForgeTheme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(entry.style.rawValue)
                    Text("•")
                    Text(entry.createdAt, style: .relative)
                }
                .font(LogoForgeTheme.body(11))
                .foregroundStyle(LogoForgeTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? LogoForgeTheme.hover : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    PromptHistoryMenu(onSelect: { _ in })
        .padding()
}
