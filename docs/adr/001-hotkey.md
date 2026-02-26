# ADR 001: Global Hotkey via Carbon

## Status
Accepted

## Context
Overlay must be triggered globally while the app stays in accessory/menubar mode.

## Decision
Use Carbon `RegisterEventHotKey` in `HotkeyManager`.

## Consequences
- Stable global shortcut behavior for this app type.
- Requires Carbon interop and explicit register/unregister handling.
