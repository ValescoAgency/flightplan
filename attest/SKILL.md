---
name: attest
description: Walk the human through the AFK attestation checklist for a `.goal-contract.yml` and write a tier-scaled attestation record. Use when the user says "attest this contract", "run attestation for VA-NNN", "I'm ready to apply afk-ready", or similar. The record gates the afk-ready label handler — no attestation, no pre-flight. Does NOT apply the label itself (deliberate, per G1).
---

# /attest

Render the tier-scaled attestation checklist for the current repo's
`.goal-contract.yml`, walk the user through it interactively, and write an
attestation record to `.afk/attestations/<linearIssueId>.json`.

The afk-ready label handler reads this record, re-computes
`attestedContentSha` against the current YAML, and refuses to promote the
contract (populate `metadata.approvedAt`, trigger pre-flight) if the sha
drifted. This catches post-attestation edits without requiring a canonical
normalization step.

## When to run

Immediately after:
1. `.goal-contract.yml` exists (authored from a `.goal-contract.draft.yml`
   produced by [`/draft-contract`](../draft-contract/SKILL.md)).
2. All `<PLANNER_SUGGESTED:>` tokens are replaced.
3. The scope PR is open (or about to be).
4. The required delay window has elapsed per tier (15/30/60 min).

**Before** applying the `afk-ready` label. That ordering is the whole point
of attestation — the label should be the last thing that happens, after
the human has consciously walked through every authority-bearing claim.

## Preconditions — check before rendering anything

1. **`.goal-contract.yml` exists** at repo root. If absent:

   > Refusing to run. `.goal-contract.yml` not found. If you have
   > `.goal-contract.draft.yml`, replace its `<PLANNER_SUGGESTED:>` tokens
   > and rename first (see /draft-contract next-steps).

2. **No `<PLANNER_SUGGESTED:>` tokens remain.** Grep the YAML bytes. If
   any token is present:

   > Refusing to run. `.goal-contract.yml` still contains
   > `<PLANNER_SUGGESTED:>` token(s) at: <lines>. Replace these with real
   > values before attesting; pre-flight will hard-reject the contract
   > regardless (G8 gate).

3. **Schema validation.** Parse the YAML and validate against
   `afk/schemas/goal-contract.v1.json` (from the valesco-platform repo —
   either vendored locally or looked up via the repo's `.afk/` sibling).
   Fail loudly on AJV errors and list them.

4. **Tier 1 canary-plan check.** If `metadata.tier === 1` and
   `canaryPlan` is missing, refuse:

   > Refusing to run. Tier 1 contracts require a canaryPlan block
   > (metrics, thresholds, rollbackTrigger, windowMinutes) per governance
   > plan G10. Author it before attesting.

5. **Existing attestation check.** If
   `.afk/attestations/<linearIssueId>.json` already exists:

   > Prior attestation exists at <path>, attested <attestedAt> with
   > `attestedContentSha` <sha>. Current YAML sha is <sha'>. {Match /
   > Drift}. Proceeding will overwrite. OK?

## Process

### Step 1 — load + introspect

Read `.goal-contract.yml`, parse, and compute:
- `linearIssueId` — from `metadata.linearIssueId`
- `tier` — from `metadata.tier`
- `attestedContentSha` — `"sha256:" + sha256(raw file bytes)` (no
  canonicalization; raw bytes is the contract per the keying decision)
- `attester` — shell out to `git config user.name` and
  `git config user.email` → `"<name> <<email>>"`
- `timeSinceDraftMinutes` — if a prior `.goal-contract.draft.yml` exists,
  use its mtime; else skip the field.

### Step 2 — render the checklist

Load [`checklist.md`](./checklist.md) and render the items that apply:

- All items marked "all tiers" render always.
- Items marked "tier 1 only" render only when `tier === 1`.
- Items marked "tier 3 only" render only when `tier === 3`.
- Incident-override item renders only when `metadata.incidentOverride`
  is present.

For each item, prompt the user with:

> [ ] `<id>` — `<label>`
>
> Tick (y), skip with rationale (s), or abort (a)?

Do not batch-prompt. One item at a time. A skipped item requires a
rationale string; do not accept a blank.

### Step 3 — adversarial-review posture

Ask the user:

> Adversarial review: has it been reviewed (r), is it pending (p), or
> was it not run (n)?

Store the answer in `adversarialReviewStatus`. This is a breadcrumb —
the authoritative adversarial record lives in the audit store.

### Step 4 — write the record

Write to `.afk/attestations/<linearIssueId>.json`. Use the shape in
[`record-reference.md`](./record-reference.md). Pretty-print with
2-space indent; trailing newline.

If `.afk/attestations/` does not exist, create it. The skill is
allowed to create `.afk/`-nested paths under attestations — that
directory is not on the hard floor.

### Step 5 — verify against schema

Validate the written JSON against
`afk/schemas/attestation-record.v1.json`. On failure, delete the file
and report the error. Never leave a malformed record on disk.

### Step 6 — print next steps

```
Attestation written: .afk/attestations/<linearIssueId>.json
  tier: <N>
  ticked: <count> / <total>
  skipped: <count> (rationales required)
  attestedContentSha: <first 12 hex chars>…
  adversarialReviewStatus: <reviewed | pending | not-run>

Next:
  1. Commit the attestation record to the scope PR branch.
  2. Confirm the delay window has elapsed:
       • Tier 1 default: 15 min (30 min sensitive; 60 min meta-contract)
       • Tier 2 default: 5 min (15 min sensitive; 30 min meta-contract)
       • Tier 3 default: 0 min (5 min sensitive; 15 min meta-contract)
  3. Apply the `afk-ready` label.
  4. The label handler will re-verify `attestedContentSha` matches the
     current YAML and reject the promotion on drift.

Any edit to `.goal-contract.yml` after this moment invalidates the
attestation — re-run `/attest` after every authority-bearing change.
```

## Self-validation before returning

- [ ] `.afk/attestations/<linearIssueId>.json` exists and parses as JSON.
- [ ] Record validates against `attestation-record.v1.json`.
- [ ] `attestedContentSha` matches `sha256:` + sha256 of current
      `.goal-contract.yml` bytes.
- [ ] Every `state: "skipped"` item has a non-empty `rationale`.
- [ ] Every `state: "ticked"` item has no `rationale` field.

If any check fails, delete the record and report the specific failure.

## Non-goals

- **No label application.** G1 mandates the human applies `afk-ready`
  by hand, consciously, after attestation. Automating this collapses
  the separation-of-concerns the attestation exists to enforce.
- **No pre-flight invocation.** Pipeline runs on its own triggers.
- **No adversarial-review execution.** The skill records posture only;
  running adversarial review is a separate pipeline concern.
- **No override-rate tracking.** Circuit-breaker + weekly cap live in
  pipeline per G1, not here.
- **No canonical-normalization.** Raw-bytes sha is authoritative for
  now; canonical form is a separate future ticket.

## References

- `valesco-platform/afk/schemas/attestation-record.v1.json` (authoritative
  record shape)
- `valesco-platform/afk/schemas/goal-contract.v1.json` (contract
  pre-validation)
- `valesco-platform/docs/afk/governance-plan.md` §G1 (checklist rationale)
- `valesco-platform/docs/afk/governance-plan.md` §7 (authority chain —
  hash binding)
- [`../draft-contract/SKILL.md`](../draft-contract/SKILL.md) (upstream
  skill)
- [`./checklist.md`](./checklist.md) (per-tier checklist items)
- [`./record-reference.md`](./record-reference.md) (record shape worked
  example)
