---
name: tracker-github
description: GitHub Issues adapter for flightplan's tracker contract. Implements the canonical operations API (`fetch_issue`, `list_comments`, `post_comment`, `apply_labels`, `set_status`) using the `gh` CLI (or the GitHub MCP if loaded). Loaded by consumer skills (`/triage`, `/draft-contract`, `/brief-to-contract`, `/diagnose`) when `.afk/config.yml` declares `tracker: github`. Not invoked directly by users — this is the adapter the rest of flightplan reads from. Suitable for low-priority projects that don't justify a Linear seat; the full AFK chain through `/draft-contract` is blocked on Phase B schema migration in `valesco-platform`, but `/triage` works end-to-end against GitHub today.
disable-model-invocation: true
---

# tracker-github — GitHub Issues adapter

Implements the [tracker adapter contract](../docs/adr/0001-tracker-adapter-contract.md)
for [GitHub Issues](https://docs.github.com/en/issues). Consumer skills
load this adapter when `.afk/config.yml` declares `tracker: github`.

GitHub operations go through the [`gh` CLI](https://cli.github.com/) by
default. If the [GitHub MCP](https://github.com/github/github-mcp-server)
is loaded in the session (`mcp__plugin_engineering_github__*`), prefer
its typed calls — they're faster and better-typed than `gh` for bulk
queries. Use `gh` as the universal floor.

## Phase B blocker — read this first

Until `valesco-platform`'s schema v2 migration lands, the full AFK
chain through `/draft-contract` and `/attest` will reject GitHub issue
IDs at schema validation. The contract field `metadata.linearIssueId`
has regex `^[A-Z]{2,6}-\d+$` — GitHub's `owner/repo#NNN` doesn't
match.

What works today against GitHub:

- `/triage` end-to-end (label/status transitions, Agent Brief
  comments, OOS knowledge base, the full triage funnel)
- `/diagnose` end-to-end (no schema dependencies)
- `/feedback-loop` (no tracker dependencies)

What does **not** work until Phase B lands:

- `/draft-contract` (rejects the GitHub-shaped ID at schema validation)
- `/attest` (depends on the contract being valid)
- `/brief-to-contract` (orchestrates the above; will halt at the draft
  step)

The constraint is intentional and registered in
[`docs/refactor-plan.md`](../docs/refactor-plan.md). Phase A1 (rename
+ adapter contract) and Phase A2 (this adapter) ship independently of
Phase B; the GitHub AFK chain becomes complete only when Phase B does.

## Capability declaration

```yaml
capabilities:
  customer_field: false              # GH issues have no customer concept
  project_membership: false          # GH Projects v2 exists but requires
                                     # GraphQL; treat as out-of-scope here.
                                     # Per-repo override may flip this true
                                     # if the repo standardizes on Projects v2.
  cycle_membership: false            # GH milestones are coarser, not equivalent
  team_namespace: false              # GH is org-scoped; no first-class team concept
  active_work_detection: best-effort # open + linked PR + assignee, heuristic only
```

Consumer-skill consequences:

- `/triage` will not recommend Tier 1 from GitHub-issue inputs
  (`customer_field: false`). Tier 1 escalation in `/brief-to-contract`
  must come from `.afk/config.yml`'s `projectTier: 1` explicitly.
- `/triage`'s read-only-on-active-work protection **warns instead of
  refusing** when about to mutate an issue that *might* be in active
  work — there's no reliable signal, only heuristics.
- Project-scoped or cycle-scoped queue views in `/triage` are
  unavailable.

## ID format

GitHub issue references take any of these forms:

- `<num>` — e.g., `42`. Implicit repo, derived from
  `git remote get-url origin` (must be a `github.com` remote).
- `#<num>` — e.g., `#42`. Same as above.
- `<owner>/<repo>#<num>` — e.g., `ValescoAgency/flightplan#42`.
  Explicit. Use this form when posting cross-repo references.

The adapter normalizes incoming references to canonical
`<owner>/<repo>#<num>` form for all subsequent operations. If repo
inference fails (no GitHub remote, ambiguous remote), surface the
failure rather than guessing.

## Operations table

The contract floor every adapter must implement.

| Canonical operation | `gh` CLI | Notes |
|---|---|---|
| `fetch_issue(id)` | `gh issue view <num> --repo <owner/repo> --json number,title,body,state,stateReason,labels,assignees,milestone,projectItems,createdAt,updatedAt,closedAt,url` | Map to canonical shape: status from `state` + `stateReason` + state-encoding labels (see [Status mapping](#status-mapping)); category + state labels via [`labels.yml`](./labels.yml); preserve unknown labels as `extra_labels`. |
| `list_comments(id)` | `gh issue view <num> --repo <owner/repo> --json comments` | Return each comment with `author.login`, `body`, ISO `createdAt`. |
| `post_comment(id, body)` | `gh issue comment <num> --repo <owner/repo> --body-file -` (pipe body in) | Markdown is supported. Body is passed verbatim — disclaimer is the consumer's responsibility. |
| `apply_labels(id, names)` | `gh issue edit <num> --repo <owner/repo> --add-label <name1> [--add-label <nameN>]` | Resolve canonical names → GitHub label strings via [`labels.yml`](./labels.yml). For removals (e.g., when transitioning state), use `--remove-label`. |
| `set_status(id, name)` | composite — see [Status mapping](#status-mapping) | GitHub has no status enum; encode via state + state-encoding label. |

Optional operations:

| Canonical operation | Implementation | Capability flag |
|---|---|---|
| `is_active_work(id)` | Best-effort: returns true if issue is open AND (has linked PR via `gh issue view --json closingIssuesReferences,timelineItems` OR has at least one assignee). | `active_work_detection: best-effort` |
| `list_repo_issues(state, labels, ...)` | `gh issue list --repo <owner/repo> --state <s> --label <l> --json ...` | (always available — no capability flag) |

## Status mapping

GitHub doesn't have a native status enum. The adapter encodes the
canonical state machine using `state` + `stateReason` + a single
**state-encoding label** (mutually exclusive with other state-encoding
labels).

State-encoding labels are: `triage`, `backlog`, `todo`, `in-progress`,
`in-review`, `reviewed`. Read these via `labels.yml` so per-repo
overrides apply.

| Canonical | GitHub `state` | `stateReason` | State-encoding label |
|---|---|---|---|
| `triage` | `OPEN` | — | `triage` |
| `backlog` | `OPEN` | — | `backlog` |
| `todo` | `OPEN` | — | `todo` |
| `in-progress` | `OPEN` | — | `in-progress` |
| `in-review` | `OPEN` | — | `in-review` |
| `reviewed` | `OPEN` | — | `reviewed` |
| `done` | `CLOSED` | `COMPLETED` | (none) |
| `canceled` | `CLOSED` | `NOT_PLANNED` | (none) |
| `duplicate` | `CLOSED` | `DUPLICATE` | (none) |

`set_status` semantics:

- For an OPEN canonical status: ensure issue is open (`gh issue
  reopen` if currently closed), apply the new state-encoding label,
  remove any other state-encoding labels.
- For a CLOSED canonical status: `gh issue close --reason
  <state_reason>` (the `gh` flag accepts `completed`, `not planned`,
  or `duplicate`). State-encoding labels are not stripped on close —
  they record the last open status, which is fine.
- `duplicate`: GitHub supports `--reason "duplicate"`. When
  transitioning to duplicate, the consumer skill should also post a
  comment linking the canonical issue *before* calling `set_status`.

`fetch_issue` reverse mapping:

- If `state == OPEN`, find the first state-encoding label present
  (priority: `in-review`, `reviewed`, `in-progress`, `todo`, `backlog`,
  `triage`). If none, default to `triage`.
- If `state == CLOSED`, map `stateReason` → canonical: `COMPLETED`
  → `done`, `NOT_PLANNED` → `canceled`, `DUPLICATE` → `duplicate`.
  Treat unknown / null `stateReason` as `done`.

## Active-work detection (best-effort)

GitHub provides no first-class signal for "this is being actively
worked on." The adapter offers a heuristic:

```
is_active_work(id) → true if ALL:
  - state == OPEN
  - (has linked PR via timelineItems[].source resolving to a PR
     that's not yet closed/merged)
    OR
    (has at least one assignee)
```

This is **best-effort** — it will miss a contributor who's working in
a fork without a draft PR yet, and it will false-positive on stale
assignees. `/triage`'s read-only protection treats `best-effort` as
"warn, don't refuse" — the maintainer makes the call.

For repos that standardize on GitHub Projects v2, a per-repo override
in `.afk/tracker-labels.yml` can declare a richer detection rule
(e.g., "active means Projects v2 status field is `In Progress`").
Out of scope for this adapter; treat Projects v2 as orthogonal.

## Label mapping

See [`labels.yml`](./labels.yml). GitHub repos commonly use lowercase
labels (`bug`, `enhancement`, `documentation`) where canonical uses
capitalized categories (`Bug`, `Feature`, `Improvement`). Per-repo
overrides via `.afk/tracker-labels.yml` follow the three-layer
resolution rule from [ADR-0001](../docs/adr/0001-tracker-adapter-contract.md).

**Non-canonical labels** (e.g., `good first issue`, `help wanted`,
`priority:high`) are **preserved on read** as `extra_labels` and
**untouched on write**. The adapter never strips a community's
labeling convention.

## Required `gh` setup

The adapter assumes:

- `gh` CLI is installed (`gh --version` works).
- The user is authenticated (`gh auth status` shows logged-in for
  github.com).
- The active repo's remote is reachable (`gh repo view` succeeds).
- The user has write access to the repo if mutating operations
  (`apply_labels`, `set_status`, `post_comment`) will be called.

If any precondition fails, refuse and surface the failure. Don't fall
back silently to read-only mode.

## `gh` CLI cheatsheet

| Need | Command |
|---|---|
| One issue (full) | `gh issue view <num> --repo <r> --json number,title,body,state,stateReason,labels,assignees,milestone,createdAt,updatedAt,closedAt,url` |
| One issue (with comments + timeline) | `gh issue view <num> --repo <r> --json ...,comments,timelineItems` |
| List repo issues | `gh issue list --repo <r> --state <open\|closed\|all> --label <l> --limit <n>` |
| Comment | `gh issue comment <num> --repo <r> --body-file -` (then pipe body) |
| Add labels | `gh issue edit <num> --repo <r> --add-label <a> --add-label <b>` |
| Remove labels | `gh issue edit <num> --repo <r> --remove-label <a>` |
| Close (done) | `gh issue close <num> --repo <r> --reason completed` |
| Close (canceled) | `gh issue close <num> --repo <r> --reason "not planned"` |
| Close (duplicate) | `gh issue close <num> --repo <r> --reason duplicate` |
| Reopen | `gh issue reopen <num> --repo <r>` |
| List repo labels | `gh label list --repo <r>` |

When in doubt about a flag, run `gh issue --help` or
`gh issue <subcommand> --help` rather than guessing.

## Self-validation checks

The adapter guarantees these to consumer skills. If a downstream skill
catches a violation, file a bug against this adapter.

- `fetch_issue` returns canonical status names (mapped through the
  table above), never raw `OPEN`/`CLOSED` strings.
- `list_comments` returns timestamps as ISO 8601, regardless of `gh`'s
  output shape (`gh` does ISO 8601 already, but the adapter normalizes
  on the off chance the format changes).
- `apply_labels` only modifies labels that map to canonical names plus
  the state-encoding labels enumerated in the status mapping table.
  Non-canonical labels are preserved on read and untouched on write.
- `set_status("triage")` always lands the issue in OPEN state with
  the `triage` state-encoding label, never just labels alone (state
  must be coherent).
- ID format normalization always returns `<owner>/<repo>#<num>` form
  before performing operations, even if the input was bare `<num>`.

## What this adapter does NOT do

- **No goal-contract knowledge.** The schema field
  `metadata.linearIssueId` (its name unchanged in this rollout)
  belongs to consumer skills and to `valesco-platform`'s schemas.
  This adapter just provides the issue ID; the GitHub-shaped ID will
  fail the existing regex until Phase B.
- **No tier inference from GitHub metadata.** Tier comes from
  `.afk/config.yml`. (`projectTier: 1` repos using GitHub will
  trigger Tier 1 even though GitHub has no `customer_field` —
  `/brief-to-contract` will surface that the customer must come from
  another source, e.g., the `.afk/config.yml` declaration.)
- **No AFK-eligibility decisions.** Eligibility is consumer-side.
- **No PR creation or branch operations.** This adapter only touches
  Issues. Pull-request work is out of scope.
- **No GitHub Projects v2 integration.** Treat as orthogonal; revisit
  if a Valesco repo standardizes on it.
- **No GitLab support.** That's a separate adapter (`tracker-gitlab`,
  not currently planned).

## References

- [`../docs/adr/0001-tracker-adapter-contract.md`](../docs/adr/0001-tracker-adapter-contract.md)
  — the design decision this adapter implements.
- [`../docs/refactor-plan.md`](../docs/refactor-plan.md) — Phase A2
  scope (this adapter); Phase B (schema migration that unblocks the
  full chain).
- [`./labels.yml`](./labels.yml) — label mapping for GitHub.
- [`../tracker-linear/SKILL.md`](../tracker-linear/SKILL.md) — sibling
  adapter (full-capability reference implementation).
- [`../CONTEXT.md`](../CONTEXT.md) — canonical state machine and
  capability set.
- [`gh` CLI manual](https://cli.github.com/manual/) — for any
  operation the cheatsheet doesn't cover.
- [GitHub Issues REST API](https://docs.github.com/en/rest/issues)
  and [GraphQL API](https://docs.github.com/en/graphql) — underlying
  surfaces; rarely needed directly when `gh` covers the operation.
