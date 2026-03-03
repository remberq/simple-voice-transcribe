# Troubleshooting Voice Overlay

## Welcome Window Did Not Appear
1. Open tray menu and select `Приветствие`.
2. If first-launch auto-show is being tested, reset defaults and relaunch:
```bash
defaults delete com.anti.VoiceOverlay
```

## Overlay Does Not React
1. Verify app is running from `build/VoiceOverlay.app`.
2. Check menu bar icon is present.
3. Open Settings and reset hotkey to default.

## Recording Fails
1. Open `System Settings > Privacy & Security > Microphone`.
2. Ensure Voice Overlay is allowed.
3. Re-open Welcome and use the microphone button to verify status.

## Keychain Toggle Looks Wrong
1. Open Welcome and check `Хранить API-ключи в Keychain`.
2. Open Settings -> Система and verify the toggle matches.
3. Restart app if you changed the mode while editing providers.

## No Dock Icon
Expected behavior. App runs as menu-bar utility (`LSUIElement=true`).
