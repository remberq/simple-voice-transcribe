import Foundation

class RemoteTranscriptionService: TranscriptionService {
    
    private let apiURL: URL
    private let model: String
    private let apiKey: String
    private let logPrefix: String
    
    init(apiKey: String, model: String, baseURL: String) {
        self.apiKey = apiKey
        self.model = model
        
        let urlStr = baseURL.hasSuffix("/chat/completions") ? baseURL : baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        self.apiURL = URL(string: urlStr) ?? URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        
        if self.apiURL.host?.contains("openrouter.ai") == true {
            self.logPrefix = "[OpenRouter]"
        } else {
            self.logPrefix = "[CustomSTT]"
        }
    }
    
    func transcribe(audioFileURL: URL) async throws -> String {
        let maskedKey = apiKey.count > 8 ? "\(apiKey.prefix(4))...\(apiKey.suffix(4))" : "***"
        print("\(logPrefix) Using API key: \(maskedKey) (length: \(apiKey.count))")
        
        guard apiKey.count > 5 else {
            throw TranscriptionError.missingAPIKey
        }
        
        // Read audio file and encode to base64
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioFileURL)
        } catch {
            throw TranscriptionError.emptyAudio
        }
        
        guard !audioData.isEmpty else {
            throw TranscriptionError.emptyAudio
        }
        
        print("\(logPrefix) Audio file size: \(audioData.count) bytes")
        
        let base64Audio = audioData.base64EncodedString()
        
        // Build the multimodal chat request with inline audio
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Transcribe the following audio recording. Return ONLY the transcribed text, without any additional commentary, labels, or formatting. If the audio is in a non-English language, transcribe it in the original language."
                        ],
                        [
                            "type": "input_audio",
                            "input_audio": [
                                "data": base64Audio,
                                "format": "wav"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 4096,
            "temperature": 0
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("VoiceOverlay/1.0", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Voice Overlay macOS App", forHTTPHeaderField: "X-Title")
        request.httpBody = jsonData
        request.timeoutInterval = 30
        
        print("\(logPrefix) Sending transcription request to \(apiURL) with model \(model)...")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("\(logPrefix) Network request failed: \(error)")
            throw TranscriptionError.networkError
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError
        }
        
        print("\(logPrefix) Response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            throw TranscriptionError.apiError(message: "Unauthorized — check your OpenRouter API key.")
        }
        
        if httpResponse.statusCode == 402 {
            throw TranscriptionError.apiError(message: "Insufficient credits on OpenRouter account.")
        }
        
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("\(logPrefix) Error response body: \(body)")
            throw TranscriptionError.apiError(message: "Server returned HTTP \(httpResponse.statusCode): \(body)")
        }
        
        // Parse the chat completion response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("\(logPrefix) Unexpected response structure: \(body)")
            throw TranscriptionError.processFailed
        }
        
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("\(logPrefix) Transcription result (\(trimmed.count) chars): \(trimmed.prefix(100))...")
        guard !trimmed.isEmpty else {
            throw TranscriptionError.processFailed
        }
        
        return trimmed
    }
}
