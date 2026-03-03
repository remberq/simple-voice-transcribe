# Voice Overlay Product Flow

## First Launch
1. App starts as menu-bar utility.
2. Welcome window opens automatically once.
3. User can explicitly request microphone access from Welcome.
4. User can close Welcome or press `Начать`.
5. `Начать` marks onboarding as completed.

## Happy Path
1. Focus an editable field in another app.
2. Press hotkey.
3. Overlay appears without stealing focus.
4. Click mic -> recording starts.
5. Click mic again -> recording stops, transcription runs.
6. Transcript is copied and tracked in History.
7. Overlay closes.

## Welcome Reopen Flow
1. User opens tray menu.
2. Selects `Приветствие`.
3. Welcome window opens regardless of completion state.

## Error Paths
- Missing microphone permission: overlay enters error state; tap opens System Settings.
- Welcome permission button behavior:
  - `notDetermined`: requests microphone access.
  - `denied`/`restricted`: opens System Settings for microphone privacy.
  - `authorized`: shows current authorized status.
- Remote provider selected without API key: transcription falls back to mock provider.
- Remote API/network errors: user gets notification with failure reason, and job is marked Failed in History.

## Retry / History Flow
1. User can open "Транскрибации" (History) from the system tray menu.
2. The UI lists all pending, completed, and failed jobs.
3. User can click "Повторить" on any failed or previous jobs to re-transcribe the cached audio.
4. User can click the "Copy" icon to retrieve previous results.
