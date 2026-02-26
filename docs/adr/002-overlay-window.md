# ADR 002: Non-Activating NSPanel Overlay

## Status
Accepted

## Context
Overlay must be always visible on demand but must not take focus from the target app.

## Decision
Render overlay in borderless `NSPanel` with `.nonactivatingPanel`, `.floating`, and multi-space behavior.

## Consequences
- Preserves user focus in external apps.
- Requires explicit panel lifecycle management in `OverlayController`.
