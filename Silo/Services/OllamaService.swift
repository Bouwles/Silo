import Foundation

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaChatRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

struct OllamaChatResponse: Codable {
    let message: OllamaMessage
    let done: Bool
}

struct OllamaTagsResponse: Codable {
    let models: [OllamaModelEntry]
}

struct OllamaModelEntry: Codable {
    let name: String
}

@MainActor
class OllamaService: ObservableObject {
    static let shared = OllamaService()
    let baseURL = "http://localhost:11434"

    func isRunning() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func listModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models.map { $0.name }
    }

    func chat(model: String, messages: [OllamaMessage]) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = OllamaChatRequest(model: model, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return decoded.message.content
    }
}
