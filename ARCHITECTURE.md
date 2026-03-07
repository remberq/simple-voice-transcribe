# Voice Overlay Architecture

## Runtime Modules
- `AppDelegate`: status bar menu, app startup, hotkey wiring, settings/history/welcome windows, file-upload entrypoint.
- `WelcomeView`: first-launch onboarding UI (intro, microphone, hotkey hint, keychain toggle).
- `HotkeyManager`: global hotkey registration via Carbon `RegisterEventHotKey`. Supports three hotkeys: record toggle (id=1), file upload (id=2), and a dynamically registered configurable pause/resume key (id=3, default Space, stored in `SettingsManager`, active only during recording/paused states).
- `AudioMIMEHelper`: MIME type detection, UTType filtering for NSOpenPanel, file size validation (25 MB limit), and `input_audio.format` mapping.
- `OverlayController`: panel lifecycle, state machine, record/transcribe orchestration.
- `OverlayView` + `MicButtonView` + `EqualizerBarsView`: overlay UI states.
- `RecorderService`: `AVAudioRecorder` WAV capture + level metering.
- `PermissionsCoordinator`: microphone status, explicit microphone request, and deep link to microphone privacy settings.
- `SettingsManager` + `SettingsView`: persisted settings and API key storage.
- `TranscriptionHistoryManager` + `HistoryView`: tracks transcription jobs (progress, completion, errors) with retry/copy actions.
- `TranscriptionService` protocol and provider implementations.

## State Machine
`idle <-> recording -> transcribing -> idle`
`idle -> fileUpload -> idle` (file picker flow)
`recording <-> paused` (toggled by configurable pause key, default Space)

Exceptional transitions:
- `idle -> error` when microphone permission is missing.
- `recording -> idle` or `paused -> idle` on dismiss/hide.
- `recording -> transcribing` on mic tap or main hotkey toggle.
- `paused -> recording` on mic tap (resume).
- `paused -> transcribing` on main hotkey toggle (stop and send).
- `idle -> fileUpload` on file upload hotkey (`Cmd+Shift+D`).
- `fileUpload -> idle` after file selection or cancel.

## First-Launch Lifecycle / Onboarding
- On startup, `AppDelegate` checks if setup is complete (`hasCompletedWelcome`) and if microphone permission is granted.
- If either condition is not met, the Welcome window is shown, overriding the overlay.
- `hasCompletedWelcome` is set only when the user presses `Начать` *and* microphone permission is already granted.
- Pressing the hotkey while onboarding is incomplete will redirect to the Welcome window rather than opening the overlay.

## Build System
- No `.xcodeproj`.
- Native app bundle built by `Makefile` using `swiftc`.
