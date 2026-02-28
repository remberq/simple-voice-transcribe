import Foundation
import UniformTypeIdentifiers

struct AudioMIMEHelper {
    
    /// Supported audio extensions for NSOpenPanel filtering
    static let allowedExtensions = ["wav", "mp3", "m4a", "mp4", "webm", "mpga", "mpeg", "ogg", "flac"]
    
    /// UTTypes for NSOpenPanel's allowedContentTypes
    static var allowedContentTypes: [UTType] {
        var types: [UTType] = [.wav, .mp3, .mpeg4Audio, .mpeg4Movie]
        if let webm = UTType(filenameExtension: "webm") { types.append(webm) }
        if let ogg = UTType(filenameExtension: "ogg") { types.append(ogg) }
        if let flac = UTType(filenameExtension: "flac") { types.append(flac) }
        types.append(.audio) // Catch-all for audio types
        return types
    }
    
    /// Maximum file size in bytes (25 MB — OpenAI Whisper limit)
    static let maxFileSizeBytes: Int64 = 25 * 1024 * 1024
    
    /// Detect MIME type from file extension
    static func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp3", "mpga":  return "audio/mpeg"
        case "m4a":          return "audio/mp4"
        case "mp4", "mpeg":  return "audio/mp4"
        case "wav":          return "audio/wav"
        case "webm":         return "audio/webm"
        case "ogg":          return "audio/ogg"
        case "flac":         return "audio/flac"
        default:             return "application/octet-stream"
        }
    }
    
    /// Returns the short format string (e.g. "wav") for the `input_audio.format` field
    /// used by OpenRouter / chat-completion endpoints.
    static func audioFormat(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp3", "mpga":  return "mp3"
        case "m4a":          return "m4a"
        case "mp4", "mpeg":  return "mp4"
        case "wav":          return "wav"
        case "webm":         return "webm"
        case "ogg":          return "ogg"
        case "flac":         return "flac"
        default:             return "wav"
        }
    }
    
    /// Validate file size. Returns nil if OK, or an error message if too large.
    static func validateFileSize(at url: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return "Не удалось определить размер файла."
        }
        if size > maxFileSizeBytes {
            let mbSize = Double(size) / (1024 * 1024)
            return String(format: "Файл слишком большой (%.1f МБ). Максимум — 25 МБ.", mbSize)
        }
        if size == 0 {
            return "Файл пустой."
        }
        return nil
    }
}
