# CONTEXT.md

Ubiquitous language for the flightplan plugin and the AFK pipeline it
serves. Terms here are what skills, agents, and humans use to describe the
domain. Implementation details (file paths, MCP names, framework choices)
are out of scope — see the relevant `SKILL.md` files for those.

Format follows Matt Pocock's
[CONTEXT-FORMAT](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/CONTEXT-FORMAT.md).
Update inline as terms become contested or sharpened during a
`/grill-with-docs` or `/improve-codebase-architecture` run — don't batch.

---

## Pipeline domain

**AFK** — *Away From Keyboard.* The Valesco autonomous-coding governance
pipeline that takes an attested goal-contract through pre-flight,
runner dispatch, validation, and gated promotion. Lives in
[`valesco-platform/afk/`](https://github.com/ValescoAgency/valesco-platform);
flightplan skills feed it.

**Goal contract** — a `.goal-contract.yml` at a repo's root specifying
intent, write paths, budget, success criteria, verifiers, and (Tier 1)
canary plan. The contract is the agreement between the human and the AFK
runner; pre-flight rejects malformed or under-specified contracts per §G8.

**Attestation** — the human's act of confirming a goal-contract is ready
for AFK execution. Produces a record at `.afk/attestations/<id>.json`
keyed by issue ID and bound to the YAML bytes via SHA-256. The label
handler refuses to promote on sha drift.

**afk-ready** — the label that triggers pre-flight. Applied by the human,
never by a skill, after the tier-appropriate delay window (§G1). Its
application is the last conscious step before pipeline takeover.

**Tier** — `1` / `2` / `3`. Sets the determinism bar, delay window, and
required artefacts. Tier 1 = production / client-critical (canary plan
required). Tier 3 = prototype / side project.

**HITL** — *Human In The Loop.* An issue or stage that requires human
judgment and cannot become an AFK contract. Routed to `ready-for-human`
rather than coerced toward AFK.

## Tracker domain

**Tracker** — the system where issues, comments, labels, and statuses
live. For Valesco, that's Linear today; the adapter contract makes it
swappable. Other supported targets (per the rollout plan): GitHub Issues
(planned proof-of-concept), Jira (deferred), local markdown (deferred).

**Tracker adapter** — the per-vendor module satisfying a uniform
operations API for the rest of flightplan to call. Lives at
`tracker-<provider>/SKILL.md` with a sibling `labels.yml`. Each adapter
declares its capability set; consumer skills check capabilities before
using vendor-specific features.

**Active tracker** — the adapter selected at session start by reading
`.afk/config.yml`'s `tracker:` field. Default `linear` if absent. Missing
adapter SKILL.md = refuse and surface; no silent fallback.

**Capability set** — the optional features an adapter declares.

- **Floor** (every adapter implements): `fetch_issue`, `list_comments`,
  `post_comment`, `apply_labels`, `set_status`.
- **Optional**: `customer_field`, `project_membership`, `cycle_membership`,
  `team_namespace`, `active_work_detection`.

**Active-work detection** — capability tier (`reliable | best-effort |
none`) describing how confidently an adapter can identify an issue
currently being worked on. Linear: reliable (native `In Progress` /
`In Review`). GitHub: best-effort (linked PR + assignee, or Projects v2).
Local markdown: none. The `triage` skill gates its read-only-on-active-work
protection on this capability.

## Process artefacts

**Agent Brief** — the structured comment that tells an AFK runner what to
build. Format lives in `triage/AGENT-BRIEF.md`; delivery happens via the
active tracker's `post_comment`. Vendor-agnostic shape; only delivery
differs per tracker.

**Triage Notes** — the comment posted when an issue moves to `needs-info`.
Lists what's established and the specific facts required to make the
issue AFK-ready.

**Out-of-scope KB** — `.out-of-scope/<concept>.md` files in the working
repo, written when a Feature/Improvement is rejected. Future triage runs
read these to surface "we already rejected this" matches.

## Canonical state machine

Vocabulary that consumer skills use unchanged across vendors. Adapters
translate to/from vendor-native names per `tracker-<provider>/labels.yml`,
with optional per-repo override at `.afk/tracker-labels.yml`.

**State labels**: `needs-triage`, `needs-info`, `ready-for-agent`,
`ready-for-human`, `wontfix`.

**Category labels**: `Bug`, `Feature`, `Improvement`.

**Status values**: `triage`, `backlog`, `todo`, `in-progress`,
`in-review`, `done`, `canceled`, `duplicate`.
