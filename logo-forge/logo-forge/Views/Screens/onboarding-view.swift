import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.keychainService) private var keychain

    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "paintbrush.pointed")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Welcome to Logo Forge")
                .font(.largeTitle.bold())

            Text("Generate beautiful logos with AI.\nEnter your Replicate API key to start.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                SecureField("r8_xxxxxxxxxxxxxxxxxxxxxxxx", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Link("Get your API key from replicate.com →",
                     destination: URL(string: "https://replicate.com/account/api-tokens")!)
                    .font(.caption)
            }
            .frame(maxWidth: 400)

            Button {
                Task { await validateAndSave() }
            } label: {
                if isValidating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Get Started")
                        .frame(minWidth: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKey.isEmpty || isValidating)

            Spacer()
        }
        .padding(40)
        .frame(width: 500, height: 400)
    }

    private func validateAndSave() async {
        isValidating = true
        errorMessage = nil

        // Basic validation: Replicate keys start with "r8_"
        guard apiKey.hasPrefix("r8_") else {
            errorMessage = "Invalid API key format. Keys start with 'r8_'"
            isValidating = false
            return
        }

        do {
            try keychain.save(key: apiKey)
            dismiss()
        } catch {
            errorMessage = "Failed to save API key"
        }

        isValidating = false
    }
}

#Preview {
    OnboardingView()
}
