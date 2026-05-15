# Changelog

All notable changes to flightplan are documented here. Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html); breaking
changes bump the major.

## 1.1.0 — 2026-05-14

`/handoff` skill (added in 1.0.0's merge train but never released) is
now packaged. The headline change is the **runway queue gate moves from
status `Todo` to label `ready-for-agent`**.

### Added

- Skill: [`/handoff`](skills/handoff/SKILL.md) — compact the current
  conversation into a handoff document so another agent can continue
  the work.
- State label: `ready-for-agent`. Added to both tracker adapters
  (`skills/tracker-linear/labels.yml`,
  `skills/tracker-github/labels.yml`). At most one state label per
  issue — `ready-for-agent` is mutually exclusive with `needs-info`,
  `needs-human`, `wontfix`, `needs-triage`.

### Fixed

- `/handoff` temp path is portable on macOS. The original
  `mktemp -t handoff-XXXXXX.md` produced literal `handoff-XXXXXX.md.<random>`
  on BSD `mktemp` (any suffix after `X`s blocks expansion). Replaced
  with `${TMPDIR:-/tmp}/handoff-$(date +%Y%m%d-%H%M%S).md`.

### Changed (BREAKING for runway)

- **Runway queue is now a label, not a status.** runway must drain
  by `label = ready-for-agent` instead of `status = Todo`. Reason:
  Linear's GitHub integration auto-mutates status when a PR
  cross-references an issue (`Triage`/`Backlog`/`Todo` → `In Progress`),
  silently draining a status-gated queue every time someone mentions an
  issue in a PR. Labels are not touched by the integration.
- `/triage` advance transition now applies the `ready-for-agent` label.
  Status is left to humans + the Linear/GitHub integration, with one
  exception: if the issue's current status is `Triage` or `Backlog`,
  `/triage` advances it to `Todo` as a visibility cue. In-flight
  statuses (`In Progress` / `In Review` / `Reviewed`) are never
  mutated — read-only-on-active-work invariant preserved.
- HITL eject (`needs-human`) follows the same status policy.

### Migration notes

Backfill before runway switches its drain query:

1. **Linear**: apply `ready-for-agent` to every issue currently in
   `Todo` status that you actually want runway to pick up. A Linear
   saved view filtered by `status = Todo AND has no label
   ready-for-agent` makes this a one-pass click-through.
2. **GitHub adapter consumers**: the `ready-for-agent` label will be
   lazily created on first use via the existing label-creation flow;
   no manual setup needed.
3. **Runway**: update the drain query and any state-mutation logic on
   pickup. Recommended: remove the `ready-for-agent` label as the
   issue is claimed (atomic claim signal). On run failure, re-apply
   the label or flip to `needs-human` for triage.

The canonical `todo` status is **not removed** — it's still in the
state vocabulary and the Linear-native `Todo` is still where humans
park work. It just no longer gates runway.

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
