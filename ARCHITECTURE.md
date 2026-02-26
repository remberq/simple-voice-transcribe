# Voice Overlay Architecture

## Runtime Modules
- `AppDelegate`: status bar menu, app startup, hotkey wiring, settings window.
- `HotkeyManager`: global hotkey registration via Carbon `RegisterEventHotKey`.
- `OverlayController`: panel lifecycle, state machine, record/transcribe orchestration.
- `OverlayView` + `MicButtonView` + `EqualizerBarsView`: overlay UI states.
- `RecorderService`: `AVAudioRecorder` WAV capture + level metering.
- `FocusAndInsertService`: interaction anchoring, focus safety checks, clipboard/paste insertion.
- `PermissionsCoordinator`: microphone + accessibility checks and settings deep links.
- `SettingsManager` + `SettingsView`: persisted settings and API key storage.
- `TranscriptionService` protocol:
  - `MockTranscriptionService`
  - `RemoteTranscriptionService` (OpenRouter HTTP)

## State Machine
`idle -> recording -> transcribing -> idle`

Exceptional transitions:
- `idle -> error` when microphone permission is missing.
- `recording -> idle` on dismiss/hide.
- `recording -> transcribing` on stop (tap or hotkey toggle).

## Build System
- No `.xcodeproj`.
- Native app bundle built by `Makefile` using `swiftc`.
