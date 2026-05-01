---
name: tracker-linear
description: Linear adapter for flightplan's tracker contract. Implements the canonical operations API (`fetch_issue`, `list_comments`, `post_comment`, `apply_labels`, `set_status`) by delegating to the Linear MCP. Loaded by consumer skills (`/triage`, `/draft-contract`, `/brief-to-contract`, `/diagnose`) when `.afk/config.yml` declares `tracker: linear` (the default). Not invoked directly by users — this is the adapter the rest of flightplan reads from.
disable-model-invocation: true
---

# tracker-linear — Linear adapter

Implements the [tracker adapter contract](../docs/adr/0001-tracker-adapter-contract.md)
for [Linear](https://linear.app). Consumer skills load this adapter when
`.afk/config.yml` declares `tracker: linear` (or omits the field — that
defaults to `linear`).

All Linear operations go through the
[`mcp__plugin_productivity_linear__*`](https://github.com/linear/linear-mcp)
toolset. Never use `gh` or other tracker CLIs from this adapter.

## Capability declaration

```yaml
capabilities:
  customer_field: true              # Linear has first-class customer
  project_membership: true          # Linear projects
  cycle_membership: true            # Linear cycles
  team_namespace: true              # Linear teams (VA, MREG, FMF, ...)
  active_work_detection: reliable   # native In Progress / In Review statuses
```

Consumer skills query these flags before using vendor-specific features.

## Operations table

The contract floor every adapter must implement. Inputs and outputs are
the canonical shapes consumer skills expect.

| Canonical operation | Linear MCP call | Notes |
|---|---|---|
| `fetch_issue(id)` | `get_issue(id)` | `id` accepts `VA-87` style. Returns body, status, labels, project, dates. |
| `list_comments(id)` | `list_comments(issue: id)` | Returns each comment with author + ISO timestamp. |
| `post_comment(id, body)` | `save_comment(issue: id, body: <body>)` | Body is markdown. Always passes through verbatim — disclaimer is the consumer's responsibility. |
| `apply_labels(id, names)` | `save_issue(issue: id, labelIds: [...])` | Resolve canonical names → label IDs via `list_issue_labels(team)`. Cache within session. |
| `set_status(id, name)` | `save_issue(issue: id, stateId: <id>)` | Resolve canonical status → Linear `stateId` via `list_issue_statuses(team)`. See [status mapping](#status-mapping) below. |

Optional operations (consumer skills must check capability first):

| Canonical operation | Linear MCP call | Capability flag |
|---|---|---|
| `get_customer(id)` | `get_issue(id)` → `.customer` | `customer_field` |
| `list_team_issues(team, ...)` | `list_issues({team, ...})` | `team_namespace` |
| `list_project_issues(project, ...)` | `list_issues({project, ...})` | `project_membership` |
| `list_cycle_issues(cycle, ...)` | `list_issues({cycle, ...})` | `cycle_membership` |
| `is_active_work(id)` | inspect `get_issue(id).status` against the In Progress / In Review / Reviewed set | `active_work_detection: reliable` |

## Status mapping

Canonical → Linear-native. Resolve the right side to a `stateId` for the
issue's team via `list_issue_statuses(team)`; cache per session.

| Canonical (consumer-facing) | Linear status (UI / API) | Linear `type` |
|---|---|---|
| `triage` | `Triage` | `triage` |
| `backlog` | `Backlog` | `backlog` |
| `todo` | `Todo` | `unstarted` |
| `in-progress` | `In Progress` | `started` |
| `in-review` | `In Review` | `started` |
| `reviewed` | `Reviewed` | `started` |
| `done` | `Done` | `completed` |
| `canceled` | `Canceled` | `canceled` |
| `duplicate` | `Duplicate` | `canceled` |

Active-work detection: any status whose `type` is `started` is treated
as active work. `is_active_work(id)` returns `true` for `In Progress`,
`In Review`, `Reviewed`.

## Label mapping

See [`labels.yml`](./labels.yml) — Valesco repos use canonical names
directly in Linear, so the file is essentially the identity mapping.
Per-repo override goes in `.afk/tracker-labels.yml` if a repo has
nonstandard label strings.

## Valesco workspace teams

| Team key | Team name | Typical repos |
|---|---|---|
| `VA` | Valescoagency | `valesco-platform` (afkEligible: false), `flightplan`, `ffl-live-draft`, `styled-by-kb`, etc. |
| `MREG` | Mill Real Estate Group | `millsreg-sanity` |
| `FMF` | FMF-Website | `fmf-website` |

Infer the team from `git remote get-url origin` when possible. If
unknown, ask once and cache for the session.

The maintainer is **Jason Kennemer**
(`jason@valescoagency.com`). Other Linear users (`cursor`, `linear`)
are bots — never assign to them, never @-mention them in briefs.

## ID format

Linear issue IDs are `<TEAM>-<N>` — e.g., `VA-87`, `MREG-12`.
The pattern `^[A-Z]{2,6}-\d+$` matches.

This format is also the value `draft-contract` writes into
`metadata.linearIssueId` and the value `attest` uses as the filename
for `.afk/attestations/<linearIssueId>.json`. The schema field name
`linearIssueId` is unchanged in this rollout — it will be renamed to
`trackerIssueId` only when the Phase B v2 schema migration in
`valesco-platform` lands. Until then, this adapter populates that field
with Linear's native ID format and the GitHub adapter (when authored)
will not be able to drive the full chain past `/draft-contract`.

## Linear MCP cheatsheet

When implementing an operation, prefer the Linear MCP
`search_documentation` tool over guessing. Common entry points:

- **Teams:** `list_teams()`
- **Statuses for a team:** `list_issue_statuses(team)`
- **Labels:** `list_issue_labels(team?)` — workspace-wide if `team` omitted
- **Issues:** `list_issues({team, status, label, project, ...})`
- **One issue:** `get_issue(<id-or-key>)` (accepts `VA-87` style)
- **Comments:** `list_comments(issue)` / `save_comment(issue, body)`
- **Update:** `save_issue(issue, {...})`

## Self-validation checks

Consumer skills should NOT need to implement these — the adapter
guarantees them. If a downstream skill catches a violation, file a bug
against this adapter.

- `fetch_issue` returns canonical status names (mapped through the
  table above), never raw Linear strings.
- `list_comments` returns timestamps as ISO 8601, regardless of how
  Linear surfaces them.
- `apply_labels` only modifies labels that map to canonical names.
  Non-canonical labels (e.g., team-specific decoration like
  `priority-high`) are preserved on read and untouched on write.
- `set_status("triage")` always lands the issue in the team's `Triage`
  state, never the team's `Backlog` (which is a separate canonical
  status).

## What this adapter does NOT do

- **No goal-contract knowledge.** Schema field names like
  `linearIssueId` belong to consumer skills (and to
  `valesco-platform`'s schemas). The adapter just provides the issue
  ID; the consumer wraps it in whatever schema field is appropriate.
- **No tier inference.** Tier is read from `.afk/config.yml`, not
  computed from Linear project metadata.
- **No AFK-eligibility decisions.** Eligibility is a Valesco-doctrine
  concern, owned by the consumer skill (`/triage`).
- **No PR / commit creation.** Linear has issue→PR linking; this
  adapter doesn't touch GitHub.
- **No Linear-native features beyond the contract.** Linear has rich
  things (sub-issues, project updates, customer requests). The adapter
  exposes only what the canonical operations need; consumer skills
  don't get to use Linear-specific richness through this surface.

## References

- [`../docs/adr/0001-tracker-adapter-contract.md`](../docs/adr/0001-tracker-adapter-contract.md)
  — the design decision this adapter implements.
- [`./labels.yml`](./labels.yml) — label mapping (identity for Valesco).
- [`../CONTEXT.md`](../CONTEXT.md) — canonical state machine and
  capability set.
- [Linear MCP](https://github.com/linear/linear-mcp) — underlying
  MCP server.
