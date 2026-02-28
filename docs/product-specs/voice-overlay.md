# Voice Overlay Product Flow

## Happy Path
1. Focus an editable field in another app.
2. Press hotkey.
3. Overlay appears without stealing focus.
4. Click mic -> recording starts.
5. Click mic again -> recording stops, transcription runs.
6. Transcript is inserted (if safe) and/or copied based on settings.
7. Overlay closes.

## File Upload Path
1. Press file upload hotkey (default `Cmd+Shift+D`).
2. Green overlay with doc.badge.plus icon appears.
3. Click icon → file picker opens (wav, mp3, m4a, mp4, webm, ogg, flac).
4. Select file → overlay hides, "Файл загружается" notification shown.
5. File enters transcription pipeline → result copied to clipboard.
6. Press Escape or click elsewhere → overlay dismissed.

## Safety Rules
- If the frontmost app changed since recording started, insertion is blocked.
- If focused element is not editable, insertion is blocked.
- If insertion is blocked, user still gets notification with result status.

## Error Paths
- Missing microphone permission: overlay enters error state; second tap opens System Settings.
- Remote provider selected without API key: transcription falls back to mock provider.
- Remote API/network errors: user gets notification with failure reason, and job is marked Failed in History.
- File too large (>25 MB): user gets error notification, job not created.
- Non-WAV files converted to WAV via `afconvert`; conversion failure shown as error notification.

## Retry / History Flow
1. User can open "Транскрибации" (History) from the system tray menu.
2. The UI lists all pending, completed, and failed jobs.
3. User can click "Повторить" on any failed or previous jobs to re-transcribe the cached audio seamlessly.
4. User can click the "Copy" icon to retrieve previous results.
