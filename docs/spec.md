# Voice Overlay Specification

## Product Scope
Voice Overlay is a macOS menu-bar utility (`LSUIElement`) that records voice and returns text into the active work context.

## Current Behavior (Implemented)
1. User presses the global hotkey (default `Cmd+Shift+Space`).
2. Overlay appears as a non-activating floating panel near caret, focused element, or mouse fallback.
3. Click mic to start recording.
4. Click mic again, or press hotkey while recording, to stop and start transcription.
5. App transcribes audio using selected provider:
   - `mock` (development default)
   - `openai` / `openrouter` / `custom` / `raif` (Raiffeisen, featuring custom prompts/languages)
   - Customizable global hotkey through System Settings tab (default `Cmd+Shift+Space`)
   - `mock` (default)
   - `remote` (OpenRouter, requires API key in Keychain)
   - remote key storage mode: Keychain (persistent) or session-only (memory)
6. Result handling:
   - inserted in History window and Tray tooltip tracks live processing
   - optional clipboard copy (`alwaysCopy` setting)
   - optional insertion via simulated `Cmd+V` when focused element appears editable and frontmost app is unchanged
7. Overlay hides after completion.

## Direct File Upload
1. User presses file upload hotkey (default `Cmd+Shift+D`).
2. Green overlay with a file icon appears near cursor.
3. Click icon → `NSOpenPanel` opens, filtered to audio formats: wav, mp3, m4a, mp4, webm, ogg, flac.
4. File size validated (max 25 MB).
5. Non-WAV files auto-converted to WAV via macOS `afconvert` for providers requiring WAV input.
6. "Файл загружается" notification appears; user can click it to open History.
7. Same transcription → clipboard flow as voice recording.

## UI States
- `idle`: mic icon
- `recording`: red background + live equalizer
- `transcribing`: spinner
- `error`: warning icon; tap opens microphone settings and closes overlay
- `fileUpload`: green background + doc.badge.plus icon; tap opens file picker

## Required Permissions
- Microphone (`NSMicrophoneUsageDescription`)
- Accessibility (for focus checks and synthetic paste)

## Out of Scope (Current Build)
- Native Apple Speech transcription path (`SFSpeechRecognizer`) is not used.
- Hold-to-stop interaction is not used.
- Pause/Resume is not exposed in the UI flow.
