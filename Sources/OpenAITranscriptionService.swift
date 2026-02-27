import Foundation

class OpenAITranscriptionService: TranscriptionService {
    
    private let baseURL: URL
    private let model: String
    private let apiKey: String
    
    // Default to OpenAI's public API, but allow overrides for custom endpoints
    init(apiKey: String, model: String = "whisper-1", baseURL: String = "https://api.openai.com/v1") {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = URL(string: baseURL) ?? URL(string: "https://api.openai.com/v1")!
    }
    
    func transcribe(audioFileURL: URL) async throws -> String {
        let maskedKey = apiKey.count > 8 ? "\(apiKey.prefix(4))...\(apiKey.suffix(4))" : "***"
        print("[OpenAI-STT] Using API key: \(maskedKey)")
        
        guard apiKey.count > 5 else {
            throw TranscriptionError.missingAPIKey
        }
        
        // Read audio file
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioFileURL)
        } catch {
            throw TranscriptionError.emptyAudio
        }
        
        guard !audioData.isEmpty else {
            throw TranscriptionError.emptyAudio
        }
        
        let url = baseURL.appendingPathComponent("audio/transcriptions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Construct multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Add language parameter (optional, but good for speed if known, we omit for auto-detect by default)
        
        // Add response_format parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // Add file parameter
        let filename = audioFileURL.lastPathComponent
        let mimeType = "audio/wav" // Adjust if we record in m4a/aac
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        request.timeoutInterval = 60
        
        print("[OpenAI-STT] Sending request to \(url) (model: \(model))...")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranscriptionError.networkError
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError
        }
        
        if httpResponse.statusCode == 401 {
            throw TranscriptionError.apiError(message: "Unauthorized — check your OpenAI API key.")
        }
        
        if httpResponse.statusCode == 429 {
            throw TranscriptionError.apiError(message: "Rate limit exceeded or insufficient quota.")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP \(httpResponse.statusCode)"
            throw TranscriptionError.apiError(message: errorStr)
        }
        
        // Parse the response: { "text": "..." }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw TranscriptionError.processFailed
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranscriptionError.processFailed
        }
        
        return trimmed
    }
}
