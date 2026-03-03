# Manual Smoke Test Checklist

## Setup
- Build and run latest code.
- Reset app defaults if you need to validate first-launch behavior.

## Checklist
1. First Launch Welcome
- Start app after reset.
- Expected: Welcome window opens automatically once.

2. Welcome Auto-Show Once
- Close Welcome with `Закрыть` (without `Начать`).
- Restart app.
- Expected: Welcome is not auto-shown again.

3. Welcome Manual Reopen
- Open tray menu and click `Приветствие`.
- Expected: Welcome opens every time from menu item.

4. Microphone Permission Button
- In Welcome with `notDetermined`, click request button.
- Expected: system microphone prompt appears.
- Deny permission and click again.
- Expected: app opens microphone settings page.
- Allow permission and click again.
- Expected: status shows authorized.

5. Keychain Toggle Sync
- Toggle `Хранить API-ключи в Keychain` in Welcome.
- Open Settings -> Система.
- Expected: toggle value matches.

6. Overlay Focus
- Open Notes and place caret.
- Press hotkey.
- Expected: overlay appears and Notes stays focused (non-activating).

7. Record/Stop/Transcribe
- Click mic to start recording.
- Speak.
- Click mic again.
- Expected: transcribing state, then completion notification/history entry.

8. Missing Microphone Permission
- Deny microphone and trigger recording from overlay.
- Expected: error state; app does not crash.

9. Hotkey Reload
- Open Settings and reset hotkey.
- Expected: hotkey still toggles overlay.
