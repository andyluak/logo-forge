import SwiftUI

struct PromptSuggestionsButton: View {
    let currentPrompt: String
    let style: Style
    var onSelect: (String) -> Void

    private let suggestionService = PromptSuggestionService()

    @State private var isLoading = false
    @State private var suggestions: [String] = []
    @State private var isOpen = false
    @State private var error: String?

    var body: some View {
        Button {
            Task { await loadSuggestions() }
        } label: {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "sparkles")
                }
                Text("Improve")
            }
        }
        .buttonStyle(.bordered)
        .disabled(currentPrompt.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        .help("Get AI-powered prompt suggestions (~$0.002)")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            SuggestionsPopover(
                suggestions: suggestions,
                error: error,
                onSelect: { suggestion in
                    onSelect(suggestion)
                    isOpen = false
                },
                onKeepOriginal: { isOpen = false }
            )
        }
    }

    private func loadSuggestions() async {
        isLoading = true
        error = nil

        do {
            suggestions = try await suggestionService.suggest(
                prompt: currentPrompt,
                style: style,
                count: 3
            )
            isOpen = true
        } catch {
            self.error = error.localizedDescription
            isOpen = true
        }

        isLoading = false
    }
}

// MARK: - Suggestions Popover

private struct SuggestionsPopover: View {
    let suggestions: [String]
    let error: String?
    var onSelect: (String) -> Void
    var onKeepOriginal: () -> Void

    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("SUGGESTIONS")
                    .font(LogoForgeTheme.body(11, weight: .medium))
                    .foregroundStyle(LogoForgeTheme.textSecondary)
                    .tracking(1.5)

                Spacer()

                Text("~$0.002")
                    .font(LogoForgeTheme.body(10))
                    .foregroundStyle(LogoForgeTheme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if let error {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(LogoForgeTheme.body(12))
                        .foregroundStyle(LogoForgeTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Suggestions list
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: selectedIndex == index
                        ) {
                            selectedIndex = index
                            onSelect(suggestion)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Keep Original", action: onKeepOriginal)
                    .buttonStyle(.borderless)
                    .foregroundStyle(LogoForgeTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320)
        .background(LogoForgeTheme.surface)
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let suggestion: String
    let isSelected: Bool
    var onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : LogoForgeTheme.textSecondary)
                    .font(.system(size: 14))

                Text(suggestion)
                    .font(LogoForgeTheme.body(13))
                    .foregroundStyle(LogoForgeTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isHovered ? LogoForgeTheme.hover : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    PromptSuggestionsButton(
        currentPrompt: "mountain logo",
        style: .minimal,
        onSelect: { _ in }
    )
    .padding()
}
