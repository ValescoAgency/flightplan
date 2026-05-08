# CONTEXT.md

Ubiquitous language for the flightplan plugin. Terms here are what skills,
agents, and humans use to describe the domain. Implementation details
(file paths, MCP names, framework choices) are out of scope — see the
relevant `SKILL.md` files for those.

Format follows Matt Pocock's
[CONTEXT-FORMAT](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/CONTEXT-FORMAT.md).
Update inline as terms become contested or sharpened during a
`/grill-with-docs` or `/improve-codebase-architecture` run — don't batch.

---

## Workflow domain

**Runway** — the Valesco autonomous-coding CLI at
[`ValescoAgency/runway`](https://github.com/ValescoAgency/runway). Reads
issues from a tracker, calls `@ai-hero/sandcastle` per issue (Claude Code
in Docker), runs an adversarial sub-agent review, and opens a PR. Trust
comes from human PR review, not gates. Flightplan's skills feed runway
indirectly by getting issues into a state where runway will pick them up.

**Sandcastle** — `@ai-hero/sandcastle`, the package runway uses to run
Claude Code inside an isolated Docker sandbox per issue.

**Claude Code** — the agent runtime running inside the sandbox.
Implements whatever the issue describes; the issue body is the spec.

**Sub-agent review** — adversarial pass run by runway before opening the
PR. Looks for the same things a careful human reviewer would: regressions,
missing tests, scope creep, brittle patterns. Output goes in the PR body.

**HITL** — *Human In The Loop.* An issue or stage that needs human
judgment and shouldn't go to runway. Routed to `needs-human` rather than
`Todo`.

## Tracker domain

**Tracker** — the system where issues, comments, labels, and statuses
live. For Valesco, that's Linear today; the adapter contract makes it
swappable. Other supported targets: GitHub Issues (shipped), Jira
(deferred), local markdown (deferred).

**Tracker adapter** — the per-vendor module satisfying a uniform
operations API for the rest of flightplan to call. Lives at
`tracker-<provider>/SKILL.md` with a sibling `labels.yml`. Each adapter
declares its capability set; consumer skills check capabilities before
using vendor-specific features.

**Active tracker** — the adapter selected at session start by reading
`.afk/config.yml`'s `tracker:` field, or by sniffing the working repo's
git remote. Default `linear` if absent. Missing adapter SKILL.md =
refuse and surface; no silent fallback.

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

**Acceptance criteria** — the testable bullets in an issue body that
runway / Claude Code reads as the spec for what to build. `/triage` makes
sure these exist and are sharp before transitioning the issue to `Todo`.

**Triage Notes** — the comment posted when an issue moves to `needs-info`.
Lists what's established and the specific facts the reporter needs to
provide before the issue can move forward.

**Out-of-scope KB** — `.out-of-scope/<concept>.md` files in the working
repo, written when a Feature/Improvement is rejected. Future triage runs
read these to surface "we already rejected this" matches.

## Canonical state machine

Vocabulary that consumer skills use unchanged across vendors. Adapters
translate to/from vendor-native names per `tracker-<provider>/labels.yml`,
with optional per-repo override at `.afk/tracker-labels.yml`.

**State labels**: `needs-triage`, `needs-info`, `needs-human`, `wontfix`.

**Category labels**: `Bug`, `Feature`, `Improvement`.

**Status values**: `triage`, `backlog`, `todo`, `in-progress`,
`in-review`, `done`, `canceled`, `duplicate`.

`Todo` is the runway pickup state — issues in `Todo` with sharp
acceptance criteria are what runway scans for. `needs-human` is the HITL
exit; the issue stays open but routes to a human PR rather than runway.
