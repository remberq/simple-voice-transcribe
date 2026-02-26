# ADR 003: Safe Paste-Based Insertion

## Status
Accepted

## Context
Direct AX insertion is inconsistent across macOS apps. We need predictable behavior with low risk of destructive insertion.

## Decision
Use focus/editability checks via Accessibility APIs, then insert using clipboard + synthetic `Cmd+V` when safe.

## Consequences
- Better cross-app compatibility.
- Requires accessibility permission for reliable safety checks.
- Clipboard behavior is controlled by settings and can affect user expectations.
