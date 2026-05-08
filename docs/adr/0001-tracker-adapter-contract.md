# ADR-0001: Tracker adapter contract

- **Status**: Accepted (the contract survives the runway pivot — see
  Status section)
- **Date**: 2026-05-01
- **Deciders**: Jason Kennemer (Valesco) + Claude (design grill)
- **Format**: based on Matt Pocock's
  [ADR-FORMAT](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/ADR-FORMAT.md)

## Context

Flightplan's triage and diagnosis skills originally bound directly to
Linear via `mcp__plugin_productivity_linear__*` calls. About 70% of the
old `linear-triage/SKILL.md` was in fact vendor-agnostic Valesco doctrine
(the canonical state machine, comment shape, eligibility checks) — only
~10% was genuinely Linear-specific. The skill *felt* Linear-coupled
because the table of contents led with Linear MCP operations and used
Linear's status names.

Valesco wants:

1. To use the same triage and debugging machinery against GitHub Issues
   for projects that don't justify a Linear seat.
2. To eventually support Jira and local-markdown trackers without
   re-authoring core flightplan logic each time.
3. The "context layer" — issue body + comments + labels + status — to be
   a *modular component*, plug-replaceable per repo, while the canonical
   state machine and skill behavior stay shared across all adapters.

The forces:

- Three relevant providers already have first-class MCPs (Linear, GitHub,
  Atlassian); local markdown does not.
- We don't want consumer skills to know which vendor is in use — that
  defeats the modularity goal.

## Decision

Adopt a four-part contract:

### 1. Skill-per-provider adapter, not MCP-per-provider

Each adapter ships as `tracker-<provider>/SKILL.md` + `labels.yml`. The
SKILL.md documents which underlying MCP / CLI / file-op handles each
operation; consumer skills resolve the active adapter at session start
and follow its operations table.

### 2. Baseline-plus-capabilities operations contract

```
Floor (every adapter implements):
  fetch_issue(id)         → { body, status, labels, category, ... }
  list_comments(id)       → [{ author, body, ts }]
  post_comment(id, body)  → { id, ts }
  apply_labels(id, names) → ok
  set_status(id, name)    → ok

Optional capabilities (declared by the adapter):
  customer_field
  project_membership
  cycle_membership
  team_namespace
  active_work_detection: reliable | best-effort | none
```

Consumer skills query `adapter.capabilities` before using vendor-specific
features (active-work read-only checks, team-scoped queries).

### 3. Flightplan-canonical labels and statuses with three-layer resolution

Consumer skills speak only canonical names. Adapter ships defaults at
`tracker-<provider>/labels.yml`. Per-repo overrides land at
`.afk/tracker-labels.yml` if needed. Non-canonical tracker labels
(GitHub's `help wanted`, etc.) are preserved on read and untouched on
write.

### 4. Discovery via existing `.afk/config.yml`

```yaml
tracker: linear            # default if absent
trackerLabelsPath: .afk/tracker-labels.yml   # optional
```

No auto-detection, no fallback chain. Missing adapter = refuse and
surface.

## Consequences

### Easier

- Adding a new tracker is one new `tracker-<provider>/` directory; no
  consumer-skill edits required.
- The same `triage` and `diagnose` skills work against any supported
  vendor.
- Future skills can reuse the adapter contract for free.
- Capability-gated logic means low-richness vendors degrade gracefully
  rather than failing opaquely.

### Harder

- Consumer skills must maintain capability-check discipline at every
  vendor-specific use site. Easy to forget.
- Adapter authors must implement the floor exactly; partial floors
  silently break consumer skills.
- The label-mapping layer is a small but real surface to keep correct
  per vendor.

### Trade-offs vs alternatives

- **MCP-per-provider** (rejected): typed contract is more reliable, but
  authoring an MCP is heavyweight, the top three vendors already have
  MCPs we don't own, and local markdown can't reasonably get one.
  Skill-per-provider gets ~90% of the reliability for ~20% of the cost.
- **One skill with internal branches** (rejected): defeats reuse —
  every consumer skill ends up with the same provider-conditional
  logic.
- **Matt Pocock's freeform-prose `setup-matt-pocock-skills` pattern**
  (kept as fallback only): the LLM has to inline-translate "we use Jira"
  into Jira-specific calls; no real seam. Useful as the soft fallback
  when no adapter SKILL.md exists, not as the primary mechanism.

## Status

Accepted. Survives the runway pivot of 2026-05-08, which removed the
AFK-pipeline-specific consumer skills (`/draft-contract`, `/attest`,
`/brief-to-contract`, `/run-attested`). The remaining consumers
(`/triage`, `/diagnose`) still use the adapter contract unchanged.

The ADR was originally written when this repo's consumer chain ended in
an AFK pre-flight + attestation gate; that chain has been retired and
replaced by [runway](https://github.com/ValescoAgency/runway), which
reads issues directly from the tracker. The adapter contract didn't
need to change — it was always tracker-shaped, never AFK-shaped.

The historical "Phase B blocker" referenced in earlier revisions
(GitHub-shaped issue IDs failing a Linear-tuned schema regex in
`valesco-platform`) is no longer relevant — that schema lived in the
retired AFK pipeline.

## References

- [`/Users/jkennemer/Developer/flightplan/CONTEXT.md`](../../CONTEXT.md)
  — ubiquitous language including all terms used here.
- [Matt Pocock's `/setup-matt-pocock-skills`](https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/SKILL.md)
  — the fallback pattern this contract supersedes for Valesco repos.
