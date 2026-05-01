# ValescoAgency/flightplan

Claude Code skills authored by or curated for [Valesco Agency](https://valescoagency.com)
to develop software via **harness engineering and agent orchestration**.

Primary consumer: the AFK (autonomous) coding governance pipeline at
[`ValescoAgency/valesco-platform`](https://github.com/ValescoAgency/valesco-platform).

## Contents

- [`CONTEXT.md`](CONTEXT.md) — ubiquitous-language glossary for
  flightplan + AFK pipeline. Read on session start.
- [`docs/workflow.md`](docs/workflow.md) — end-to-end harness +
  orchestration map, repo conventions (`CONTEXT.md`, `docs/adr/`,
  `.afk/config.yml`), HITL fork, skills-vs-pipeline boundary.
- [`docs/adr/`](docs/adr/) — architectural decision records.
- [`docs/refactor-plan.md`](docs/refactor-plan.md) — phased PR roadmap
  for the tracker adapter rollout.
- [`docs/starter-set.md`](docs/starter-set.md) — adopted skills (Valesco
  + Matt Pocock + Addy Osmani), with rationale.
- [`docs/gaps.md`](docs/gaps.md) — open gaps, pipeline cross-references,
  closed gaps with ship dates.
- `<skill-name>/SKILL.md` — Valesco-authored skills, one directory per
  skill (Claude Code plugin convention).

## Consumer skills

User-invoked skills that drive issues through the AFK chain. Vendor-agnostic
— they read the active tracker via the adapter system below.

| Skill | Purpose |
|---|---|
| [`/triage`](triage/SKILL.md) | Funnel issues toward `ready-for-agent` with an Agent Brief comment. AFK-eligibility-aware. *(Renamed from `/linear-triage` in 0.3.0.)* |
| [`/diagnose`](diagnose/SKILL.md) | Six-phase debugging discipline; Phase 1 builds the verifier the goal-contract will use. |
| [`/feedback-loop`](feedback-loop/SKILL.md) | The 10-pattern catalog for constructing deterministic agent-runnable signals. |
| [`/draft-contract`](draft-contract/SKILL.md) | Lift a tracker issue into `.goal-contract.draft.yml` with `<PLANNER_SUGGESTED:>` tokens (§G8 gate). |
| [`/attest`](attest/SKILL.md) | Tier-scaled attestation checklist; writes `.afk/attestations/<id>.json`. |
| [`/brief-to-contract`](brief-to-contract/SKILL.md) | Orchestration spine — drives an issue from triage through to attested contract with resume detection + HITL exits. |

## Tracker adapters

Modular per-vendor adapters that satisfy the
[tracker contract](docs/adr/0001-tracker-adapter-contract.md). The
active adapter is selected via `tracker:` in `.afk/config.yml` (default
`linear`).

| Adapter | Status | Capabilities |
|---|---|---|
| [`tracker-linear`](tracker-linear/SKILL.md) | Shipped (default) | Full — customer field, project/cycle membership, team namespace, reliable active-work detection |
| [`tracker-github`](tracker-github/SKILL.md) | Shipped (Phase A2) | Reduced — no customer field, best-effort active-work detection. Triage works end-to-end; full chain through `/draft-contract` waits on Phase B schema migration in `valesco-platform`. |
| `tracker-jira`, `tracker-local-md` | Deferred | — |

This repo is its own dogfood for the GitHub adapter — see
[`.afk/config.yml`](.afk/config.yml). `afkEligible: false` (skill-layer
control plane); `tracker: github`. Walking flightplan issues through
`/triage` against the `tracker-github` adapter is the validation
milestone for Phase A2.

These compose with Matt Pocock's
[engineering skills](https://github.com/mattpocock/skills/tree/main/skills/engineering)
(`/grill-with-docs`, `/to-prd`, `/to-issues`,
`/improve-codebase-architecture`, `/zoom-out`, `/tdd`) per the workflow
in [`docs/workflow.md`](docs/workflow.md). Matt's `/triage` is **not**
adopted — flightplan's `/triage` is a strict superset (same canonical
state machine, plus AFK eligibility, tier logic, and §14.3 refusal).

## Skills-vs-pipeline rule

Load-bearing constraint on what belongs here:

- **Pipeline code** (lives in `valesco-platform/afk/`): capabilities
  touching hash-bound authority, audit records, tier gates, or requiring
  deterministic + replayable behavior. Validator runs, pre-flight checks,
  authority binding, label handler.
- **Skills** (live here): capabilities that are advisory, exploratory,
  or user-invoked. PRD drafting, domain modeling, triage, diagnosis,
  attestation walkthroughs, contract-drafting, orchestration spine.

If a proposed skill would violate the boundary, it becomes a pipeline
ticket, not a skill. See [`docs/gaps.md`](docs/gaps.md) for the
cross-reference list of pipeline items registered there only so skill
work doesn't accidentally pick them up.

## Related

- [`valesco-platform`](https://github.com/ValescoAgency/valesco-platform)
  — AFK governance + platform code
- [`docs/sdlc/workflow.md`](https://github.com/ValescoAgency/valesco-platform/blob/main/docs/sdlc/workflow.md)
  — Valesco SDLC including §8 AFK governance
- [`docs/afk/governance-plan.md`](https://github.com/ValescoAgency/valesco-platform/blob/main/docs/afk/governance-plan.md)
  — boundary constraints any adopted skill must respect
- [Matt Pocock's skills](https://github.com/mattpocock/skills) —
  upstream for `/grill-with-docs`, `/to-prd`, `/to-issues`,
  `/improve-codebase-architecture`, `/zoom-out`, `/tdd`
