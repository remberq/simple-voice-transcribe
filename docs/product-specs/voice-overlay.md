# Voice Overlay Product Flow

## Happy Path
1. Focus an editable field in another app.
2. Press hotkey.
3. Overlay appears without stealing focus.
4. Click mic -> recording starts.
5. Click mic again -> recording stops, transcription runs.
6. Transcript is inserted (if safe) and/or copied based on settings.
7. Overlay closes.

## Safety Rules
- If the frontmost app changed since recording started, insertion is blocked.
- If focused element is not editable, insertion is blocked.
- If insertion is blocked, user still gets notification with result status.

## Error Paths
- Missing microphone permission: overlay enters error state; second tap opens System Settings.
- Remote provider selected without API key: transcription falls back to mock provider.
- Remote API/network errors: user gets notification with failure reason.
