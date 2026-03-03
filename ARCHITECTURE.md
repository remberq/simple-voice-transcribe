# Voice Overlay Architecture

## Runtime Modules
- `AppDelegate`: status bar menu, app startup, hotkey wiring, settings/history/welcome windows.
- `WelcomeView`: first-launch onboarding UI (intro, microphone, hotkey hint, keychain toggle).
- `HotkeyManager`: global hotkey registration via Carbon `RegisterEventHotKey`.
- `OverlayController`: panel lifecycle, state machine, record/transcribe orchestration.
- `OverlayView` + `MicButtonView` + `EqualizerBarsView`: overlay UI states.
- `RecorderService`: `AVAudioRecorder` WAV capture + level metering.
- `PermissionsCoordinator`: microphone status, explicit microphone request, and deep link to microphone privacy settings.
- `SettingsManager` + `SettingsView`: persisted settings and API key storage.
- `TranscriptionHistoryManager` + `HistoryView`: tracks transcription jobs (progress, completion, errors) with retry/copy actions.
- `TranscriptionService` protocol and provider implementations.

## State Machine
`idle -> recording -> transcribing -> idle`

Exceptional transitions:
- `idle -> error` when microphone permission is missing.
- `recording -> idle` on dismiss/hide.
- `recording -> transcribing` on stop (tap or hotkey toggle).

## First-Launch Lifecycle
- On startup, `AppDelegate` checks `SettingsManager.hasAutoShownWelcomeOnce`.
- If `false`, it is set to `true` and Welcome window is shown.
- `hasCompletedWelcome` is set only when user presses `Начать`.

## Build System
- No `.xcodeproj`.
- Native app bundle built by `Makefile` using `swiftc`.
