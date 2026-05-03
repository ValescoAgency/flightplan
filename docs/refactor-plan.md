# Refactor plan — tracker adapter rollout

Phased roadmap for landing [ADR-0001](./adr/0001-tracker-adapter-contract.md).
Goal: extract the issue-tracker context layer into a modular `tracker-<provider>/`
component so flightplan's core skills (triage, contract drafting,
diagnosis, orchestration) work unchanged across Linear, GitHub Issues,
and future vendors.

## Phases at a glance

| Phase | Repo | Scope | Depends on | Status |
|---|---|---|---|---|
| **A1** | flightplan | Rename + Linear adapter extraction + ADR + CONTEXT.md | nothing | next |
| **A2** | flightplan | `tracker-github` proof-of-concept (triage-only end-to-end) | A1 | follow-up |
| **B** | valesco-platform | Schema v2: `linearIssueId` → `trackerIssueId`, regex broadening, label-handler update | independent of A | when GitHub AFK chain is real demand |
| **A3** | flightplan | Skill sweep to use `trackerIssueId` (post-Phase B) | A1, B | post-B |

A1 and B can run in parallel. A2 depends on A1. A3 depends on both.

---

## Phase A1 — Rename + Linear adapter

**Branch**: `feature/tracker-adapter`

**Ships**:

- Rename `linear-triage/` → `triage/`. Refactor `triage/SKILL.md` to
  speak adapter-canonical names (no Linear MCP calls inline).
- `tracker-linear/SKILL.md` — operations table mapping each contract
  operation to the underlying Linear MCP call. Capability declaration
  block.
- `tracker-linear/labels.yml` — identity mapping (Valesco repos already
  use canonical names directly).
- Migrate Linear-specific knowledge from `triage` into `tracker-linear`:
  the VA / MREG / FMF team table, status-name translation, the
  Linear-MCP cheatsheet.
- Refactor consumer skills (`draft-contract`, `brief-to-contract`,
  `diagnose`) to call "the active tracker adapter" via the operations
  table rather than `mcp__plugin_productivity_linear__*` directly.
- New `.afk/config.yml` field documented: `tracker: linear` (default).
- Doc updates:
  - `docs/workflow.md` — new section on the adapter contract.
  - `docs/starter-set.md` — drop Matt's `/triage` from adopted with
    rationale (Valesco's is a strict superset).
  - `docs/gaps.md` — close `/triage` rename gap; register Phase B and
    Phase A2.
  - `README.md` — skills table updated.
  - `.claude-plugin/plugin.json` — bump to `0.3.0`; updated description
    + keywords.

**Backwards compatibility**:

- Existing `.afk/config.yml` files without `tracker:` continue to work
  (default `linear`).
- Existing consumer-skill behavior is unchanged for Linear-backed repos.
- The slash command rename (`/linear-triage` → `/triage`) is a breaking
  change. Plugin namespace prefix (`valesco:triage`) makes the canonical
  invocation unambiguous; bare `/triage` resolves to ours since Matt's
  is dropped from the adopted set.

**Out of scope for A1** (registered for follow-up):

- Authoring the GitHub adapter (Phase A2).
- Schema migration in valesco-platform (Phase B).
- Tooling to validate adapter conformance (future, only if needed).

---

## Phase A2 — `tracker-github` proof-of-concept

**Branch**: `feature/tracker-github`

**Ships**:

- `tracker-github/SKILL.md` — operations table mapping to `gh` CLI or
  the GitHub MCP (whichever is connected). Capability declaration with
  explicit `customer_field: false`, `team_namespace: false`,
  `active_work_detection: best-effort`.
- `tracker-github/labels.yml` — vendor default mapping
  (`bug`→`Bug`, `enhancement`→`Feature`, `documentation`→`Improvement`,
  etc.).
- Walk one real low-priority GitHub-Issues repo through `/triage`
  end-to-end as the validation milestone.
- Doc updates: starter-set, gaps register, workflow.md.

**Known constraint** (acknowledged, documented):

- The full chain `/triage` → `/draft-contract` → `/attest` will reject
  GitHub issue IDs at schema validation until Phase B lands. The
  `tracker-github/SKILL.md` calls this out explicitly so users don't
  hit the wall unprepared.

---

## Phase B — Schema v2 in `valesco-platform`

**Repo**: `valesco-platform`. **Branch**: TBD when the work starts.

**Ships**:

- `goal-contract.v2.json` — `metadata.linearIssueId` → `metadata.trackerIssueId`;
  regex broadened to accept GitHub-style `owner/repo#NNN`.
- `attestation-record.v2.json` — same field rename + regex.
- Label handler update — read v2 schema; key attestation lookup by
  `trackerIssueId`.
- Pre-flight update — read v2 schema; surface the field rename in error
  messages.
- Migration for in-flight records:
  - Existing `.goal-contract.yml` files: schema validators accept both
    v1 and v2 during a transition window; PR template prompts maintainers
    to bump.
  - Existing `.afk/attestations/*.json`: filename pattern is unchanged
    (still keyed by issue ID); contents get a one-line transform script.
- Own attestation walk — this is governance-grade; use `/attest` against
  a meta-contract authored for the migration itself per §G1.

**Triggering condition**: real demand for AFK chains on non-Linear
repos. Don't ship preemptively — the migration cost is real, and it's
governance-bound.

---

## Phase A3 — Skill sweep post-Phase B

**Branch**: `chore/trackerIssueId-sweep`

**Ships**:

- Search-and-replace across flightplan skills: `linearIssueId` →
  `trackerIssueId` in prose, examples, regex references, and the
  `attest` filename pattern.
- Ensure attestation records keyed by `trackerIssueId` are read/written
  correctly in `attest/SKILL.md`.
- Update `state-machine.md` rules in `brief-to-contract/` to reference
  the new field name in detection rules.
- Doc updates removing the Phase B blocker mentions.

**Out of scope**:

- Anything that wasn't already in scope for A1 or A2 — this is purely a
  field-rename sweep.

---

## Risk register

| Risk | Mitigation |
|---|---|
| Capability checks forgotten in consumer skills, leading to vendor-specific assumptions creeping back in | A1 includes an explicit capability-check pattern in each consumer skill; review checklist in PR description. |
| Adapter prose drifts from operations contract over time | ADR-0001 is canonical; adapters reference back to it. Schema-typed contract (Option 2 from grilling) remains a future option if drift becomes a problem. |
| Phase B never happens, A2 ships and confuses users at the `draft-contract` step | A2's `tracker-github/SKILL.md` documents the Phase B blocker explicitly; `/draft-contract` error message points at the gap. |
| Slash-command rename `/linear-triage` → `/triage` breaks user muscle memory | Plugin version bump (0.2.0 → 0.3.0) signals breaking change; README + starter-set call out the rename; `/linear-triage` removal is documented. |

## References

- [ADR-0001: Tracker adapter contract](./adr/0001-tracker-adapter-contract.md)
  — the design decision this plan implements.
- [`CONTEXT.md`](../CONTEXT.md) — ubiquitous language including all
  terms used in this plan.
- `valesco-platform/docs/afk/governance-plan.md` — pipeline-side
  governance that constrains Phase B.
