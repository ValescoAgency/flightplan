# Gap register

Skills Valesco knows it will need but has not authored yet. Entries are
registered when the gap first blocks or slows a real run; speculative
entries are avoided — if it hasn't bitten, it's not here.

Each entry:

- **Name** — proposed skill name.
- **Purpose** — one line on what it does.
- **Trigger-to-author** — condition under which we stop registering and
  start authoring.
- **Classification** — `skill` (advisory, user-invoked) or `pipeline`
  (belongs in `valesco-platform/afk/` instead, registered here only for
  cross-reference).
- **Tracking** — Linear issue if one exists.

---

## Open skill gaps

### `/preflight-report`

- **Purpose**: Render a human-readable summary of a pre-flight run's
  output (structural checks, churn, Supabase advisors, cost estimate)
  for quick review before approval. Pipeline already emits structured
  output; this skill wraps it for chat.
- **Trigger-to-author**: When raw pre-flight output becomes noisy enough
  to slow down approvals. Defer until proven.
- **Classification**: skill.
- **Tracking**: none yet.

### Linear-native variants of `/to-prd` and `/to-issues`

- **Purpose**: Matt's `/to-prd` and `/to-issues` use GitHub by default
  and route Linear through the "Other" issue-tracker fallback. That
  works but requires per-invocation freeform-prose configuration. A
  Valesco-flavored variant would lock in Linear MCP, the VA/MREG/FMF
  team mapping, and the AFK-eligibility check.
- **Trigger-to-author**: When the freeform-prose fallback produces drift
  twice in a row, or when Matt adds first-class Linear support and we
  want to compose with that instead.
- **Classification**: skill.
- **Tracking**: none yet.

### `tracker-github` adapter (Phase A2)

- **Purpose**: GitHub Issues adapter implementing the
  [tracker contract](./adr/0001-tracker-adapter-contract.md). Free
  alternative for low-priority projects. Reduced capabilities — no
  `customer_field`, `team_namespace: false`,
  `active_work_detection: best-effort`.
- **Trigger-to-author**: When a real low-priority project needs
  `/triage` against GitHub Issues. Don't ship preemptively.
- **Classification**: skill.
- **Tracking**: none yet. See
  [`refactor-plan.md`](./refactor-plan.md#phase-a2--tracker-github-proof-of-concept).
- **Constraint**: full chain (`/draft-contract` and downstream) blocks
  on Phase B schema migration in `valesco-platform`. Triage works
  end-to-end independently.

### `tracker-jira` and `tracker-local-md` adapters

- **Purpose**: Same contract; cover Jira workflows and local-markdown
  issue tracking respectively.
- **Trigger-to-author**: Real demand. Speculative today.
- **Classification**: skill.
- **Tracking**: none.

---

## Cross-reference — pipeline items (not skills)

Registered here so skill work doesn't accidentally take them on. These
belong in `valesco-platform/afk/`.

### Adversarial pairing runner

- **Purpose**: Runs two agents on the same contract with different
  prompts / seeds, diffs outputs, flags divergence. Per G1 of the
  governance plan, runs on every contract.
- **Why pipeline**: Produces audit records; output is authority-bearing
  (gates `afk-ready` readiness signals).
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157)
  (research, someday backlog); implementation ticket TBD.

### Stage-gate enforcer

- **Purpose**: Enforces "cannot apply `afk-ready` label until delay
  elapsed AND attestation green AND adversarial review green." Per G1 +
  G8.
- **Why pipeline**: Hash-bound; gates authority transition.
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157)
  (research); implementation ticket TBD.

### Sequential chain runner

- **Purpose**: Plan → implement → test → review with state handoff
  between stages. Distinct from Ralph's stateless loop.
- **Why pipeline**: Consumes + produces `.goal-contract.yml` authority
  artefacts.
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157).

### Parallel fan-out + merge

- **Purpose**: Split `write_paths` by concern (API / DB / UI / tests),
  run specialist per lane, merge, re-validate.
- **Why pipeline**: Merge step is authority-bearing — determines final
  diff submitted to validator.
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157).

### Containerized AFK runner (Sandcastle-shaped)

- **Purpose**: Long-running AFK runs in an ephemeral container per Matt
  Pocock's [sandcastle](https://github.com/mattpocock/sandcastle) shape.
  Driven from a `ready-for-agent`-tagged tracker issue once attestation
  is green.
- **Why pipeline**: Executes the contract's `verification.commands` and
  produces audit records that flow into the label handler. Hash-bound.
- **Tracking**: none yet — research item.

### Schema v2: `linearIssueId` → `trackerIssueId` (Phase B)

- **Purpose**: Rename `metadata.linearIssueId` → `metadata.trackerIssueId`
  in `goal-contract.v1.json` and `attestation-record.v1.json`; broaden
  the ID regex from `^[A-Z]{2,6}-\d+$` to also accept GitHub-style
  `owner/repo#NNN` and arbitrary string IDs that satisfy a length floor.
  Update label handler to read v2. Migrate any in-flight records.
- **Why pipeline**: Schema authority + label handler logic.
- **Trigger**: Real demand for AFK chains on non-Linear repos. Don't
  ship preemptively — the migration cost is real, and it's
  governance-bound. See
  [`refactor-plan.md`](./refactor-plan.md#phase-b--schema-v2-in-valesco-platform).
- **Tracking**: TBD — open in `valesco-platform` when needed.
- **Phase A3 cleanup**: once Phase B lands, sweep skills to use the new
  field name (`attest`'s filename pattern, `state-machine.md` rules,
  prose).

---

## Closed gaps

### Tracker adapter contract — shipped 2026-05-01

- **Ships**: `tracker-linear/SKILL.md`, `tracker-linear/labels.yml`;
  rename `linear-triage/` → `triage/` with vendor-agnostic refactor;
  consumer skills (`draft-contract`, `diagnose`, `brief-to-contract`)
  refactored to speak the adapter contract.
- **Tracking**: PR #6 (docs: ADR-0001 + CONTEXT.md + refactor plan),
  PR A1 (this PR — implementation).
- **Notes**: Phase A1 of the rollout in
  [`refactor-plan.md`](./refactor-plan.md). Phase A2 (`tracker-github`)
  registered above; Phase B (schema migration) registered above.
  Capabilities baseline: `customer_field`, `project_membership`,
  `cycle_membership`, `team_namespace`, `active_work_detection`.

### `/diagnose` — shipped 2026-05-01

- **Ships**: `diagnose/SKILL.md`.
- **Purpose**: Six-phase debugging discipline; Phase 1 is load-bearing
  (build a deterministic agent-runnable feedback loop). AFK-aware via
  `.afk/config.yml`; the loop becomes a candidate `verification.commands`
  entry; the regression test seeds `intent.successCriteria`.
- **Notes**: Adapts Matt Pocock's
  [`/diagnose`](https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnose/SKILL.md)
  with AFK / Linear / contract integration layered on. Defers
  feedback-loop pattern detail to the sibling `/feedback-loop` skill.

### `/feedback-loop` — shipped 2026-05-01

- **Ships**: `feedback-loop/SKILL.md`.
- **Purpose**: 10-pattern catalog for constructing deterministic
  agent-runnable signals (failing test, curl harness, CLI fixture diff,
  headless browser, replay trace, throwaway harness, property/fuzz,
  bisection, differential, HITL bash) plus the iteration ladder for
  hardening any pattern against flakes.
- **Notes**: Cited from `/diagnose` Phase 1, `/tdd` (Matt's), and
  `/draft-contract` when authoring `verification.commands`. Tier-1
  contracts require determinism-or-disqualified per §G10.

### `/brief-to-contract` — shipped 2026-05-01

- **Ships**: `brief-to-contract/SKILL.md`,
  `brief-to-contract/state-machine.md`.
- **Purpose**: Orchestration spine — drives a Linear issue from triage
  through to attested contract by sequentially invoking the right
  per-stage skills with resume detection, HITL exits, and tier
  escalation.
- **Notes**: Writes no authority records itself; never applies
  `afk-ready` (§G1); never auto-fills tokens (§G8); never renames the
  draft (§G8). The state machine has 15 detection rules evaluated
  top-to-bottom; later-stage overrides are refused, earlier-stage
  overrides require confirmation.

### Anthropic `write-a-skill` variant — closed 2026-05-01

- **Decision**: Use `anthropic-skills:skill-creator`. It's connected,
  richer (eval loop, description optimization, packaging), and matches
  the Valesco authoring ergonomics for these orchestration-heavy skills.
- **Status**: Used to author `/diagnose`, `/feedback-loop`, and
  `/brief-to-contract` on 2026-05-01.
- **Notes**: Matt Pocock's `write-a-skill` remains in his productivity
  bucket; we don't run both in parallel. Revisit if `skill-creator` ever
  becomes unavailable or if Matt's variant gains specifically-better
  ergonomics for one-off small skills.

### `/attest` — shipped 2026-04-22

- **Ships**: `attest/SKILL.md`, `attest/checklist.md`,
  `attest/record-reference.md`.
- **Tracking**: [VA-160](https://linear.app/valescoagency/issue/VA-160).
- **Notes**: Schema lives in `valesco-platform`
  ([VA-160](https://github.com/ValescoAgency/valesco-platform/pull/31)).
  Records keyed by `linearIssueId`; `attestedContentSha` is raw-bytes
  sha. The label handler re-computes and rejects on drift.

### `/draft-contract` — shipped 2026-04-22

- **Ships**: `draft-contract/SKILL.md`,
  `draft-contract/template.yml`,
  `draft-contract/authority-fields.md`.
- **Tracking**: [VA-154](https://linear.app/valescoagency/issue/VA-154).
- **Notes**: Drafts validate cleanly against
  `afk/schemas/goal-contract.v1.json` post
  [VA-158](https://linear.app/valescoagency/issue/VA-158).
  `<PLANNER_SUGGESTED:>` tokens hold the §G8 gate; pre-flight rejects
  any contract that still contains them.
