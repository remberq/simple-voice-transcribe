# ADR 004: Pluggable Transcription Provider

## Status
Accepted

## Context
Need fast E2E development and ability to switch providers without changing overlay flow.

## Decision
Define `TranscriptionService` protocol and ship two implementations:
- `MockTranscriptionService` for deterministic local testing
- `RemoteTranscriptionService` for production-like API transcription

## Consequences
- Provider swap is isolated from UI/orchestration logic.
- Remote path depends on API key management and network reliability.
