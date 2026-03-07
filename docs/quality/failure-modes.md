# Failure Modes

## Rule
When state is uncertain, do not insert text into external apps.

## Current Handling
| Area | Failure | Behavior |
|---|---|---|
| Onboarding | Welcome was never shown before | Auto-show once, then mark `hasAutoShownWelcomeOnce = true`. |
| Permissions | Microphone denied/restricted | Recording blocked; overlay enters error path; Welcome button opens system settings. |
| Permissions | Microphone not determined | Permission is requested only after explicit Welcome button action. |
| Recording | Recorder setup/start fails | Stop flow safely; notify through logs/notification path. |
| Transcription | Network/API failure | Transcription fails with explicit error message. |
| Hotkey | Registration failure | App keeps running; hotkey-triggered overlay may be unavailable. |

## Residual Risk (Known)
If microphone permission remains denied and user skips Welcome, recording attempts will continue to enter the error path until permission is changed in system settings.
