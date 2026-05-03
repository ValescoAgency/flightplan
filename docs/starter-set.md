# Starter skill set

The defended set of Claude Code skills Valesco adopts for day-to-day work
around the AFK pipeline. Tuned 2026-04-21; revised 2026-05-01 to align
with Matt Pocock's reorganized [`engineering/`](https://github.com/mattpocock/skills/tree/main/skills/engineering)
bucket and the new flightplan-owned harness/orchestration skills.

The skills-vs-pipeline rule in [README](../README.md) and the workflow
doctrine in [workflow.md](./workflow.md) govern every entry. If a skill
starts creeping into authority, audit, or tier-gate territory, it moves
to pipeline code at `valesco-platform/afk/` and drops off this list.

---

## Adopted — flightplan-owned (Valesco)

These ship in this plugin. AFK-aware; vendor-agnostic via the tracker
adapter contract ([ADR-0001](./adr/0001-tracker-adapter-contract.md)).

### Consumer skills

| Skill | Use case |
|---|---|
| [`/triage`](../triage/SKILL.md) | Funnel issues toward `ready-for-agent` with an Agent Brief comment. **Vendor-agnostic** — uses the active tracker adapter. AFK-eligibility-aware via `.afk/config.yml`. *(Renamed from `/linear-triage` in 0.3.0.)* |
| [`/diagnose`](../diagnose/SKILL.md) | Six-phase debugging discipline; Phase 1 builds the verifier the contract will use. AFK-aware tier handling. |
| [`/feedback-loop`](../feedback-loop/SKILL.md) | The 10-pattern catalog for constructing deterministic agent-runnable signals. Cited by `/diagnose`, `/draft-contract`, and Matt's `/tdd`. |
| [`/draft-contract`](../draft-contract/SKILL.md) | Lift a tracker issue into `.goal-contract.draft.yml` with `<PLANNER_SUGGESTED:>` tokens (G8 gate). |
| [`/attest`](../attest/SKILL.md) | Tier-scaled attestation checklist; writes `.afk/attestations/<id>.json` (the label handler reads it). |
| [`/brief-to-contract`](../brief-to-contract/SKILL.md) | Orchestration spine — drives an issue through the chain to attested contract with resume detection + HITL exits. |

### Tracker adapters

Loaded automatically by consumer skills based on `.afk/config.yml`'s
`tracker:` field. Not directly user-invoked.

| Adapter | Status | Notes |
|---|---|---|
| [`tracker-linear`](../tracker-linear/SKILL.md) | Shipped (default) | Full capability set. |
| [`tracker-github`](../tracker-github/SKILL.md) | Shipped (Phase A2) | Triage end-to-end works; full chain blocks on Phase B schema migration. |
| `tracker-jira`, `tracker-local-md` | Deferred | — |

---

## Adopted — upstream (Matt Pocock)

Adopted from [`mattpocock/skills`](https://github.com/mattpocock/skills).
Used as-is; configure for Valesco via `/setup-matt-pocock-skills` with
Linear as the issue tracker (the "Other" path until/unless he adds a
first-class Linear adapter).

### Always-on alignment + planning posture

| Skill | Source | Use case |
|---|---|---|
| [`/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md) | Matt | Adversarial pass on a plan, with inline updates to `CONTEXT.md` and `docs/adr/`. **Replaces** `grill-me` + `domain-model` + `ubiquitous-language` from the previous starter-set — those three are now folded into one. |
| [`/to-prd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-prd/SKILL.md) | Matt | Synthesize a PRD from the current conversation, post to Linear. No interview — the grill happens upstream. |
| [`/to-issues`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-issues/SKILL.md) | Matt | Break a PRD into vertical-slice tracer-bullet issues with HITL/AFK tags. **New since the previous starter-set** — split out from `/to-prd`. |

### User-invoked review passes

These do not auto-run. Invoke deliberately.

| Skill | Source | When to invoke |
|---|---|---|
| [`/tdd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md) | Matt | Feature work where TDD is the explicit posture. Vertical-slice red-green-refactor; explicit anti-pattern: no horizontal slicing. |
| [`/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md) | Matt | **Newly adopted (2026-05-01).** Surface deepening opportunities (Module/Interface/Depth/Seam/Adapter glossary). Run every few days, or after a `/diagnose` that surfaced an architectural blocker. The previous rejection rationale ("overlaps grill-me + domain-model") no longer holds — Matt's new version has its own architectural glossary distinct from grilling. |
| [`/zoom-out`](https://github.com/mattpocock/skills/blob/main/skills/engineering/zoom-out/SKILL.md) | Matt | Newly adopted. One-paragraph navigation aid when entering an unfamiliar area of the codebase. |
| [`security-and-hardening`](https://github.com/addyosmani/agent-skills) | Addy Osmani | Review pass on auth paths, RLS policies, payment flows, any net-new surface that takes untrusted input. |
| [`performance-optimization`](https://github.com/addyosmani/agent-skills) | Addy Osmani | Review pass when a page or action measurably regresses. Reactive to signal, not preventive. |
| [`frontend-ui-engineering`](https://github.com/addyosmani/agent-skills) | Addy Osmani | UI-heavy feature work. House style (Tailwind + shadcn + `react-components.md` rules) wins any conflict per the conflict rule. |

**shadcn/ui skill**: adopted per-project, not globally. Added when a
project's frontend surface justifies it.

---

## Newly added Valesco repo conventions (2026-05-01)

The above skills assume three repo-level conventions, established with
this revision and described in detail in [workflow.md](./workflow.md):

1. **`.afk/config.yml`** — already established for the AFK pipeline.
2. **`CONTEXT.md`** — the project's ubiquitous language. Lazily created
   by `/grill-with-docs` on first term resolution.
3. **`docs/adr/`** — architectural decision records. Lazily created by
   `/grill-with-docs` or `/improve-codebase-architecture` on first ADR.

`/diagnose`, `/feedback-loop`, and `/brief-to-contract` reference these
files directly. Existing repos backfill on first need.

---

## Rejected / deferred

| Skill | Decision | Rationale |
|---|---|---|
| `domain-model` | Removed (deprecated upstream) | Matt folded it into `/grill-with-docs`. Use that. |
| `ubiquitous-language` | Removed (deprecated upstream) | Same — folded into `/grill-with-docs`. |
| `design-an-interface` | Removed (deprecated upstream) | Matt deprecated this; the deepening work happens in `/improve-codebase-architecture` now. |
| `request-refactor-plan` | Rejected | Overlaps `/improve-codebase-architecture` and the Plan agent / planning phase of AFK contracts. |
| `git-guardrails-claude-code` | Rejected | Lefthook + branch protection cover this mechanically per `workflow.md` §7. Skill would duplicate without adding authority. |
| Matt's `/triage` | Rejected | Valesco's `/triage` is a strict superset — same canonical state machine, OOS pattern, and brief structure, plus AFK eligibility, tier logic, and §14.3 refusal. Adopting both creates namespace ambiguity for zero capability gain. Re-evaluate if Matt diverges meaningfully (e.g., adds typed adapter contracts). |
| `obsidian`, `obsidian-vault` | Out of scope | Personal knowledge workflow, orthogonal to AFK. |
| `caveman` | N/A | Response style, not a workflow skill. Loaded per session. |
| `/setup-matt-pocock-skills` | Skip | Valesco repos already follow the conventions this skill bootstraps. Run it only on a brand-new project that isn't using the Valesco template. |

---

## Conflict rule

If a skill's output contradicts the house rules in
`~/.claude/rules/*.md`, the governance plan in
`valesco-platform/docs/afk/governance-plan.md`, or an ADR in `docs/adr/`,
**the rules / governance / ADR win.** Skill output is advisory; those
three are authority. Log persistent conflicts as a revisit trigger here.

---

## Revisit triggers

Revise this list when:

- An adopted skill gets invoked fewer than 1×/month over two months → demote to rejected.
- A rejected skill gets wanted three times → promote.
- A gap in [gaps.md](./gaps.md) gets authored and lands → move to adopted.
- Matt or Addy ship a substantively new skill in their engineering bucket → evaluate within a week.
- An adopted upstream skill conflicts with house rules / governance / an ADR repeatedly → consider replacing with a Valesco-flavored variant.
