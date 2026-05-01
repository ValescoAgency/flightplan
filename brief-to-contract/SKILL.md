---
name: brief-to-contract
description: Orchestrate a tracker issue through the full Valesco AFK chain — from triage to attested goal-contract — by sequentially invoking the right per-stage skills (`/triage`, `/diagnose`, `/grill-with-docs`, `/draft-contract`, `/attest`). Use when the user says "take VA-NNN through to attested contract", "run brief-to-contract for VA-NNN", "I want to AFK this issue", "walk this through the pipeline", "what's the next step on VA-NNN", or asks to drive a tracker ticket end-to-end toward an AFK run. This skill IS the orchestration spine — it does not replace `/triage` (one-shot triage), `/draft-contract` (one-shot draft), or `/attest` (one-shot attestation); it composes them with the right gates, resume detection, and HITL exits. Reach for it whenever you'd otherwise be manually stitching those skills together to advance one issue.
---

# /brief-to-contract

Walk a tracker issue from inbound state all the way to an attested
`.goal-contract.yml` that is ready for the human to apply `afk-ready` to.
The skill is a **stitcher** — it sequences calls to the per-stage skills,
detects which stage is already done, enforces the gates between them, and
exits cleanly when an issue turns out to be HITL.

This skill writes **no authority-bearing artefacts of its own**. It posts
status comments to the active tracker (with the AI disclaimer), and it tells *other*
skills to write things. The afk-ready label is never applied here — that
is deliberate human work per governance plan §G1.

## When to run

When you have a tracker issue (or want to find one) and intend to drive it
toward an AFK run. The skill picks the right starting stage based on the
issue's current state — you don't need to know whether triage has
happened, or a draft exists, or attestation is in place. It detects all of
that.

## When NOT to run

- The issue is already attested and `afk-ready` is applied — pipeline owns
  it now; this skill is read-only at that point and will just print the
  current status.
- The user wants to do a single stage by hand (just triage, just draft,
  just attest) — invoke the per-stage skill directly. This one is for the
  end-to-end walk.
- The repo is a control plane (`afkEligible: false`) — the skill refuses
  in Stage 0 and routes the user to `/triage` for `ready-for-human`
  instead.

## Authority boundary — what this skill never does

| Action | Why this skill doesn't do it |
|---|---|
| Apply the `afk-ready` label | §G1 — the human applies it consciously, after the delay window, as the last act before pre-flight. |
| Run pre-flight | §G1 — pre-flight triggers on the label, not on this skill. |
| Auto-fill `<PLANNER_SUGGESTED:>` tokens | §G8 — every authority field is human-authored. |
| Rename `.goal-contract.draft.yml` → `.goal-contract.yml` | §G8 — the rename is the human's act of taking ownership of the contract content. |
| Modify `.afk/attestations/*.json` directly | The `/attest` skill owns that path. This one calls `/attest`; it doesn't write the record. |
| Open the scope PR | Out of scope per existing per-skill non-goals. |
| Skip stages on user request without confirmation | The skill confirms the resume point but won't bypass a structural gate (e.g., it won't draft a contract for an issue that hasn't been triaged). |

## Stage 0 — Pre-flight

Read `.afk/config.yml` at the working repo root before doing anything else.

| Field | Effect |
|---|---|
| `afkEligible: false` | **Refuse and route.** Print: "This repo is a control plane (afkEligible:false). AFK contracts cannot run against it (§14.3). Hand the issue to `/triage` and drive it to `ready-for-human` instead." Then stop. |
| `afkEligible: true` + `projectTier: 1` | Note for later — the skill will recommend canaryPlan when entering Stage 4. |
| `afkEligible: true` + `projectTier: 2` or `3` | Standard chain applies. |
| missing | Surface to the maintainer. The skill cannot orchestrate without knowing tier and eligibility. |

Also confirm the working directory is a git repo with `.afk/` present —
otherwise this isn't an AFK-aware repo and the skill has nothing to
orchestrate.

## Resume detection — pick the right entry stage

Before announcing a stage, the skill walks the artefact tree and decides
the entry point. Detection rules in detail:
[`state-machine.md`](./state-machine.md). Summary table:

| Existing artefact | Entry stage | Skill announces |
|---|---|---|
| `.afk/attestations/<linearIssueId>.json` exists, sha matches current `.goal-contract.yml` | Stage 8 | "Already attested. Printing hand-off." |
| `.goal-contract.yml` exists, no `<PLANNER_SUGGESTED:>` tokens, no attestation record (or sha drift) | Stage 7 | "Contract authored; entering attestation." |
| `.goal-contract.yml` exists, but `<PLANNER_SUGGESTED:>` tokens remain | Refuse to advance | "Contract has unreplaced tokens. Replace them, then I'll run /attest." |
| `.goal-contract.draft.yml` exists, no `.goal-contract.yml` | Stage 5 | "Draft exists; awaiting token replacement + rename." |
| issue status is `todo` + `ready-for-agent` + has Agent Brief comment | Stage 2 (or 4 if Bug already has captured reproducer / not a Bug) | "Brief in place; entering diagnosis check." |
| issue status is `triage` or has `needs-info` | Stage 1 | "Issue not yet brief-ready; entering triage." |
| issue status is `in-progress` / `in-review` / `reviewed` | **Read-only** | "Issue is in active work; this skill is read-only on those statuses." |

Always **announce** the detected resume point and ask the user to confirm
or override before proceeding. A misdetected resume point can skip a gate
the user wanted to revisit.

## Stage 1 — Triage gate

If the issue isn't yet at `status=Todo` + `label=ready-for-agent` + has an
Agent Brief comment, invoke [`/triage`](../triage/SKILL.md)
and let it do its work.

After triage returns, branch on the outcome:

| Triage outcome | Action |
|---|---|
| `ready-for-agent` | Continue to Stage 2. |
| `ready-for-human` | **HITL exit.** Print the human-brief that triage authored, plus a one-line "this issue is being handed to you, not to AFK — work it manually." Stop. |
| `needs-info` | **Pause exit.** Print "Triage posted Triage Notes; the reporter needs to answer before this can advance. Re-run me when they reply." Stop. |
| `Backlog` / `Canceled` / `Duplicate` | **Done exit.** Print the resolution and stop. The chain doesn't apply. |

Triage is also where the **HITL fork** is most likely to fire. The skill
never tries to coerce a `ready-for-human` issue back toward AFK.

## Stage 2 — Diagnosis gate (Bugs only)

For category `Bug`, check whether the Agent Brief contains a captured
reproducer:

- A linked Phase 1 feedback loop (script, test path, harness file)
- A regression test reference under `intent.successCriteria` shape
- An explicit "reproduced via X" line in the brief

If any of those is missing, invoke [`/diagnose`](../diagnose/SKILL.md). The
diagnose run will:

1. Build the feedback loop (`/feedback-loop` patterns 1–10).
2. Reproduce the bug.
3. Hypothesise + instrument + fix-or-document.
4. Output a regression test and a verifier-ready loop command.

After `/diagnose` returns, **fold its outputs back into the tracker issue**:

- Append a comment (with AI disclaimer) summarizing: feedback-loop
  command, regression test path, the post-mortem one-liner.
- Update the Agent Brief comment in place if it lacks the reproducer
  reference. (The brief is what `/draft-contract` reads — keep it
  current.)

If `/diagnose` exits at Phase 1 because no reproducer can be built, this
is a **HITL-back-to-triage exit**. Drop back to Stage 1 with a
`needs-info` recommendation listing the specific blockers diagnose found
(reproducer access / captured artefact / production instrumentation).

For categories `Feature` / `Improvement`, skip this stage — there's no bug
to reproduce.

## Stage 3 — Domain alignment gate (optional)

Read [`CONTEXT.md`](../docs/workflow.md#contextmd--ubiquitous-language)
and skim [`docs/adr/`](../docs/workflow.md#adrs). Then read the Agent
Brief.

Invoke [`/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)
**only when** at least one of these holds:

- The brief uses a domain term that isn't in `CONTEXT.md` *and* could
  be ambiguous (e.g. "account" without a Customer/User distinction).
- The brief proposes an architectural shape that contradicts an existing
  ADR.
- Tier-1 brief whose `intent.description` is fewer than 200 chars — the
  pipeline will likely accept it, but the AFK runner will produce
  generic code without sharper context.

Otherwise, **skip this stage**. The grill is genuine work — don't impose
it on issues that don't need it.

After grill returns, treat any new ADRs or `CONTEXT.md` updates as
follow-on commits the user should make on the scope PR branch (when
they open it in Stage 8).

## Stage 4 — Draft

Before invoking, do **tier escalation detection**:

| Signal | Recommend |
|---|---|
| Issue has a `customer` field set (when adapter declares `customer_field`) | Tier 1 |
| Likely `writePaths` touch `**/auth/**`, `**/billing/**`, `**/migrations/**`, `supabase/migrations/**`, `src/**/payment*` | Tier 1 |
| Issue is in a Tier-1 project per `.afk/config.yml` | Tier 1 |
| None of the above | Tier 3 default (matches `/draft-contract`'s posture) |

Tell the user the recommendation and the reason, then invoke
[`/draft-contract`](../draft-contract/SKILL.md) with the issue ID.
The draft skill writes `.goal-contract.draft.yml` with
`<PLANNER_SUGGESTED:>` tokens for human-authored fields; for Tier 1, the
`canaryPlan` block is one of those tokens.

After `/draft-contract` returns, post a tracker comment (with AI
disclaimer) noting that the draft is in place and what the user needs to
do next (token replacement). Do not include the contract contents in the
comment — that's noise, and it tempts future readers to edit the contract
in the tracker instead of in the file.

## Stage 5 — Token replacement (HITL by design)

Print the list of every `<PLANNER_SUGGESTED:>` token currently in the
draft, with file:line locations and the descriptive token text. Then **wait**.

The user replaces tokens by hand. This is a §G8 gate — auto-fill is
explicitly forbidden because tokens mark fields where authority must be
human-derived (the agent doesn't know which globs are right; it can only
suggest).

A reasonable presentation:

```
.goal-contract.draft.yml has 6 unreplaced <PLANNER_SUGGESTED:> tokens:

  L24  writePaths:
       - "<PLANNER_SUGGESTED: propose minimal globs under src/app/api/...>"
  L31  budget.timeMinutes
       "<PLANNER_SUGGESTED: 15-30 for routine, 60+ for migration-heavy>"
  L48  canaryPlan
       "<PLANNER_SUGGESTED: required for Tier 1 — name metrics, thresholds...>"
  ...

Replace each token with a real value, then say "tokens replaced" or
re-run me. I will not auto-fill.
```

When the user says they're done (or re-invokes the skill), grep the file
for the token marker. If any remain, list them and stop. If none remain,
advance to Stage 6.

## Stage 6 — Rename

Prompt the user to rename `.goal-contract.draft.yml` →
`.goal-contract.yml`. **Do not perform the rename.** The act is the human
taking ownership of the contract content per §G8 — the skill renaming it
collapses the meaningfulness of that act.

```
Tokens replaced. Rename the file when ready:

  mv .goal-contract.draft.yml .goal-contract.yml

When the rename is in place, say "renamed" or re-run me. I will check the
file exists at the new path and advance to attestation.
```

When the user confirms, verify `.goal-contract.yml` exists and
`.goal-contract.draft.yml` is gone. If both exist, refuse — having two
contract files at once is a dangerous state. If only the draft remains,
prompt again. Only when exactly `.goal-contract.yml` exists at the root,
proceed.

## Stage 7 — Attest

Invoke [`/attest`](../attest/SKILL.md). The attestation skill walks the
human through the tier-scaled checklist and writes
`.afk/attestations/<linearIssueId>.json`.

This skill **blocks** until the attestation record exists with
`attestedContentSha` matching the current YAML. If `/attest` is aborted
or the user skips it, the chain stops here — there is no Stage 8 without
a fresh attestation.

After `/attest` returns successfully:

- Verify `.afk/attestations/<linearIssueId>.json` parses, validates, and
  matches the current YAML's sha.
- If sha drift is detected later (the user edited the contract after
  attestation), refuse Stage 8 and tell them to re-attest.

Post a tracker comment (with AI disclaimer) confirming attestation is in
place — but **never** the attestation record contents.

## Stage 8 — Hand-off

Print the final next-steps block:

```
Contract attested for <TEAM-NNN> ("<issue title>"):
  tier:        <N>
  attestedContentSha: <first 12 hex chars>...
  attestedAt:  <ISO timestamp>
  attester:    <name <email>>

Next, by hand:
  1. Open the scope PR with "Fixes <TEAM-NNN>" in the body.
     Commit the attestation record to the scope PR branch.
  2. Wait the tier-appropriate delay window:
       Tier 1: 15 min (30 min sensitive; 60 min meta-contract)
       Tier 2: 5 min  (15 min sensitive; 30 min meta-contract)
       Tier 3: 0 min  (5 min sensitive;  15 min meta-contract)
  3. Apply the `afk-ready` label.
     The label handler will re-verify attestedContentSha against the
     current YAML and refuse promotion on drift.
  4. Pre-flight runs. AFK takes over.

Any edit to .goal-contract.yml after this moment invalidates the
attestation — re-run /attest first, then re-apply the label.

This skill is done. The pipeline owns the issue from here.
```

Stop after printing. Don't apply the label. Don't open the PR. Don't
trigger pre-flight.

## HITL fork — exit conditions across stages

The HITL fork can fire at any stage. When it does, exit cleanly with
whatever progress was captured. Never coerce a HITL issue toward AFK.

| Stage | HITL trigger | Exit message |
|---|---|---|
| 0 | `afkEligible: false` | "Control plane — route to `/triage` for `ready-for-human`." |
| 1 | Triage decides `ready-for-human` | Show the human-brief; stop. |
| 1 | Triage decides `needs-info` | Show the missing facts; stop. |
| 2 | `/diagnose` cannot build a reproducer | Drop back to Stage 1 with a specific `needs-info` recommendation. |
| 3 | `/grill-with-docs` reveals the user has no clear answer (e.g. genuine open architectural question) | Pause — the question is real engineering work, not contract drafting. |
| 4 | Tier-1 escalation declined and the issue still touches sensitive globs | Stop and ask whether to retag the issue or accept Tier 1. |
| 5 | Tokens reveal the user genuinely doesn't know the right values | Surface the unknowns, drop back to Stage 3 (grill). |
| 7 | Attestation aborted | Stop — without attestation there is no afk-ready. |

## Tier escalation logic (detail)

Tier 1 contracts require canaryPlan. The skill's job is to **detect early**
and recommend Tier 1 *before* `/draft-contract` runs, so the draft is
authored with Tier-1 defaults rather than retrofitted.

Detection inputs:

1. **`.afk/config.yml`** — if `projectTier: 1`, all issues default to Tier 1.
2. **Issue body** — does it mention a customer name? Production
   incident ID? "client-critical" / "billing" / "auth flow" language?
3. **Inferred `writePaths`** — read the brief, plus any architectural
   anchors. If the writes likely touch sensitive globs, escalate.
4. **`/diagnose` output** — if the regression test sits in
   `**/auth/**` or similar, escalate.

Surface the recommendation as one paragraph before Stage 4 begins:

```
Recommending Tier 1 for this contract:
  - Issue customer field is set: <name>
  - writePaths likely include src/app/api/billing/**

Tier 1 means:
  - canaryPlan block required (metrics, thresholds, rollback trigger, window)
  - 15-min minimum delay window before afk-ready (30 min sensitive)
  - Adversarial review must complete before label

Confirm Tier 1, downgrade, or pause to discuss?
```

Do not silently set the tier — confirm with the user and pass their
choice to `/draft-contract` so the draft is built right.

## AI disclaimer for tracker comments

Every tracker comment this skill posts (status announcements, stage
hand-offs, attestation confirmations) starts on its own line with:

```
> *This was generated by AI during triage.*
```

The skill posts comments at: end of Stage 4 (draft created), end of
Stage 7 (attestation in place). It does **not** post per-stage chatter —
the tracker is for durable status, not progress reports.

Local files (the contract draft, the attestation record, debug scripts)
carry their own provenance via git history; no disclaimer needed.

## Self-validation before declaring done

When the skill reaches Stage 8 hand-off, check:

- [ ] `.goal-contract.yml` exists at repo root, parses as YAML, no
      `<PLANNER_SUGGESTED:>` tokens.
- [ ] `.afk/attestations/<linearIssueId>.json` exists, parses, and
      validates against the v1 schema.
- [ ] `attestedContentSha` in the record == `sha256:` + sha256 of current
      `.goal-contract.yml` bytes.
- [ ] No `.goal-contract.draft.yml` lingering in the working tree.
- [ ] Tier in the contract matches the recommendation made in Stage 4.
- [ ] For Tier 1: `canaryPlan` block is non-empty and has metrics,
      thresholds, rollbackTrigger, windowMinutes.
- [ ] Tracker issue has the Agent Brief comment + `ready-for-agent` label
      + status `Todo`.

If any check fails, do not print the hand-off block. Surface the
specific failure and the remediation path.

## Non-goals

- **No `afk-ready` label application.** §G1.
- **No pre-flight invocation.** Pipeline triggers on the label, not on
  this skill.
- **No scope-PR creation.** Separate operation; the user opens the PR by
  hand.
- **No token auto-fill.** §G8.
- **No file-level rename of draft → final.** §G8.
- **No canonical YAML normalization.** Raw-bytes sha is authoritative for
  now, per the keying decision in [`/attest`](../attest/SKILL.md).
- **No status change to `In Progress` / `In Review` / `Reviewed`.** Those
  belong to active development work, downstream of this skill.
- **No editing of the goal-contract by this skill.** All authoring goes
  through `/draft-contract` or the human directly.

## References

- [`../triage/SKILL.md`](../triage/SKILL.md) — Stage 1.
- [`../diagnose/SKILL.md`](../diagnose/SKILL.md) — Stage 2.
- [`../feedback-loop/SKILL.md`](../feedback-loop/SKILL.md) — invoked
  inside `/diagnose` Phase 1.
- [Matt Pocock's `/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md) — Stage 3.
- [`../draft-contract/SKILL.md`](../draft-contract/SKILL.md) — Stage 4.
- [`../attest/SKILL.md`](../attest/SKILL.md) — Stage 7.
- [`./state-machine.md`](./state-machine.md) — full resume-point detection
  rules.
- `valesco-platform/docs/afk/governance-plan.md` §G1 (label discipline —
  why this skill never applies `afk-ready`).
- `valesco-platform/docs/afk/governance-plan.md` §G8 (planner→main token
  gate — why tokens stay tokens until a human replaces them).
- `valesco-platform/docs/afk/governance-plan.md` §G10 (Tier-1 canaryPlan
  requirement).
- `valesco-platform/docs/afk/governance-plan.md` §14.3 (control-plane
  self-modification refusal).
