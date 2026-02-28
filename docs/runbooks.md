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
  - In Settings -> Transcription, disable `Store API key in Keychain`.
  - Key is kept in memory and cleared on app exit.

## Manual Verification (Core)
1. Launch app; verify menu-bar icon exists and Dock icon is hidden.
2. Open Notes and place caret in text area.
3. Trigger hotkey; verify overlay appears and Notes keeps focus.
4. Click mic, speak for 2-3 seconds, click mic again.
5. Verify notification appears and transcript inserts into Notes.
6. Repeat in Slack/Chrome input.
7. Repeat on non-editable surface (Finder desktop): verify no insertion.

## Manual Verification (Settings & History)
1. Open Settings -> Горячая клавиша. Change shortcut, verify it works.
2. Perform a transcription, verify hovering over the system tray icon says "Идет обработка файла" promptly.
3. Open "Транскрибации" window from tray.
4. Verify previous transcription is listed. Click "Копировать", verify clipboard content.
5. Create a failed transcription (e.g. invalid API key), click "Повторить".
6. Click "Очистить" to remove all history.

## Manual Verification (File Upload)
1. Press `Cmd+Shift+D` → verify green overlay with file icon appears.
2. Click icon → verify file picker opens, shows only audio files.
3. Select an `.m4a` file → verify "Файл загружается" notification appears.
4. Wait for transcription → verify result copied to clipboard and appears in History.
5. Repeat with `.mp3` and `.wav` files.
6. Try file > 25 MB → verify error notification appears.
7. Press `Cmd+Shift+D`, then press Escape → verify overlay dismissed.
8. Open file picker and cancel → verify overlay dismissed cleanly.

## Permission Verification
1. Remove microphone permission in System Settings.
2. Trigger recording; verify error state and guidance behavior.
3. Remove accessibility permission.
4. Verify transcription still runs but insertion is blocked.
