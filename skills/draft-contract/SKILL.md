---
name: draft-contract
description: Lift a Linear issue into .goal-contract.draft.yml for the Valesco AFK pipeline. Use when the user says "draft a contract for VA-NNN", "goal contract for this ticket", "turn this Linear issue into a draft contract", or similar. Produces a structurally non-executable draft — authority fields emit as <PLANNER_SUGGESTED:> tokens per governance plan G8.
---

# /draft-contract

Author the first-pass `.goal-contract.draft.yml` for an AFK run, sourced from
a Linear issue. The draft is **intentionally non-executable**: every
authority-bearing field that cannot be mechanically derived is emitted as a
`<PLANNER_SUGGESTED: …>` token. A human replaces tokens, renames the file to
`.goal-contract.yml`, and only then is it eligible for pre-flight per G8.

## Inputs

- **Required:** a Linear issue identifier in `TEAM-NNN` form (e.g., `VA-142`).
  Passed as the skill argument or inferred from the conversation when the user
  pasted a Linear URL.
- **Optional:** a target directory. Defaults to the current working directory
  (repo root).

## Preconditions — check before writing anything

1. **Repo root check.** Target path must look like the root of a git
   repository. If `.git/` is absent and the user hasn't confirmed, ask.
2. **Hard-floor refusal.** If the target path would write to
   `.goal-contract.yml` (not `.draft.yml`), stop. Print:

   > Refusing to write `.goal-contract.yml` — that path is hard-floor per the
   > protected-paths manifest. Draft contracts must go to
   > `.goal-contract.draft.yml`. Rename manually after token replacement.

3. **Existing draft check.** If `.goal-contract.draft.yml` already exists,
   ask the user whether to overwrite or append a numbered suffix
   (`.goal-contract.draft.2.yml`).
4. **Linear MCP check.** The Linear MCP tool must be available. If not,
   print a single-line error and stop — do not fall back to asking the user
   to paste the issue body.

## Process

### Step 1 — fetch the Linear issue

Use the Linear MCP (`get_issue` by ID) to fetch:
- Title
- Description (markdown body)
- URL
- Status
- Labels
- Linked attachments / URLs

Fail loudly if the issue status is `Cancelled` or `Done` — drafts for
closed issues are almost certainly a mistake.

### Step 2 — extract intent

See [`authority-fields.md`](./authority-fields.md) for the full field list.
Short version:

| Contract field | Source in Linear issue |
|---|---|
| `intent.description` | First paragraph before any `##` header. Fallback: whole body truncated to ~500 chars. Minimum 20 chars per schema. |
| `intent.successCriteria` | Bullets under `## Acceptance`, `## Success criteria`, `## Test plan`. Lift each bullet as-is; strip trailing punctuation. |
| `intent.nonGoals` | Bullets under `## Non-goals`, `## Out of scope`. |
| `intent.anchors.docs[]` | URLs in the issue body that point at `.md`, `docs/`, ADR/PRD paths, or external doc hosts (Notion, Sanity, Obsidian). For each, compute a sha256 of the URL string itself as the `versionHash` placeholder — pre-flight will replace it with content hash. |
| `metadata.linearIssueId` | The TEAM-NNN identifier. |
| `metadata.created` | Current timestamp, ISO 8601. |

If a section source is **missing** from the Linear body, do not leave the
field empty — emit a `<PLANNER_SUGGESTED:>` token describing what's expected.
The skill must never silently drop an authority field.

### Step 3 — fill the template

Start from [`template.yml`](./template.yml). Apply tier-3 defaults (safest
initial posture per 2026-04-21 decision):

```yaml
metadata:
  tier: 3
budget:
  timeMinutes: 15
  maxRetries: 2
  maxCommits: 5
  perRunUsd: 0.50
  perContractUsd: 1.50
```

These are **defaults with suggestion intent** — annotate each with a
`# PLANNER_SUGGESTED` YAML comment so a human sees they were not derived.

### Step 4 — emit authority tokens

See [`authority-fields.md`](./authority-fields.md) for the full list and
token copy. Token format:

```yaml
writePaths:
  - "<PLANNER_SUGGESTED: propose globs under the target subsystem, e.g. src/components/**/*.tsx>"
```

Tokens must be **descriptive** — they guide the human replacement, not just
mark absence. Bad: `<PLANNER_SUGGESTED: TBD>`. Good:
`<PLANNER_SUGGESTED: propose the minimal globs under src/app/api/** this contract mutates>`.

### Step 5 — write the file

Write to `<target>/.goal-contract.draft.yml`. Use YAML literal-block scalars
(`|`) for any multi-line string. Preserve ordering from `template.yml`.

### Step 6 — print next steps

After writing, print a concise next-steps block:

```
Draft written: .goal-contract.draft.yml
Linked Linear: VA-NNN  ("<issue title>")

Next:
  1. Review + replace every <PLANNER_SUGGESTED: …> token.
  2. Verify tier assignment — default is 3. Raise to 2 (internal) or 1
     (prod/client) if the work touches customer data, billing, or migrations.
  3. For Tier 1: author the canaryPlan block (metrics, thresholds,
     rollbackTrigger, windowMinutes).
  4. Rename to .goal-contract.yml ONLY when every token is replaced.
  5. Open the scope PR with "Fixes VA-NNN" in the body.
  6. Wait for the delay window (15/30/60 min by tier + sensitivity).
  7. Apply the afk-ready label to trigger pre-flight.

Pre-flight will hard-reject the draft if any <PLANNER_SUGGESTED:> token
remains — this is the G8 structural gate. Intentional.
```

## Self-validation before returning

Before printing the next-steps block, verify:

- [ ] The written YAML parses.
- [ ] `metadata.linearIssueId` matches the pattern `^[A-Z]{2,6}-\d+$`.
- [ ] Every field listed in [`authority-fields.md`](./authority-fields.md) as
      "token-required when not derivable" is either a real value or contains
      the literal string `<PLANNER_SUGGESTED:`.
- [ ] The file path ends with `.goal-contract.draft.yml`, never
      `.goal-contract.yml`.

If any check fails, delete the file and report the specific failure. Do
not leave a malformed draft on disk.

## Non-goals

- **No auto-apply of `afk-ready`.** That is deliberate human work per G1.
- **No codebase inspection to infer `writePaths`.** Authority fields are
  human-authored per G8 — an agent guessing paths would violate the rule
  the skill exists to enforce.
- **No Linear status transitions.** Fetching is read-only.
- **No scope PR creation.** Separate operation; out of scope for this skill.

## References

- `valesco-platform/docs/afk/governance-plan.md` §G8 (planner → main handoff)
- `valesco-platform/docs/afk/intake.md` (full intake flow context)
- `valesco-platform/afk/schemas/goal-contract.v1.json` (draft must validate
  against this on schema-typed fields; token strings are accepted where the
  field type is string or string-array)
- `valesco-platform/afk/protected-paths/default.yml` (the hard-floor manifest)
