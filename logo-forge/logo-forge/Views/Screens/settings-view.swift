import SwiftUI

struct SettingsView: View {
    @Environment(\.keychainService) private var keychain

    @State private var apiKey = ""
    @State private var showKey = false
    @State private var isSaving = false
    @State private var saveMessage: String?

    var body: some View {
        Form {
            Section("API Key") {
                HStack {
                    if showKey {
                        TextField("API Key", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button {
                        showKey.toggle()
                    } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)

                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty || isSaving)
                }

                if let message = saveMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message.contains("Saved") ? .green : .red)
                }

                Link("Manage keys on replicate.com",
                     destination: URL(string: "https://replicate.com/account/api-tokens")!)
                    .font(.caption)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Model", value: "Nano Banana Pro")

                Link("View on GitHub", destination: URL(string: "https://github.com/")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 250)
        .onAppear {
            loadAPIKey()
        }
    }

    private func loadAPIKey() {
        apiKey = (try? keychain.retrieve()) ?? ""
    }

    private func saveAPIKey() {
        isSaving = true
        saveMessage = nil

        do {
            try keychain.save(key: apiKey)
            saveMessage = "Saved successfully"
        } catch {
            saveMessage = "Failed to save"
        }

        isSaving = false

        // Clear message after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            saveMessage = nil
        }
    }
}

#Preview {
    SettingsView()
}
