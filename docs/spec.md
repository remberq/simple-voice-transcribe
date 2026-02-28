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

## UI States
- `idle`: mic icon
- `recording`: red background + live equalizer
- `transcribing`: spinner
- `error`: warning icon; tap opens microphone settings and closes overlay

## Required Permissions
- Microphone (`NSMicrophoneUsageDescription`)
- Accessibility (for focus checks and synthetic paste)

## Out of Scope (Current Build)
- Native Apple Speech transcription path (`SFSpeechRecognizer`) is not used.
- Hold-to-stop interaction is not used.
- Pause/Resume is not exposed in the UI flow.
