# Workflow — harness engineering + agent orchestration

Reference for how Valesco-authored skills compose with Matt Pocock's
engineering skills to drive a tracker issue end-to-end through the AFK
pipeline. This is the doctrine the new flightplan skills assume; the
[starter-set](./starter-set.md) tracks which skills are adopted and the
[gaps](./gaps.md) doc tracks what's missing.

## End-to-end map

```
idea / conversation / paste
        │
        ▼
   /grill-with-docs        (Matt — alignment + glossary + ADR)
        │
        ▼
        /to-prd            (Matt — synthesizes PRD from context)
        │
        ▼
        /to-issues         (Matt — vertical-slice tracer-bullet issues)
        │
        ▼
   ─── Tracker issue exists ───────────────────────────────────────
        │
        ▼
   /triage                  (Valesco — funnel toward ready-for-agent)
        │
        ├─→ ready-for-human  → HITL exit
        ├─→ needs-info       → wait for reporter
        └─→ ready-for-agent (Agent Brief comment posted)
                │
                ▼
        /diagnose           (Valesco — Bugs only; build the Phase-1 loop)
                │           │
                │           └─ uses /feedback-loop for the 10 patterns
                │
                ▼
        /grill-with-docs    (optional, when domain alignment looks suspect)
                │
                ▼
        /draft-contract     (Valesco — lift issue → .goal-contract.draft.yml)
                │
                ▼
   ─── HUMAN: replace <PLANNER_SUGGESTED:> tokens, rename to .goal-contract.yml
                │
                ▼
        /attest             (Valesco — tier-scaled checklist + record)
                │
                ▼
   ─── HUMAN: open scope PR, wait delay window, apply afk-ready
                │
                ▼
   AFK pipeline (valesco-platform)  — pre-flight, adversarial review, run, label handler
```

The orchestration spine, [`/brief-to-contract`](../brief-to-contract/SKILL.md),
walks an issue from the Tracker-issue line through to the attest step. It
detects which stage to enter based on existing artefacts and exits cleanly
on HITL forks.

## Stage ownership

| Stage | Skill | Source | Purpose |
|---|---|---|---|
| Idea → aligned plan | [`/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md) | Matt | Alignment + locks domain language in `CONTEXT.md` + records ADRs inline |
| Plan → PRD | [`/to-prd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-prd/SKILL.md) | Matt | Synthesizes a PRD from current context; posts to the tracker |
| PRD → issues | [`/to-issues`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-issues/SKILL.md) | Matt | Breaks the PRD into vertical-slice tracer-bullet issues; tags HITL vs AFK |
| Tracker issue → ready-for-agent | [`/triage`](../triage/SKILL.md) | Valesco | Funnel toward `ready-for-agent` with an Agent Brief comment; HITL-aware |
| Bug needs reproducer | [`/diagnose`](../diagnose/SKILL.md) | Valesco | Six-phase loop; Phase 1 builds the verifier the contract will use |
| Construct a feedback loop | [`/feedback-loop`](../feedback-loop/SKILL.md) | Valesco | The 10-pattern catalog for deterministic agent-runnable signals |
| Architecture review | [`/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md) | Matt | Find deepening opportunities; informed by `CONTEXT.md` + ADRs |
| Brief → draft contract | [`/draft-contract`](../draft-contract/SKILL.md) | Valesco | Lift tracker issue into `.goal-contract.draft.yml` with `<PLANNER_SUGGESTED:>` tokens |
| Draft → attested | [`/attest`](../attest/SKILL.md) | Valesco | Tier-scaled checklist; writes `.afk/attestations/<id>.json` |
| Whole chain | [`/brief-to-contract`](../brief-to-contract/SKILL.md) | Valesco | Orchestration spine; sequences the above with resume detection + HITL exits |
| Pre-flight, adversarial review, run, label handler | — | `valesco-platform/afk/` | **Pipeline, not skills.** Authority-bearing, hash-bound, replay-safe. |

The `/brief-to-contract` spine never crosses into pipeline territory.
That boundary is load-bearing — see [§ Skills vs pipeline](#skills-vs-pipeline)
below.

## Repo conventions this workflow assumes

For the workflow to compose cleanly, projects under
`github.com/ValescoAgency` adopt three conventions:

1. **`.afk/config.yml`** at the repo root. Declares `afkEligible`,
   `projectTier`, customer (Tier 1), tier expiry, **`tracker:`** (which
   adapter to use; default `linear`), and optional
   `trackerLabelsPath:` for per-repo label overrides. Pipeline reads it;
   skills read it for their own gating.
2. **`CONTEXT.md`** at the repo root (single-context) or
   **`CONTEXT-MAP.md`** + per-context `CONTEXT.md` (multi-context, e.g.
   monorepos). Holds the project's ubiquitous language. Maintained by
   `/grill-with-docs` and `/improve-codebase-architecture`.
3. **`docs/adr/`** at the repo root, or per-context. Records architectural
   decisions that meet the three-condition rule: hard to reverse,
   surprising without context, result of a real trade-off.

These conventions are new as of 2026-05-01. Existing repos backfill on
first use — `/grill-with-docs` creates `CONTEXT.md` lazily when the first
term is resolved, and creates `docs/adr/` lazily when the first ADR is
needed.

## Tracker adapters

The "context layer" — issue body, comments, labels, status — is a
**modular component**. The active adapter is loaded at session start
based on `.afk/config.yml`'s `tracker:` field. Consumer skills speak
only canonical names; the adapter translates to vendor-native form.

| Adapter | Status | Notes |
|---|---|---|
| [`tracker-linear`](../tracker-linear/SKILL.md) | Default, shipped | Full capability set — `customer_field`, `team_namespace`, reliable active-work detection. |
| `tracker-github` | Planned (Phase A2) | Triage-end-to-end works; full chain through `/draft-contract` blocked on Phase B schema migration in `valesco-platform`. |
| `tracker-jira`, `tracker-local-md` | Deferred | — |

The contract that defines the adapter API is
[ADR-0001](./adr/0001-tracker-adapter-contract.md). The phased rollout
is in [refactor-plan.md](./refactor-plan.md).

## CONTEXT.md — Ubiquitous Language

The glossary file. Every term agents and humans use to describe the
project's domain — the Eric Evans "ubiquitous language" idea, made
concrete as a markdown file the agent can read on session start.

### What goes in

- Domain nouns the project distinguishes (`Customer` vs `User`,
  `Order` vs `Cart`, `Subscription` vs `Plan`).
- Domain verbs that mean something specific (`materialize`, `cancel`,
  `enroll`).
- Concepts that have a precise project-specific meaning beyond their
  common-English reading.

### What stays out

- Implementation details — class names, file paths, framework choices.
  The glossary is what domain experts would say, not what the codebase
  happens to be named today.
- Things any reader of the codebase would understand without the file
  (`User has email and password`).
- Refactor candidates / code-review observations — those go in
  `docs/adr/` or are addressed in the code itself.

### When to update

Inline, as terms are resolved during a `/grill-with-docs` or
`/improve-codebase-architecture` run. Don't batch — capture each term
when it first becomes contested or sharpened. Format per Matt's
[CONTEXT-FORMAT.md](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/CONTEXT-FORMAT.md).

### Why agents need this

Cold-start agents (the AFK runner, sub-agents spawned by the Explore
tool, fresh Claude Code sessions) start with no project vocabulary. They
guess at "user" vs "customer," reinvent verbs the team has already
named, and produce verbose code that uses 20 words where 1 will do. A
read-on-start glossary collapses that to a paragraph.

The Valesco engineering skills (`/diagnose`, `/draft-contract`,
`/linear-triage`) reference `CONTEXT.md` so the test names, contract
fields, and triage notes round-trip in the project's language.

## ADRs

Architectural Decision Records under `docs/adr/`. One file per decision,
numbered (`0001-event-sourced-orders.md`, `0002-postgres-write-model.md`).

### When an ADR is warranted

All three must hold (Matt's rule, adopted as Valesco doctrine):

1. **Hard to reverse** — changing your mind later costs real engineering.
2. **Surprising without context** — a future reader will wonder "why?"
3. **Result of a real trade-off** — there were genuine alternatives.

If any of the three is missing, skip the ADR. Most decisions don't merit
one.

### What's in the file

Format per Matt's
[ADR-FORMAT.md](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/ADR-FORMAT.md).
Short version:

- Context (the trade-off as it was at decision time)
- Decision (what was chosen)
- Consequences (what becomes easier and harder)
- Status (proposed / accepted / superseded by NNNN)

### How AFK skills use ADRs

- [`/draft-contract`](../draft-contract/SKILL.md) reads the ADR area
  relevant to the issue's `writePaths` so the contract doesn't propose
  changes that contradict locked-in decisions.
- [`/diagnose`](../diagnose/SKILL.md) reads ADRs in the bug's area before
  hypothesising — sometimes a "bug" is the documented behavior of an
  ADR'd decision.
- [`/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md)
  surfaces ADR conflicts as part of its candidate-deepening list, but
  marks them clearly so the human can decide whether to revisit the ADR.
- The AFK runner inherits the same posture by reading the same files.

ADRs are read more often than they're written. That's the ratio you
want — six months later they're a navigation aid, not a notebook.

## HITL fork

Not every issue is AFK-eligible. The pipeline is built around accepting
that gracefully and routing to a human without losing work.

| Trigger | Where it fires | Skill response |
|---|---|---|
| Repo is `afkEligible: false` (e.g. `valesco-platform`) | `/brief-to-contract` Stage 0 | Refuse; recommend `/linear-triage` for `ready-for-human`. |
| Triage decides `ready-for-human` | `/linear-triage` Step 5 | Post a Human Brief (same shape as Agent Brief + a "why human, not agent" paragraph). |
| `/diagnose` cannot build a feedback loop | Phase 1 fallback | Drop back to `/linear-triage` with `needs-info` listing the specific blockers. |
| `<PLANNER_SUGGESTED:>` tokens reveal genuine unknowns | `/brief-to-contract` Stage 5 | Surface the unknowns; drop back to `/grill-with-docs` if they're domain questions. |
| Tier 1 escalation declined | `/brief-to-contract` Stage 4 | Pause and discuss — the issue may need to be retagged or accepted at Tier 1 anyway. |
| Adversarial review surfaces a real concern | Pipeline (not a skill) | Pipeline halts the run; ticket goes back to a human. |

The HITL fork is a feature, not a failure. An issue routed to
`ready-for-human` has been triaged, briefed, and (if a bug) often
diagnosed — the human picking it up has the same context the AFK runner
would have had.

## Skills vs pipeline

The boundary that gives this workflow its safety properties.

**Skills** (live in this repo, advisory, user-invoked):

- Can read any file.
- Can call other skills.
- Can post tracker comments via the active adapter (with the AI disclaimer).
- Can write *user-territory* files: tests, scripts in `scripts/debug/`,
  `CONTEXT.md`, `docs/adr/`, the goal-contract draft, the attestation
  record.
- Cannot mutate AFK authority records (audit store, label handler state,
  pipeline's own data).
- Cannot apply `afk-ready` (§G1).
- Cannot replace `<PLANNER_SUGGESTED:>` tokens (§G8).

**Pipeline** (lives in `valesco-platform/afk/`, authority-bearing):

- Validators (structural, churn, advisor, cost).
- Pre-flight orchestration.
- Adversarial pairing runner (when implemented per §G1).
- Label handler (re-verifies `attestedContentSha`, gates promotion).
- Stage-gate enforcer (delay window, attestation green, adversarial
  green).
- Audit log writers.

If a proposed capability would touch authority, audit, or hash-bound
state, it becomes a pipeline ticket — not a skill. See
[`docs/gaps.md`](./gaps.md) for the cross-reference list of pipeline
items registered there only so skill work doesn't accidentally pick them
up.

## Conflict rule

When skill output (Matt's or Valesco's) contradicts:

- The house rules in `~/.claude/rules/*.md`,
- The governance plan in `valesco-platform/docs/afk/governance-plan.md`,
- An ADR in `docs/adr/`,

**the rules / governance / ADR win.** Skill output is advisory; those
three are authority. If a skill insists on a structure that violates
them, log it as a starter-set revisit trigger in
[`docs/starter-set.md`](./starter-set.md).

## References

- [`./starter-set.md`](./starter-set.md) — adopted skills, with rationale.
- [`./gaps.md`](./gaps.md) — known-missing skills + pipeline cross-refs.
- `valesco-platform/docs/afk/governance-plan.md` — full governance.
- `valesco-platform/docs/sdlc/workflow.md` §8 — AFK governance section
  of the broader SDLC.
- [Matt Pocock's skills](https://github.com/mattpocock/skills) — upstream
  for `/grill-with-docs`, `/to-prd`, `/to-issues`,
  `/improve-codebase-architecture`, `/zoom-out`, `/tdd`.
