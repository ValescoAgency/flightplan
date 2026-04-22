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

### `intent-matches-linear`

**Applies:** all tiers.

> I have re-read the referenced Linear issue within the last 15
> minutes. The contract's `intent.description`, `successCriteria`, and
> `nonGoals` still reflect the issue's current wording — no silent
> drift between Linear and the YAML.

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

**Applies:** all tiers.

> At least the required delay has elapsed between the contract's
> initial draft write and now:
>
> | tier | default | sensitive paths | meta-contract |
> |---|---|---|---|
> | 1 | 15 min | 30 min | 60 min |
> | 2 | 5 min | 15 min | 30 min |
> | 3 | 0 min | 5 min | 15 min |
>
> Sensitive paths: auth, `supabase/migrations/**`, billing, any path
> flagged "production-critical" in repo metadata.

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

**Applies:** `metadata.tier === 1`.

> `canaryPlan.metrics`, `canaryPlan.thresholds`, and
> `canaryPlan.rollbackTrigger` are concrete and executable. Thresholds
> are calibrated to the actual deployment's normal-range baseline,
> not round-number guesses. `rollbackTrigger` is a real command or
> Vercel action, not a TBD placeholder.

---

## Tier 3 only

### `tier-3-not-expired`

**Applies:** `metadata.tier === 3`.

> `.afk/config.yml` has a `tier_expires` date and that date has not
> yet passed. Tier 3 projects auto-fail pre-flight after expiration
> until renewed by a Tier-2+ ceremony.

---

## Conditional on contract content

### `incident-override-rationale`

**Applies:** `metadata.incidentOverride` present.

> `metadata.incidentOverride.linearIssueRef` points at a real
> incident issue, and `metadata.incidentOverride.rationale` is a
> genuine description of the urgency — not a workaround for impatience
> with the normal delay window. I understand this counts as an
> `urgent_business_need` override against the override budget.

---

## Deprecated / removed items

When an item is retired, it moves here with a removal date and the
ticket that retired it. Never delete the id history — past records
still reference the old ids.

_(none yet)_
