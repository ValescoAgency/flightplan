# State machine — resume-point detection

Detail for [`SKILL.md`](./SKILL.md). The orchestration spine has eight
stages and is **idempotent on each invocation** — re-running the skill
on the same tracker issue should land at the right stage, never redo
work, and refuse to advance through a structural gate.

The detection rules below are evaluated **top-to-bottom on every
invocation**. The first rule that matches sets the entry stage.

## Detection table

Read in order. Stop at the first match.

| # | Detection signal | Entry | Confirmation prompt |
|---|---|---|---|
| 1 | `.afk/config.yml` is missing OR `afkEligible: false` | Refuse | "This repo is a control plane (or unlinked). Routing to `/triage` for `ready-for-human`." |
| 2 | `.afk/attestations/<linearIssueId>.json` exists AND its `attestedContentSha` matches `sha256:` + sha256 of current `.goal-contract.yml` bytes | Stage 8 | "Already attested for `<TEAM-NNN>`. Sha matches. Printing hand-off — confirm OK?" |
| 3 | `.afk/attestations/<linearIssueId>.json` exists BUT sha does not match current YAML | Stage 7 | "Attestation exists but the YAML drifted (sha mismatch). I will re-attest. Confirm OK?" |
| 4 | `.goal-contract.yml` exists, no `<PLANNER_SUGGESTED:>` tokens, no attestation record | Stage 7 | "Contract authored, ready for attestation. Entering /attest. Confirm OK?" |
| 5 | `.goal-contract.yml` exists AND any `<PLANNER_SUGGESTED:>` tokens remain | Refuse | "Contract has unreplaced tokens at lines `<list>`. Replace them, then re-run me. I will not auto-fill." |
| 6 | Both `.goal-contract.yml` AND `.goal-contract.draft.yml` exist | Refuse | "Both files exist — that's a dangerous state. Pick one: keep the draft and delete the final, or vice versa. Then re-run." |
| 7 | `.goal-contract.draft.yml` exists, no `.goal-contract.yml` | Stage 5 | "Draft in place. Listing unreplaced tokens for you to address. Confirm OK?" |
| 8 | issue status is `in-progress` / `In Review` / `Reviewed` | Read-only | "Issue is in active work. This skill is read-only on those statuses. Showing current state only." |
| 9 | issue status is `done` / `Canceled` / `Duplicate` | Read-only | "Issue is closed (`<status>`). Nothing for the chain to do. Showing the resolution." |
| 10 | issue status is `backlog` | Read-only | "Issue parked in Backlog. Re-triage it via `/triage` to bring it back into the funnel before running me." |
| 11 | issue status is `todo` AND has `ready-for-human` label | Read-only HITL | "This issue is HITL — work it manually, not through AFK. Showing the human-brief from the triage comment." |
| 12 | issue status is `todo` AND has `ready-for-agent` label AND has an Agent Brief comment AND category is `Bug` AND brief lacks captured reproducer (per Stage 2 detection) | Stage 2 | "Brief in place but no captured reproducer. Entering `/diagnose`. Confirm OK?" |
| 13 | issue status is `todo` AND has `ready-for-agent` AND has Agent Brief AND (category is not `Bug` OR reproducer is captured) AND domain alignment looks suspect (per Stage 3 heuristics) | Stage 3 | "Brief in place; one or more domain terms / decisions need locking down. Entering `/grill-with-docs`. Confirm OK or skip?" |
| 14 | issue status is `todo` AND has `ready-for-agent` AND has Agent Brief AND nothing further is needed pre-draft | Stage 4 | "Brief is solid. Entering `/draft-contract`. Confirm tier recommendation: `<tier>` (`<reason>`)." |
| 15 | issue status is `triage` or `needs-info` (any other shape) | Stage 1 | "Issue not yet brief-ready. Entering `/triage`. Confirm OK?" |

If none of the above matches, refuse and surface the issue's current
labels + status — something unexpected is going on, and the user should
look before the skill acts.

## Detection-rule notes

### Rule 2 vs Rule 4 — sha computation

Both rules compute `sha256:` + sha256 of the **raw bytes** of
`.goal-contract.yml`. No canonicalization. This matches the keying
decision in [`/attest`](../attest/SKILL.md) — the contract is the bytes,
not a normalized form.

If the file has trailing-newline drift between editors, the sha will
differ and the skill will fall into Rule 3 (re-attest). That's correct:
any byte-level edit invalidates the attestation per §G1.

### Rule 5 — token detection

Grep the YAML bytes for the literal substring `<PLANNER_SUGGESTED:`. Do
not try to parse the YAML first — partial-replacement states (where the
user replaced some tokens but left others) are common, and YAML may
parse fine while still containing token strings.

The detection captures and reports each line containing a token, so the
user sees exactly what's left.

### Rule 6 — both files present

This state is dangerous because:

- The draft may have a different sha than the final, leading to
  attestation against the wrong content.
- Pre-flight will validate `.goal-contract.yml` but the user may have
  been editing `.goal-contract.draft.yml` instead.
- It's a sign of a broken Stage 6 — the rename was done by copy-paste
  and the draft was never deleted.

Refuse to advance until the user resolves it. Don't pick for them — the
right resolution depends on whether the user has continued editing the
draft after creating the final.

### Rules 8–11 — read-only states

The skill never mutates issues that have left the triage funnel. For
those statuses, print the current state in a single block:

```
<TEAM-NNN> "<title>"
  status: <canonical status>
  labels: <comma-separated>
  category: <Bug|Feature|Improvement>
  state:    <ready-for-agent|ready-for-human|needs-info|none>

Briefs / artefacts in place:
  - Agent Brief comment: <yes/no>
  - .goal-contract.draft.yml: <yes/no>
  - .goal-contract.yml: <yes/no>
  - .afk/attestations/<id>.json: <yes/no, sha-match-yes/no>

This skill is read-only here. <reason from rule>.
```

### Rule 12 — bug-without-reproducer detection

The Agent Brief is considered to have a captured reproducer if **any**
of the following is true:

- The brief includes a fenced code block under a heading like
  `## Reproducer`, `## Repro`, or `## Feedback loop`.
- The brief references a path under `scripts/debug/`, `tests/`, or a
  test framework's conventional location (e.g. `*.test.ts`,
  `*_test.py`).
- An `intent.successCriteria`-shaped bullet describes a verifiable
  observation (≥ 5 chars, contains "When …" or "expect …" phrasing).

If none holds, treat the bug as un-reproduced and route to `/diagnose`.

### Rule 13 — domain-alignment suspicion

Heuristics for "looks suspect":

- The brief uses a noun the project has no glossary entry for, where
  ambiguity is plausible (e.g. uses "user" when the codebase has both
  `Customer` and `User` types).
- The brief mentions `should ` followed by an architectural pattern
  (event-sourced, queue-based, batch, etc.) that no ADR has decided on.
- A Tier-1 brief whose `intent.description` is < 200 chars total — too
  thin to give an AFK runner enough to work with.

These are heuristics, not rules. The user can confirm "skip the grill"
and the skill respects that — domain alignment is genuine work, not
mandatory ceremony.

### Rule 14 — entering Stage 4 with tier recommendation

The detection rule fires only after Stages 2 and 3 are confirmed
unnecessary. The confirmation prompt includes the tier recommendation
inline because tier choice changes the draft's contents — a confirmed
recommendation feeds straight into `/draft-contract`'s Tier-1 / Tier-2 /
Tier-3 default selection.

Tier reasoning the prompt should always cite:

| Tier 1 reason | Source |
|---|---|
| `customer` field set on the issue | active tracker adapter |
| Project itself is Tier 1 in `.afk/config.yml` | Pre-flight |
| Likely `writePaths` touch `**/auth/**`, `**/billing/**`, `**/migrations/**`, `supabase/migrations/**`, `src/**/payment*` | Brief inference |
| Issue body mentions "production", "client-critical", an incident ID | issue body parse |

Single hit → escalate and ask. Multiple hits → escalate and ask, with
all reasons listed.

## Override rules

The user can override the detected entry stage. Allowed overrides:

- **Earlier stage** (e.g. detected Stage 7, user wants to redo Stage 4):
  prompt for a reason, then proceed. Earlier overrides imply the user
  is aware the existing artefacts will be re-created or invalidated.
  Make that explicit:

  > Re-entering Stage `<N>` will likely invalidate the existing
  > `<artefact>`. Confirm?

- **Later stage** (e.g. detected Stage 4, user wants to skip to Stage 7):
  **refuse**. Skipping a structural gate defeats the purpose of the
  spine. The user can invoke the per-stage skill (e.g. `/attest`)
  directly if they want to bypass.

- **Read-only override** (e.g. detected `In Progress`, user wants to
  re-attest because something changed): refuse. Active-work statuses
  belong to the developer doing the work, not to this skill.

When refusing an override, point at the per-stage skill the user can
invoke directly. The orchestration spine refusing an override is not the
same as the user being blocked.

## What this state machine does NOT track

- **Time / delay window** — the tier-appropriate delay between Stage 7
  and the user applying `afk-ready` is **not** tracked here. The
  governance plan §G1 puts that gate in the label handler, not in this
  skill.
- **Adversarial review status** — that's a pipeline concern, recorded by
  the audit store (per §G1). The attestation record carries a breadcrumb
  (`adversarialReviewStatus: reviewed | pending | not-run`) but this
  skill does not gate on its value.
- **PR open/closed** — the scope PR is opened by the user after Stage 8.
  This skill never reads PR state.
- **CI status** — same; CI runs on the PR, downstream of this skill.

If any of those cross into scope, they belong in pipeline code at
`valesco-platform/afk/`, not here. The skills-vs-pipeline rule is
load-bearing.
