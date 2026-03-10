# Voice Overlay Runbook

## Build and Run
- Build: `make build`
- Run: `make run`
- Test: `make test`
- Docs links check: `make lint-docs`
- Clean: `make clean`

## Reset Local State
- Reset `UserDefaults`:
```bash
defaults delete com.anti.VoiceOverlay
```
- Remove stored API key:
```bash
security delete-generic-password -s "com.anti.VoiceOverlay" -a "com.anti.VoiceOverlay.APIKey"
```
- Session-only mode:
  - In Welcome or Settings, disable `Хранить API-ключи в Keychain`.
  - Key is kept in memory and cleared on app exit.

## Manual Verification (Core)
1. Launch app; verify menu-bar icon exists and Dock icon is hidden.
2. On first launch, verify Welcome window opens automatically.
3. Open Notes and place caret in text area.
4. Trigger hotkey; verify overlay appears and Notes keeps focus.
5. Click mic, speak for 2-3 seconds, click mic again.
6. Verify notification appears and transcript is copied/visible in History.

## Manual Verification (Welcome)
1. Close Welcome without pressing `Начать`.
2. Restart app.
3. Verify Welcome does not auto-open again.
4. Open tray menu and click `Приветствие`.
5. Verify Welcome opens manually.
6. Press `Начать` and verify `hasCompletedWelcome` behavior in logs/debugging if needed.

## Manual Verification (Settings & History)
1. Open Settings -> Горячая клавиша. Change shortcut, verify it works.
2. In Settings -> Горячая клавиша, change the pause key and cancel key, verify both save and work during recording.
3. Try to assign a duplicate shortcut that matches main/file-upload/pause/cancel. Verify Settings shows a validation error and keeps the previous shortcut.
4. In Welcome, toggle `Хранить API-ключи в Keychain` and verify the same value in Settings -> Система.
5. Perform a transcription, verify tray tooltip says "Идет обработка файла" while active.
6. Open "Транскрибации" window from tray.
7. Verify previous transcription is listed. Click "Копировать", verify clipboard content.
8. Create a failed transcription (e.g. invalid API key), click "Повторить".
9. Click "Очистить" to remove all history.

## Manual Verification (File Upload)
1. Press `Cmd+Shift+D` → verify green overlay with file icon appears.
2. Click icon → verify file picker opens, shows only audio files.
3. Select an `.m4a` file → verify "Файл загружается" notification appears.
4. Wait for transcription → verify result copied to clipboard and appears in History.
5. Repeat with `.mp3` and `.wav` files.
6. Try file > 25 MB → verify error notification appears.
7. Press `Cmd+Shift+D`, then press Escape → verify overlay dismissed.
8. Open file picker and cancel → verify overlay dismissed cleanly.

## Manual Verification (Cancel Recording)
1. Start recording and press `Escape`.
2. Verify overlay closes, state returns to idle, and no transcription notification appears.
3. Start recording, pause it, then press `Escape`.
4. Verify the paused recording is discarded and no History item is created.
5. Change cancel hotkey to a single key, start recording, and verify it cancels.
6. Change cancel hotkey to a key combination, start recording, and verify it cancels.

## Permission Verification
1. Set microphone to `Not Determined` (fresh install/reset permissions) and open Welcome.
2. Click `Запросить доступ к микрофону`, verify system prompt appears.
3. Test denied path: deny permission and click button again.
4. Verify app opens `System Settings > Privacy & Security > Microphone`.
5. Test authorized path: allow permission and verify recording starts from overlay.
