# Voice Overlay - Agent Rules & Navigation

## Rules for Agents
1. **No Xcode Projects**: Voice Overlay is built using a pure `Makefile` to compile Swift into a `.app` bundle natively. Do not add or try to generate `.xcodeproj` files unless explicitly approved via an ADR.
2. **Docs are the System of Record**: Before changing significant features, update the relevant specification in `docs/spec.md`. Any major decisions require an Architecture Decision Record in `docs/adr/`.
3. **No External Dependencies (where possible)**: Rely on Apple's native frameworks: AppKit, SwiftUI, Speech, AVFoundation, and Accessibility APIs.
4. **Task Groups**: Development should occur in atomic Task Groups. A Walkthrough should be generated for each completed feature slice.
5. **Post-Edit Build**: When finishing a cycle of changes, always use the `/post-edit-build` workflow command to kill the old process, clean, rebuild, and run the new application.

## Navigation
- `ARCHITECTURE.md`: Module decomposition and state machine.
- `docs/spec.md`: Formal product specifications, UI, and functionality.
- `docs/product-specs/voice-overlay.md`: Specific product flow and edge cases.
- `docs/runbooks.md`: Instructions for manual testing, verification, and debugging.
- `docs/adr/`: Architecture Decision Records.
- `docs/testing/`: Manual smoke test checklists.
- `docs/quality/`: Quality gates and metrics.
- `Sources/`: All Swift source code.
- `Makefile`: Build scripts for the Application.
## QUALITY GATE
Do not mark a TG complete unless:
- Manual smoke steps for that TG are written and executed (or explicitly not applicable).
- ADR updated if new non-trivial decision was made.
- Overlay does not activate or steal focus (re-verify after UI changes).
- Permissions missing path is handled (never crash or silently fail).