# ValescoAgency/flightplan

Claude Code skills authored by or curated for [Valesco Agency](https://valescoagency.com)
to develop software via **harness engineering and agent orchestration**.

Primary consumer: the AFK (autonomous) coding governance pipeline at
[`ValescoAgency/valesco-platform`](https://github.com/ValescoAgency/valesco-platform).

## Contents

- [`docs/workflow.md`](docs/workflow.md) — end-to-end harness +
  orchestration map, repo conventions (`CONTEXT.md`, `docs/adr/`,
  `.afk/config.yml`), HITL fork, skills-vs-pipeline boundary.
- [`docs/starter-set.md`](docs/starter-set.md) — adopted skills (Valesco
  + Matt Pocock + Addy Osmani), with rationale.
- [`docs/gaps.md`](docs/gaps.md) — open gaps, pipeline cross-references,
  closed gaps with ship dates.
- `<skill-name>/SKILL.md` — Valesco-authored skills, one directory per
  skill (Claude Code plugin convention).

## Skills shipped in this plugin

| Skill | Purpose |
|---|---|
| [`/linear-triage`](linear-triage/SKILL.md) | Funnel Linear issues toward `ready-for-agent` with an Agent Brief comment. AFK-eligibility-aware. |
| [`/diagnose`](diagnose/SKILL.md) | Six-phase debugging discipline; Phase 1 builds the verifier the goal-contract will use. |
| [`/feedback-loop`](feedback-loop/SKILL.md) | The 10-pattern catalog for constructing deterministic agent-runnable signals. |
| [`/draft-contract`](draft-contract/SKILL.md) | Lift a Linear issue into `.goal-contract.draft.yml` with `<PLANNER_SUGGESTED:>` tokens (§G8 gate). |
| [`/attest`](attest/SKILL.md) | Tier-scaled attestation checklist; writes `.afk/attestations/<id>.json`. |
| [`/brief-to-contract`](brief-to-contract/SKILL.md) | Orchestration spine — drives a Linear issue from triage through to attested contract with resume detection + HITL exits. |

These compose with Matt Pocock's
[engineering skills](https://github.com/mattpocock/skills/tree/main/skills/engineering)
(`/grill-with-docs`, `/to-prd`, `/to-issues`,
`/improve-codebase-architecture`, `/zoom-out`, `/tdd`) per the workflow
in [`docs/workflow.md`](docs/workflow.md).

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
