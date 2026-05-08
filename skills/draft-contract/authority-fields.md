# Authority-bearing fields

Reference for `/draft-contract`. Lists every field that carries execution
authority in a goal contract, classifies whether it can be mechanically
derived from a tracker issue, and provides the exact `<PLANNER_SUGGESTED:>`
token copy to emit when it can't.

Fields not listed here are either informational (e.g., `metadata.created`)
or computed by pre-flight / runtime (e.g., `metadata.contractHash`,
`metadata.validated`, `scope.metaContract`, `scope.sensitivePaths`,
`budget.costEstimateUsd`).

## Always derivable

These come directly from skill inputs. No tokens.

| Field | Source |
|---|---|
| `schemaVersion` | Constant `"2.1.0"` (was `"1.0.0"` pre-v2 — the v1→v2 rename also moved `metadata.linearIssueId` → `metadata.trackerIssueId`; v2.0.0→v2.1.0 added `metadata.bootstrap` and the bootstrap-mode anchors / canary relaxation) |
| `metadata.trackerIssueId` | Skill argument (Linear: `TEAM-NNN`; GitHub: `owner/repo#NNN`) |
| `metadata.created` | `new Date().toISOString()` at draft time |

## Derivable from tracker body, token on miss

Lift from the tracker issue. If the section is absent, emit the token
below — do **not** leave the field empty.

| Field | Tracker source | Token when missing |
|---|---|---|
| `intent.description` | Body before first `##` header, or whole body truncated to ~500 chars | `<PLANNER_SUGGESTED: describe the durable intent in 2-4 sentences; avoid file paths>` |
| `intent.successCriteria` | Bullets under `## Acceptance` / `## Success criteria` / `## Test plan` | `<PLANNER_SUGGESTED: list the observable conditions that mean this is done, one per bullet>` |
| `intent.nonGoals` | Bullets under `## Non-goals` / `## Out of scope` | Omit the field entirely if no source bullets; it is optional per schema |
| `intent.anchors.docs[]` | URLs in body pointing at `.md`, `docs/`, or external doc hosts (Notion, Sanity, Obsidian, tracker-native docs) | Empty array if none found; do not emit a token for absence |
| `terminationConditions` | Usually not stated in the issue body — emit token | `<PLANNER_SUGGESTED: list the conditions that end the run successfully, e.g. 'CI green', 'Validator pass', 'pnpm test passes'>` |

## Token-required when not derivable

Never mechanically derivable from a tracker issue. The skill always emits
the token; the human replaces it.

| Field | Token copy |
|---|---|
| `intent.anchors.interfaces[]` *(forbidden under bootstrap)* | `<PLANNER_SUGGESTED: list TypeScript interfaces or types the contract references; empty array if truly none>` |
| `intent.anchors.configShapes[]` *(forbidden under bootstrap)* | `<PLANNER_SUGGESTED: list config objects (e.g. OAuthConfig, SupabaseConfig) the contract depends on; empty array if none>` |
| `scope.requiredPaths[]` | `<PLANNER_SUGGESTED: globs the agent is expected to touch. Standard variant: each glob must match real files at pre-flight. For migration contracts, supabase/migrations/** goes here, NOT merely in writePaths. Bootstrap variant: each glob may resolve to zero files, OR only to entries in afk/protected-paths/bootstrap-allowlist.yml.>` |
| `scope.writePaths[]` | `<PLANNER_SUGGESTED: globs the agent may modify; must include all requiredPaths. Default hard-floor + escalated-floor paths are never writable via this field.>` |
| `metadata.customer` (Tier 1 only) | `<PLANNER_SUGGESTED: customer identifier, e.g. acme-corp>` |
| `canaryPlan.metrics[]` (Tier 1 only, optional under bootstrap) | `<PLANNER_SUGGESTED: metrics to watch post-merge, e.g. error_rate, p95_latency>` |
| `canaryPlan.rollbackTrigger` (Tier 1 only, optional under bootstrap) | `<PLANNER_SUGGESTED: command or Vercel action to execute on rollback>` |

## Bootstrap-mode authority field

Added at schemaVersion 2.1.0. Carries execution authority — flipping it
between draft and attestation invalidates approval via `contractHash`
(governance §G14). The skill never sets it silently; it asks the human
when the foundation-slice heuristic in [`SKILL.md`](./SKILL.md) Step 2.5
fires.

| Field | Default | Notes |
|---|---|---|
| `metadata.bootstrap` | `false` (key omitted) | Set to `true` ONLY when the contract's `requiredPaths` target files that do not yet exist on the resolved tree, OR resolve only to entries in `afk/protected-paths/bootstrap-allowlist.yml`. Re-attestation is required if this value changes. When `true`: omit `intent.anchors.interfaces` and `intent.anchors.configShapes` entirely; `canaryPlan` becomes optional even at Tier 1. |

## Defaults with suggestion intent

Not tokens — actual values, but annotated with `# PLANNER_SUGGESTED` YAML
comments so the human sees they were not derived from the Linear issue.

| Field | Default | Annotation |
|---|---|---|
| `metadata.tier` | `3` | `# PLANNER_SUGGESTED: default; raise to 2/1 per risk` |
| `scope.validator.policyId` | `"valesco-platform.v1"` | `# PLANNER_SUGGESTED: default; change only if a per-repo policy exists` |
| `scope.validator.policyVersion` | `"1.0.0"` | `# PLANNER_SUGGESTED: default; bump when the policy repo publishes a new version` |
| `budget.timeMinutes` | `15` | `# PLANNER_SUGGESTED: Tier 3 default; widen with evidence` |
| `budget.maxRetries` | `2` | `# PLANNER_SUGGESTED: Tier 3 default` |
| `budget.maxCommits` | `5` | `# PLANNER_SUGGESTED: Tier 3 default` |
| `budget.perRunUsd` | `0.50` | `# PLANNER_SUGGESTED: Tier 3 default per governance G6` |
| `budget.perContractUsd` | `1.50` | `# PLANNER_SUGGESTED: Tier 3 default per governance G6` |
| `canaryPlan.thresholds` (Tier 1 only) | `{ error_rate: 0.01, p95_latency_ms: 500 }` | Suggestion values; human tunes |
| `canaryPlan.windowMinutes` (Tier 1 only) | `15` | Per G10 default |

## Invariants

Regardless of source, the skill **must** ensure:

1. Every authority-bearing field either holds a real value or contains the
   literal string `<PLANNER_SUGGESTED:`. No nulls, no empty strings, no
   empty arrays unless the schema explicitly allows it.
2. `metadata.trackerIssueId` matches the active adapter's identifier
   format (Linear: `^[A-Z]{2,6}-\d+$`; GitHub: `^[\w.-]+/[\w.-]+#\d+$`).
3. The file path ends with `.goal-contract.draft.yml` — never
   `.goal-contract.yml`.
4. Default values carry the `# PLANNER_SUGGESTED` YAML comment so a human
   does not mistake them for derived values.
5. Under `metadata.bootstrap: true` the keys
   `intent.anchors.interfaces` and `intent.anchors.configShapes` are
   **absent** (not present-but-empty) — the v2.1.0 schema forbids them
   under bootstrap.
