# Transcription Integration

## Protocol
All providers conform to:

```swift
func transcribe(audioFileURL: URL) async throws -> String
```

## Implemented Providers
- `MockTranscriptionService`
  - deterministic test provider
  - validates input file existence
- `RemoteTranscriptionService`
  - endpoint: OpenRouter chat completions API
  - audio: inline base64 WAV
  - model constant is defined in source (`Sources/RemoteTranscriptionService.swift`)

## Error Contract
Provider errors should map to `TranscriptionError` cases:
- `networkError`
- `missingAPIKey`
- `apiError(message:)`
- `emptyAudio`
- `processFailed`
