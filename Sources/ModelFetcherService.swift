import Foundation

struct FetchedModel: Identifiable, Hashable {
    let id: String
    let isFree: Bool
}

class ModelFetcherService {
    
    enum FetchError: Error {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case parsingError
    }
    
    static func fetchModels(providerType: String, apiKey: String, customBaseURL: String?) async throws -> [FetchedModel] {
        switch providerType {
        case "openai":
            return try await fetchOpenAIModels(apiKey: apiKey)
        case "openrouter":
            return try await fetchOpenRouterModels(apiKey: apiKey)
        case "gemini":
            return try await fetchGeminiModels(apiKey: apiKey)
        case "custom":
            guard let base = customBaseURL, !base.isEmpty else { return [] }
            let urlStr = base.hasSuffix("/chat/completions") ? base.replacingOccurrences(of: "/chat/completions", with: "") : base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return try await fetchCustomModels(baseURL: urlStr, apiKey: apiKey)
        default:
            return []
        }
    }
    
    private static func fetchOpenAIModels(apiKey: String) async throws -> [FetchedModel] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else { throw FetchError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw FetchError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            Logger.shared.error("OpenAI fetch models failed: \(httpResponse.statusCode)")
            throw FetchError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]] else { throw FetchError.parsingError }
        
        // Filter for STT capability (usually models with "whisper" in name)
        let models = dataArray.compactMap { dict -> FetchedModel? in
            guard let id = dict["id"] as? String else { return nil }
            if id.contains("whisper") {
                return FetchedModel(id: id, isFree: false)
            }
            return nil
        }
        
        return models.sorted { $0.id < $1.id }
    }
    
    private static func fetchOpenRouterModels(apiKey: String) async throws -> [FetchedModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { throw FetchError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("VoiceOverlay/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Voice Overlay macOS App", forHTTPHeaderField: "X-Title")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw FetchError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            Logger.shared.error("OpenRouter fetch models failed: \(httpResponse.statusCode)")
            throw FetchError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]] else { throw FetchError.parsingError }
        
        var parsedModels = [FetchedModel]()
        for dict in dataArray {
            guard let id = dict["id"] as? String else { continue }
            // Filter STT models: typical OpenRouter IDs contain "audio" or "whisper"
            let lowerId = id.lowercased()
            guard lowerId.contains("audio") || lowerId.contains("whisper") else { continue }
            
            var isFree = false
            if let pricing = dict["pricing"] as? [String: Any],
               let promptPrice = pricing["prompt"] as? String,
               promptPrice == "0" {
                isFree = true
            } else if let pricing = dict["pricing"] as? [String: Any], let promptPrice = pricing["prompt"] as? Double, promptPrice == 0 {
                isFree = true
            }
            
            parsedModels.append(FetchedModel(id: id, isFree: isFree))
        }
        
        return parsedModels.sorted { $0.id < $1.id }
    }
    
    private static func fetchGeminiModels(apiKey: String) async throws -> [FetchedModel] {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)") else { throw FetchError.invalidURL }
        let request = URLRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FetchError.invalidResponse }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let modelsArray = json?["models"] as? [[String: Any]] else { throw FetchError.parsingError }
        
        let models = modelsArray.compactMap { dict -> FetchedModel? in
            guard let name = dict["name"] as? String,
                  let methods = dict["supportedGenerationMethods"] as? [String] else { return nil }
            
            if methods.contains("generateContent") {
                let cleanName = name.replacingOccurrences(of: "models/", with: "")
                return FetchedModel(id: cleanName, isFree: false)
            }
            return nil
        }
        
        return models.sorted { $0.id < $1.id }
    }
    
    private static func fetchCustomModels(baseURL: String, apiKey: String) async throws -> [FetchedModel] {
        guard let url = URL(string: baseURL + "/models") else { throw FetchError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw FetchError.invalidResponse }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]] else { throw FetchError.parsingError }
        
        let models = dataArray.compactMap { dict -> FetchedModel? in
            guard let id = dict["id"] as? String else { return nil }
            return FetchedModel(id: id, isFree: false)
        }
        
        return models.sorted { $0.id < $1.id }
    }
}
