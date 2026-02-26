# Troubleshooting Voice Overlay

## Overlay Does Not React
1. Verify app is running from `build/VoiceOverlay.app`.
2. Check menu bar icon is present.
3. Open Settings and reset hotkey to default.

## Recording Fails
1. Open `System Settings > Privacy & Security > Microphone`.
2. Ensure Voice Overlay is allowed.

## Insertion Fails
1. Open `System Settings > Privacy & Security > Accessibility`.
2. Ensure Voice Overlay is allowed.
3. Test in known editable fields (Notes text area, web input).

## No Dock Icon
Expected behavior. App runs as menu-bar utility (`LSUIElement=true`).
