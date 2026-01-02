import Foundation

// MARK: - Prompt Suggestion Service
/// Uses Replicate LLM to generate improved prompt suggestions

final class PromptSuggestionService: Sendable {
    private let baseURL = URL(string: "https://api.replicate.com/v1")!
    private let replicateModel = "meta/meta-llama-3-8b-instruct"
    private let keychainService: KeychainService

    let costPerRequest: Decimal = 0.002

    private let pollInterval: Duration = .seconds(1)
    private let maxWaitTime: Duration = .seconds(30)

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    func suggest(prompt: String, style: Style, count: Int = 3) async throws -> [String] {
        guard let apiKey = try keychainService.retrieve() else {
            throw AppError.missingAPIKey
        }

        let systemPrompt = """
        You are an expert logo designer. Improve the user's logo prompt to be more specific and effective.

        Guidelines:
        - Add specific visual details (shapes, symbols, composition)
        - Suggest color themes if not specified
        - Include style keywords that work well for logo generation
        - Keep prompts concise (under 50 words)
        - The style is: \(style.rawValue)

        Return exactly \(count) improved prompts, one per line. No numbering, no explanations.
        """

        let userPrompt = "Improve this logo prompt: \"\(prompt)\""

        // Create prediction
        let predictionID = try await createPrediction(
            system: systemPrompt,
            user: userPrompt,
            apiKey: apiKey
        )

        // Poll for completion
        let output = try await pollForCompletion(predictionID: predictionID, apiKey: apiKey)

        // Parse output into array
        let suggestions = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(count)

        return Array(suggestions)
    }

    // MARK: - Private

    private func createPrediction(system: String, user: String, apiKey: String) async throws -> String {
        let url = baseURL.appending(path: "models/\(replicateModel)/predictions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": [
                "prompt": user,
                "system_prompt": system,
                "max_tokens": 500,
                "temperature": 0.7
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError
        }

        switch httpResponse.statusCode {
        case 200, 201:
            let prediction = try JSONDecoder().decode(LLMPrediction.self, from: data)
            return prediction.id
        case 401:
            throw AppError.invalidAPIKey
        case 429:
            throw AppError.rateLimited(retryAfter: 30)
        default:
            throw AppError.generationFailed("Suggestion failed: HTTP \(httpResponse.statusCode)")
        }
    }

    private func pollForCompletion(predictionID: String, apiKey: String) async throws -> String {
        let url = baseURL.appending(path: "predictions/\(predictionID)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let startTime = Date()

        while true {
            if Date().timeIntervalSince(startTime) > Double(maxWaitTime.components.seconds) {
                throw AppError.generationFailed("Suggestion timed out")
            }

            try await Task.sleep(for: pollInterval)

            let (data, _) = try await URLSession.shared.data(for: request)
            let prediction = try JSONDecoder().decode(LLMPrediction.self, from: data)

            switch prediction.status {
            case "succeeded":
                // LLM output is an array of strings, join them
                return prediction.output?.joined() ?? ""
            case "failed":
                throw AppError.generationFailed(prediction.error ?? "Suggestion failed")
            case "canceled":
                throw AppError.generationFailed("Suggestion was canceled")
            default:
                continue  // Still processing
            }
        }
    }
}

// MARK: - LLM Response Model

private struct LLMPrediction: Decodable {
    let id: String
    let status: String
    let output: [String]?
    let error: String?
}
