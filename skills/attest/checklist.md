# Attestation checklist

Reference for `/attest`. One item per bullet. Each item has:

- **id** — stable kebab-case identifier (recorded in the attestation
  record; never rename, only add/deprecate).
- **label** — human-readable prompt rendered to the attester (stored
  verbatim in the record so future copy-edits don't rewrite history).
- **applies** — which tiers the item renders for.

Rendering order is the order below. The skill MAY skip rendering an
item whose `applies` clause excludes the current tier / condition, but
MUST NOT reorder within what it does render.

---

## All tiers

### `intent-matches-tracker`

**Applies:** all tiers.

> I have re-read the referenced tracker issue within the last 15
> minutes. The contract's `intent.description`, `successCriteria`, and
> `nonGoals` still reflect the issue's current wording — no silent
> drift between the tracker and the YAML.

*(id renamed from `intent-matches-linear` at schemaVersion 2.0.0 when
`metadata.linearIssueId` became `metadata.trackerIssueId`. Pre-2.0.0
records still carry the old id; never reuse it for new items.)*

### `paths-are-minimal`

**Applies:** all tiers.

> `scope.requiredPaths` and `scope.writePaths` are the minimum set
> required to satisfy the contract. I have not included a broad glob
> (e.g., `src/**`) when a narrower one (e.g., `src/components/foo/**`)
> would work.

### `no-hard-floor-in-writepaths`

**Applies:** all tiers.

> No hard-floor path appears in `scope.writePaths`. Hard-floor paths
> are: `.github/workflows/**`, `.github/actions/**`,
> `.github/CODEOWNERS`, `.github/dependabot.yml`, `vercel.json`,
> `.vercelignore`, `.goal-contract.yml`, `.afk/**`,
> `afk/policies/**`, `docs/prd/**`, `.env*` (except `.env.example`).
>
> Escalated-floor paths (`supabase/migrations/**`,
> `supabase/config.toml`, `package.json`, `pnpm-lock.yaml`,
> `tsconfig*.json`, `next.config.*`, `middleware.ts`,
> `src/middleware.ts`) may appear but require a meta-contract — skip
> this item with a rationale if that's the case.

### `cost-estimate-acknowledged`

**Applies:** all tiers.

> I have reviewed the pre-flight cost estimate (or acknowledged that
> pre-flight has not yet been run and the tier's default per-contract
> budget will apply).

### `time-delay-elapsed`

**Applies:** all tiers. Matrix branches on `metadata.bootstrap` per
governance §G14 (foundation slices have no production-traffic risk to
amortize across a delay window — VA-329 implements the matrix override
in the label handler).

> At least the required delay has elapsed between the contract's
> initial draft write and now.
>
> **Standard contracts** (`metadata.bootstrap !== true`):
>
> | tier | default | sensitive paths | meta-contract |
> |---|---|---|---|
> | 1 | 15 min | 30 min | 60 min |
> | 2 | 5 min | 15 min | 30 min |
> | 3 | 0 min | 5 min | 15 min |
>
> **Bootstrap contracts** (`metadata.bootstrap === true`):
>
> | tier | default | sensitive paths | meta-contract |
> |---|---|---|---|
> | 1 | 5 min | 15 min | 30 min |
> | 2 | 0 min | 5 min | 15 min |
> | 3 | 0 min | 0 min | 5 min |
>
> Sensitive paths: auth, `supabase/migrations/**`, billing, any path
> flagged "production-critical" in repo metadata. Under bootstrap, paths
> in `afk/protected-paths/bootstrap-allowlist.yml` are not treated as
> sensitive even if they overlap (the allowlist is the deliberate
> override).

### `adversarial-review-considered`

**Applies:** all tiers.

> I have considered the adversarial review outcome (or noted it as
> pending / not-run, captured separately in
> `adversarialReviewStatus`). No `escalate_human` or `fail` verdict
> is being ignored.

---

## Tier 1 only

### `customer-identifier-correct`

**Applies:** `metadata.tier === 1`.

> `metadata.customer` matches the customer this work is actually for.
> A wrong customer field wrecks per-customer cost attribution and
> retention policy.

### `canary-plan-sensible`

**Applies:** `metadata.tier === 1 && metadata.bootstrap !== true`.

> `canaryPlan.metrics`, `canaryPlan.thresholds`, and
> `canaryPlan.rollbackTrigger` are concrete and executable. Thresholds
> are calibrated to the actual deployment's normal-range baseline,
> not round-number guesses. `rollbackTrigger` is a real command or
> Vercel action, not a TBD placeholder.

*(Skipped under `metadata.bootstrap === true`: foundation slices have no
live deployment to canary against; the v2.1.0 schema relaxes
`canaryPlan` to optional even at Tier 1 in that case — governance §G14.)*

---

## Tier 3 only

### `tier-3-not-expired`

**Applies:** `metadata.tier === 3`.

> `.afk/config.yml` has a `tier_expires` date and that date has not
> yet passed. Tier 3 projects auto-fail pre-flight after expiration
> until renewed by a Tier-2+ ceremony.

---

## Conditional on contract content

### `bootstrap-claim-self-verifying`

**Applies:** `metadata.bootstrap === true`.

> Every glob in `scope.requiredPaths` either resolves to **zero files**
> on the current `main` branch, OR resolves only to paths listed in
> `afk/protected-paths/bootstrap-allowlist.yml`. No glob secretly
> overlaps a pre-existing file outside the allowlist.
>
> I have eyeballed the resolved tree (e.g. via `git ls-files` against
> the globs) and confirmed this — I am not relying on the heuristic
> alone. Pre-flight will re-check this mechanically (per VA-327), but
> the claim is mine.
>
> I also confirm `metadata.bootstrap: true` is the right shape: this
> contract creates files that do not yet exist, not edits to a
> populated codebase. If this is a "standard" contract that happens to
> touch new files alongside existing ones, the value should be `false`
> and `intent.anchors.interfaces` / `configShapes` should be populated
> instead.

### `incident-override-rationale`

**Applies:** `metadata.incidentOverride` present.

> `metadata.incidentOverride.trackerIssueRef` points at a real
> incident issue, and `metadata.incidentOverride.rationale` is a
> genuine description of the urgency — not a workaround for impatience
> with the normal delay window. I understand this counts as an
> `urgent_business_need` override against the override budget.
>
> *(Field renamed from `linearIssueRef` to `trackerIssueRef` at
> schemaVersion 2.0.0.)*

---

## Deprecated / removed items

When an item is retired, it moves here with a removal date and the
ticket that retired it. Never delete the id history — past records
still reference the old ids.

- `intent-matches-linear` — renamed to `intent-matches-tracker` on
  2026-05-07 ([VA-331](https://linear.app/valescoagency/issue/VA-331))
  when the v1→v2 schema rename moved `metadata.linearIssueId` to
  `metadata.trackerIssueId`. Pre-2026-05-07 attestation records still
  reference the old id and remain valid.
