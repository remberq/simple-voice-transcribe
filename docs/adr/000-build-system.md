# ADR 000: Build System Without Xcode Project

## Status
Accepted

## Context
The app is a compact menubar utility with a small Swift codebase. We need deterministic, scriptable builds without `.xcodeproj` merge overhead.

## Decision
Build and package with `Makefile` + `swiftc`, producing a native `.app` bundle.

## Consequences
- Faster automated edits and CI scripting.
- No Interface Builder/Xcode project metadata management.
- Build steps are explicit and easy to audit.
