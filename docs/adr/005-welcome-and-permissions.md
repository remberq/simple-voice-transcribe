# ADR 005: Welcome Onboarding and Explicit Microphone Permission

## Status
Accepted

## Date
2026-03-01

## Context
The startup flow requested microphone permission automatically during app launch. This made first-launch behavior implicit and coupled permissions to startup timing.

Project goals for this iteration:
- Introduce a dedicated first-launch Welcome window.
- Request microphone permission only by explicit user action.
- Keep onboarding re-openable from menu-bar UI.
- De-scope Accessibility-dependent permission behavior from current onboarding/runtime flow.

## Decision
1. Add a Welcome window shown automatically once per installation (`hasAutoShownWelcomeOnce`).
2. Add a completion flag (`hasCompletedWelcome`) set only on `Начать`.
3. Remove automatic microphone request from `applicationDidFinishLaunching`.
4. Request microphone access only from Welcome's explicit button.
5. Keep a permanent tray menu action to open Welcome manually.
6. Remove Accessibility permission requirements from active specs/runbooks for this flow.

## Consequences
- First launch becomes predictable and user-driven.
- Permission prompts are explicit and easier to test (`notDetermined`/`denied`/`authorized`).
- Closing Welcome without completion no longer re-triggers auto-show, but manual reopen remains available.
- Existing docs that assumed Accessibility-dependent permission flow are superseded.

## Supersedes / Affects
- Supersedes parts of ADR 003 that tied runtime behavior to Accessibility checks in active permission-path documentation.
