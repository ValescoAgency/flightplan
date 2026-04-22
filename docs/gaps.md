# Gap register

Skills Valesco knows it will need but has not authored yet. Entries are
registered when the gap first blocks or slows a real run; speculative entries
are avoided — if it hasn't bitten, it's not here.

Each entry:
- **Name** — proposed skill name.
- **Purpose** — one line on what it does.
- **Trigger-to-author** — condition under which we stop registering and start
  authoring.
- **Classification** — `skill` (advisory, user-invoked) or `pipeline` (belongs
  in `valesco-platform/afk/` instead, registered here only for cross-reference).
- **Tracking** — Linear issue if one exists.

---

## Open skill gaps

### `/attest` — **in progress**

- **Purpose**: Render the attestation checklist from a `.goal-contract.yml`
  and walk the user through tick-through (time-delay acknowledgement,
  protected-path confirmation, cost-estimate acknowledgement, tier-specific
  extras like canary plan on Tier 1). Emits an attestation record that the
  afk-ready label handler reads to decide whether to promote the contract.
- **Status**: Skill + schema authored 2026-04-22. Schema ships via
  valesco-platform PR [#31](https://github.com/ValescoAgency/valesco-platform/pull/31)
  (`afk/schemas/attestation-record.v1.json` + 26 AJV tests). Skill files
  (`attest/SKILL.md`, `checklist.md`, `record-reference.md`) on this PR.
- **Keying decision**: records keyed by `linearIssueId`, not by canonical
  `contractHash`. `attestedContentSha` (raw SHA-256 of
  `.goal-contract.yml` bytes) carries integrity; the label handler
  re-computes and rejects on drift. Canonical normalization is a
  separate future concern.
- **Classification**: skill (the checklist is advisory; the _record_ it
  produces is consumed by pipeline, which is authority).
- **Tracking**: [VA-160](https://linear.app/valescoagency/issue/VA-160).

### `/preflight-report`

- **Purpose**: Render a human-readable summary of a pre-flight run's output
  (structural checks, churn, Supabase advisors, cost estimate) for quick
  review before approval. Pipeline already emits structured output; this
  skill wraps it for chat.
- **Trigger-to-author**: When raw pre-flight output becomes noisy enough to
  slow down approvals. Defer until proven.
- **Classification**: skill.
- **Tracking**: none yet.

### Anthropic `write-a-skill` variant

- **Purpose**: Anthropic publishes a skill authoring skill (likely
  `anthropic-skills:skill-creator` or the `skill-creator` namespace). Compare
  against Matt Pocock's `write-a-skill` and pick the better fit for Valesco
  authoring ergonomics.
- **Trigger-to-author**: When authoring the first Valesco skill (any of the
  above). Choose one; don't run both in parallel.
- **Classification**: decision, not new skill. Log the choice here when made.
- **Tracking**: none.

---

## Cross-reference — pipeline items (not skills)

Registered here so skill work doesn't accidentally take them on. These belong
in `valesco-platform/afk/`.

### Adversarial pairing runner

- **Purpose**: Runs two agents on the same contract with different prompts /
  seeds, diffs outputs, flags divergence. Per G1 of the governance plan,
  runs on every contract.
- **Why pipeline**: Produces audit records; output is authority-bearing
  (gates `afk-ready` readiness signals).
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157)
  (research, someday backlog); implementation ticket TBD.

### Stage-gate enforcer

- **Purpose**: Enforces "cannot apply `afk-ready` label until delay elapsed
  AND attestation green AND adversarial review green." Per G1 + G8.
- **Why pipeline**: Hash-bound; gates authority transition.
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157)
  (research); implementation ticket TBD.

### Sequential chain runner

- **Purpose**: Plan → implement → test → review with state handoff between
  stages. Distinct from Ralph's stateless loop.
- **Why pipeline**: Consumes + produces `.goal-contract.yml` authority
  artifacts.
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157).

### Parallel fan-out + merge

- **Purpose**: Split `write_paths` by concern (API / DB / UI / tests), run
  specialist per lane, merge, re-validate.
- **Why pipeline**: Merge step is authority-bearing — determines final diff
  submitted to validator.
- **Tracking**: [VA-157](https://linear.app/valescoagency/issue/VA-157).

---

## Closed gaps

### `/draft-contract` — shipped 2026-04-22

- **Ships**: `draft-contract/SKILL.md`, `template.yml`, `authority-fields.md`.
- **Tracking**: [VA-154](https://linear.app/valescoagency/issue/VA-154).
- **Landed via**: PR [#1](https://github.com/ValescoAgency/skills/pull/1)
  (initial) + follow-up to strict-validate drafts post-VA-158 merge.
- **Notes**: Drafts now validate cleanly against
  `afk/schemas/goal-contract.v1.json` thanks to
  [VA-158](https://linear.app/valescoagency/issue/VA-158) (approvedAt +
  contractHash optional at schema level; pre-flight's
  `structural.metadata-presence` stage enforces presence). Validator
  policyId / policyVersion emit as defaults with `# PLANNER_SUGGESTED`
  comments rather than tokens, since string patterns can't hold token
  strings — matches the tier/budget precedent.
