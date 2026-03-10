# Voice Overlay Specification

## Product Scope
Voice Overlay is a macOS menu-bar utility (`LSUIElement`) that records voice and returns text into the active work context.

## Welcome Flow & Onboarding Enforcement
1. The app verifies two conditions before allowing use of the overlay: 
   - User has completed onboarding (`hasCompletedWelcome`).
   - Microphone permission is explicitly granted (`AVAuthorizationStatus.authorized`).
2. If either condition is unmet on App launch or when pressing the global hotkey, the Welcome window opens instead of the overlay.
3. Closing the Welcome window without pressing `Начать` leaves setup incomplete; the next hotkey press will reopen the Welcome window.
4. Pressing `Начать` **without** microphone access shows a red inline error message and blocks completion.
5. Pressing `Начать` **with** microphone access marks onboarding as complete (`hasCompletedWelcome = true`) and closes the window.
6. Welcome can always be reopened manually from the status-bar menu.

## Current Behavior (Implemented)
1. User presses the global hotkey (default `Cmd+Shift+Space`).
2. Overlay appears as a non-activating floating panel near caret, focused element, or mouse fallback.
3. Click mic to start recording.
   - *Pause feature*: While recording, pressing the configurable pause key (default `Space`) pauses the recording and changes the background to orange with a pause icon. Pressing it again resumes recording. The pause key can be changed in Settings.
   - *Cancel feature*: While recording or paused, pressing the configurable cancel key (default `Escape`) discards the current audio, closes the overlay, and does not start transcription. The cancel key can be changed in Settings and supports either a single key or a combination.
4. Click mic while recording to stop and start transcription. Click mic while paused to resume recording.
   - Pressing the main hotkey while recording or paused always stops and sends for transcription.
5. App transcribes audio using selected provider:
   - `mock` (development default)
   - `openai` / `openrouter` / `custom` / `raif`
6. Result handling:
   - added to History window and tray tooltip tracks live processing
   - copied to clipboard on success
7. Overlay hides after completion.

## Direct File Upload
1. User presses file upload hotkey (default `Cmd+Shift+D`).
2. Green overlay with a file icon appears near cursor.
3. Click icon → `NSOpenPanel` opens, filtered to audio formats: wav, mp3, m4a, mp4, webm, ogg, flac.
4. File size validated (max 25 MB).
5. Non-WAV files auto-converted to WAV via macOS `afconvert` for providers requiring WAV input.
6. "Файл загружается" notification appears; user can click it to open History.
7. Same transcription → clipboard flow as voice recording.

## Welcome Window Sections
- Intro text.
- Microphone status + explicit button for permission request.
- Hotkey hint (text only, no inline editor) for the main hotkey, pause hotkey, and cancel hotkey.
- Keychain toggle (`storeAPIKeyInKeychain`) with short explanation.
- Action buttons: `Начать` and `Закрыть`.

## UI States
- `idle`: mic icon
- `recording`: red background + live equalizer
- `paused`: orange background + pause icon
- `transcribing`: spinner
- `error`: warning icon; tap opens microphone settings and closes overlay
- `fileUpload`: green background + doc.badge.plus icon; tap opens file picker

## Required Permissions
- Microphone (`NSMicrophoneUsageDescription`)

## Out of Scope (Current Build)
- Native Apple Speech transcription path (`SFSpeechRecognizer`) is not used.
- Hold-to-stop interaction is not used.
- Accessibility-dependent behavior is de-scoped from current permission/onboarding flow.
