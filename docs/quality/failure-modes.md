# Failure Modes

## Rule
When state is uncertain, do not insert text into external apps.

## Current Handling
| Area | Failure | Behavior |
|---|---|---|
| Permissions | Microphone denied | Recording blocked; overlay enters error path. |
| Permissions | Accessibility denied | Flow can proceed, but insertion checks may fail and insertion is skipped. |
| Recording | Recorder setup/start fails | Stop flow safely; notify through logs/notification path. |
| Transcription | Network/API failure | Transcription fails with explicit error message. |
| Focus safety | Frontmost app changed | Insertion blocked. |
| Target editability | Focused element not editable | Insertion blocked. |
| Hotkey | Registration failure | App keeps running; hotkey-triggered overlay may be unavailable. |

## Residual Risk (Known)
`FocusAndInsertService.handleTranscription` can return a "copied only" result message in paths where clipboard copy may be disabled by settings. Keep this in mind during QA.
