# Quality Gates

A change is not complete until all gates below pass.

## Required Gates
1. Build passes: `make build`.
2. Tests pass: `make test`.
3. Docs links pass: `make lint-docs`.
4. Manual smoke checklist updated and executed for touched behavior (`docs/testing/manual-smoke.md`).
5. If architecture or behavior changed materially, update `docs/spec.md` and add/update ADR in `docs/adr/`.
6. Re-verify overlay remains non-activating after UI changes.
7. Missing-permission paths must fail safely (no crash, no silent failure).
