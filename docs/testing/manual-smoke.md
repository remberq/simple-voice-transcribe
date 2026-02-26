# Manual Smoke Test Checklist

## Setup
- Build and run latest code.
- Confirm microphone and accessibility permissions can be toggled.

## Checklist
1. Overlay Focus
- Open Notes and place caret.
- Press hotkey.
- Expected: overlay appears and Notes stays focused.

2. Record/Stop/Transcribe
- Click mic to start recording.
- Speak.
- Click mic again.
- Expected: transcribing spinner, then completion notification.

3. Insertion (Editable Input)
- Run flow in Notes, Slack input, Chrome input field.
- Expected: text inserted when input is editable.

4. No Insertion (Non-Editable)
- Focus desktop/background.
- Run flow.
- Expected: no paste into UI; no crash.

5. Focus Changed Safety
- Start in Notes input.
- During transcription, switch to another app.
- Expected: insertion blocked.

6. Missing Microphone Permission
- Deny microphone and trigger recording.
- Expected: error state; app does not crash.

7. Missing Accessibility Permission
- Deny accessibility and run full flow.
- Expected: transcription works, insertion blocked.

8. Hotkey Reload
- Open Settings and reset hotkey.
- Expected: hotkey still toggles overlay.
