# Changelog

All notable changes to flightplan are documented here. Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html); breaking
changes bump the major.

## 1.0.0 — 2026-05-08

First stable release after the pivot away from the AFK governance
pipeline. flightplan is now a small, self-contained set of advisory
skills that drive a tracker issue from raw inbox into a state
[runway](https://github.com/ValescoAgency/runway) can pick up.

### Removed

- Skills: `/draft-contract`, `/attest`, `/brief-to-contract`,
  `/run-attested`. The contract authoring + attestation chain is gone;
  trust now comes from human PR review of runway's output, not
  pipeline gates.
- Files: `skills/triage/AGENT-BRIEF.md`, `.afk/` directory and
  `.afk/config.yml`, `docs/refactor-plan.md`, `docs/gaps.md`,
  `docs/starter-set.md`.
- Concepts dropped from every surviving skill and doc: goal-contract,
  attestation, friction matrix, protected paths, `afkEligible`,
  preflight, label-handler, tier system, customer field as a hard
  requirement.

### Changed

- `/triage` deliverable: instead of posting an Agent Brief comment, it
  now edits the issue body to have sharp acceptance criteria. runway
  reads the body directly, so triage's job is making the body
  unambiguous.
- Canonical state names: `ready-for-agent` → Linear `Todo` (the queue
  runway drains), `ready-for-human` → label `needs-human` (issues
  runway skips).
- `/diagnose` no longer references contract `verification.commands` or
  G10 verifier determinism. The six-phase debugging discipline is
  intact; downstream is just `/triage` → `Todo` → runway.
- `/tracker-linear` and `/tracker-github`: contract-flavored
  capabilities (customer field as hard requirement, attestation
  linking, AFK-eligibility flag reads) dropped. The read / write /
  transition surface — what runway-prep actually needs — survives.
- `README.md`, `CONTEXT.md`, `docs/workflow.md`, ADR-0001, plugin
  metadata: all rewritten or simplified to reflect the new shape.

### Migration notes for marketplace consumers

This is a breaking change. If you were using any of the removed skills,
they're gone — the runway README explains the new flow. If you were
relying on `tracker-*` capabilities tied to contracts, those are gone
too; the surviving capabilities are documented in each tracker
adapter's `SKILL.md`.

No deprecation period — the AFK pipeline is being shut down at the
same time as this release.

## Pre-1.0.0

This file didn't exist. See `git log` for history.
