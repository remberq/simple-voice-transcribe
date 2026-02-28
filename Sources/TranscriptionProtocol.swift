import Foundation

enum TranscriptionError: Error, LocalizedError {
    case networkError
    case missingAPIKey
    case apiError(message: String)
    case emptyAudio
    case processFailed
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error — check your internet connection."
        case .missingAPIKey:
            return "API key is missing or invalid. Set it in Settings → Transcription."
        case .apiError(let message):
            return "API error: \(message)"
        case .emptyAudio:
            return "Audio file is empty or could not be read."
        case .processFailed:
            return "Could not parse transcription from API response."
        case .notImplemented:
            return "This transcription provider is not yet implemented."
        }
    }
}

protocol TranscriptionService {
    func transcribe(audioFileURL: URL) async throws -> String
}

class MockTranscriptionService: TranscriptionService {
    func transcribe(audioFileURL: URL) async throws -> String {
        // Deterministic delay for E2E testing
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5.0 seconds
        
        // Ensure file exists (rough mimic of validation)
        let fileExists = FileManager.default.fileExists(atPath: audioFileURL.path)
        if !fileExists {
            throw TranscriptionError.emptyAudio
        }
        
        return "This is a mocked transcription result."
    }
}
