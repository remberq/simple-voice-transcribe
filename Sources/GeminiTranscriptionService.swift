import Foundation

class GeminiTranscriptionService: TranscriptionService {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    private let model: String // e.g. "gemini-1.5-flash"
    private let apiKey: String
    
    init(apiKey: String, model: String = "gemini-1.5-flash") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func transcribe(audioFileURL: URL, onProgress: ((Double) -> Void)? = nil) async throws -> String {
        let maskedKey = apiKey.count > 8 ? "\(apiKey.prefix(4))...\(apiKey.suffix(4))" : "***"
        print("[Gemini-STT] Using API key: \(maskedKey)")
        
        guard apiKey.count > 5 else {
            throw TranscriptionError.missingAPIKey
        }
        
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioFileURL)
        } catch {
            throw TranscriptionError.emptyAudio
        }
        
        guard !audioData.isEmpty else {
            throw TranscriptionError.emptyAudio
        }
        
        let base64Audio = audioData.base64EncodedString()
        let mimeType = "audio/wav" // Depending on AVAudioRecorder settings
        
        // Build the URL: https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=...
        guard let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw TranscriptionError.apiError(message: "Invalid Gemini URL.")
        }
        
        // Gemini REST structure
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        [
                            "text": "Transcribe the following audio recording exactly as spoken. Return ONLY the transcribed text, without any markdown formatting, preamble, timestamps, or commentary. Keep the original language."
                        ],
                        [
                            "inlineData": [
                                "mimeType": mimeType,
                                "data": base64Audio
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0, // For deterministic transcription
                "maxOutputTokens": 2048
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        print("[Gemini-STT] Sending request to \(model)...")
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await AsyncUploadHelper.upload(request: request, data: jsonData, onProgress: onProgress)
        } catch {
            throw TranscriptionError.networkError
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError
        }
        
        if httpResponse.statusCode == 400 {
            throw TranscriptionError.apiError(message: "Bad Request. API key might be invalid or malformed.")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown HTTP \(httpResponse.statusCode)"
            print("[Gemini-STT] Unexpected response: \(errorStr)")
            throw TranscriptionError.apiError(message: "Gemini error: \(httpResponse.statusCode)")
        }
        
        // Parse Gemini response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw TranscriptionError.processFailed
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranscriptionError.processFailed
        }
        
        return trimmed
    }
}
