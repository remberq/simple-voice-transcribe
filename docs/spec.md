# Voice Overlay Specification

## Product Scope
Voice Overlay is a macOS menu-bar utility (`LSUIElement`) that records voice and returns text into the active work context.

## First-Launch Welcome Flow
1. On first launch after installation, the app opens a Welcome window automatically.
2. Auto-show happens exactly once per installation (`hasAutoShownWelcomeOnce`).
3. Closing the Welcome window without pressing `Начать` does not trigger auto-show again.
4. Pressing `Начать` marks onboarding as completed (`hasCompletedWelcome = true`).
5. Welcome can always be reopened manually from the status-bar menu.

## Current Behavior (Implemented)
1. User presses the global hotkey (default `Cmd+Shift+Space`).
2. Overlay appears as a non-activating floating panel near caret, focused element, or mouse fallback.
3. Click mic to start recording.
4. Click mic again, or press hotkey while recording, to stop and start transcription.
5. App transcribes audio using selected provider:
   - `mock` (development default)
   - `openai` / `openrouter` / `custom` / `raif`
6. Result handling:
   - added to History window and tray tooltip tracks live processing
   - copied to clipboard on success
7. Overlay hides after completion.

## Welcome Window Sections
- Intro text.
- Microphone status + explicit button for permission request.
- Hotkey hint (text only, no inline editor).
- Keychain toggle (`storeAPIKeyInKeychain`) with short explanation.
- Action buttons: `Начать` and `Закрыть`.

## UI States
- `idle`: mic icon
- `recording`: red background + live equalizer
- `transcribing`: spinner
- `error`: warning icon; tap opens microphone settings and closes overlay

## Required Permissions
- Microphone (`NSMicrophoneUsageDescription`)

## Out of Scope (Current Build)
- Native Apple Speech transcription path (`SFSpeechRecognizer`) is not used.
- Hold-to-stop interaction is not used.
- Pause/Resume is not exposed in the UI flow.
- Accessibility-dependent behavior is de-scoped from current permission/onboarding flow.
