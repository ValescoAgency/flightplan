---
name: run-attested
description: Manually invoke @valesco/afk-runner against an already-attested goal-contract for end-to-end dogfood testing. Use when the user says "run-attested for VA-NNN", "test the AFK runner against this contract", "spike a runner pass on this attested contract", or similar. v1 dogfood-only — production runs go through the central label handler in v2 ([VA-291](https://linear.app/valescoagency/issue/VA-291)). Never applies labels, never promotes branches, never re-attests.
---

# /run-attested

Manual entry point for the AFK runner. Lets a human kick off an attested
goal-contract end-to-end on Docker before the central label handler is
wired up. The skill validates preconditions, hands off to
`@valesco/afk-runner`, and tails the audit stream — surfacing the result
back to the human, who decides what happens next.

## When to run

After:

1. `.goal-contract.yml` exists at repo root with all
   `<PLANNER_SUGGESTED:>` tokens replaced.
2. [`/attest`](../attest/SKILL.md) has been run successfully — there is a
   matching `.afk/attestations/<id>.json` record on disk.
3. Docker Desktop is running locally.
4. AFK signing key is set up per
   [`afk/runner/docs/signing-key-setup.md`](https://github.com/ValescoAgency/valesco-platform/blob/main/afk/runner/docs/signing-key-setup.md)
   in `valesco-platform`.

**Before:** the central label handler ([VA-291](https://linear.app/valescoagency/issue/VA-291))
is shipped. Once that lands, runs are triggered by the human applying
the `afk-ready` label — this skill becomes a dev-only tool.

## Hard refusals

`/run-attested` never:

- Applies `afk-ready` or `ready-for-agent` (skill/pipeline boundary).
- Replaces `<PLANNER_SUGGESTED:>` tokens (§G8 — that's `/draft-contract`'s
  human-step territory).
- Writes new attestation records (§G1 — that's `/attest`'s territory).
- Promotes a branch (no `gh pr create`, no merges, no force-push).
- Continues if any of the preconditions below fail. No partial runs.

## Preconditions — check before invoking the runner

Run all six checks in order. Refuse and surface the specific failure;
do not paper over.

### 1. `.goal-contract.yml` exists

If absent:

> Refusing to run. `.goal-contract.yml` not found at repo root. If you
> have `.goal-contract.draft.yml`, run `/draft-contract` follow-up steps
> first to replace `<PLANNER_SUGGESTED:>` tokens and rename. If the
> contract was attested elsewhere, this is the wrong working directory.

### 2. Attestation record exists

Resolve the issue ID from `metadata.trackerIssueId` (renamed from
`metadata.linearIssueId` at schemaVersion 2.0.0; pre-2.0.0 contracts
still in flight should also be checked under the legacy field name for
backward compatibility). Look for `.afk/attestations/<id>.json`. If
absent:

> Refusing to run. No attestation record at
> `.afk/attestations/<id>.json`. Run `/attest` first; the runner refuses
> to dispatch an unattested contract regardless.

### 3. SHA bind matches

Compute SHA256 of the contract bytes. Compare with the record's
`attestedContentSha`. If different:

> Refusing to run. Attestation SHA drift detected.
>
> Contract SHA:    <computed>
> Attested SHA:    <attested>
>
> The contract was modified after attestation. Either revert the change
> or re-run `/attest`. The runner refuses any drifted contract.

### 4. No planner tokens remain

Grep for `<PLANNER_SUGGESTED:`. If any matches:

> Refusing to run. `.goal-contract.yml` still contains
> `<PLANNER_SUGGESTED:…>` token(s) at: <lines>. §G8 prohibits running an
> unresolved planner contract. The runner re-checks this; it would
> refuse anyway, but surfacing here is faster.

### 5. Repo is `afkEligible: true`

Read `.afk/config.yml`. If `afkEligible` is `false` or absent:

> Refusing to run. This repo's `.afk/config.yml` declares
> `afkEligible: false` (or omits the field — default safe). AFK refuses
> to operate against repos that aren't explicitly opted in. See
> [`docs/workflow.md#when-afkeligible-false-is-the-right-answer`](../../docs/workflow.md#when-afkeligible-false-is-the-right-answer)
> if you're unsure whether to flip this.

### 6. Local environment is ready

Validate, in order:

- `docker info` succeeds (Docker Desktop running).
- `~/.afk/keys/afk_signing_ed25519` exists and is readable.
- `~/.afk/keys/afk_signing_ed25519.pub` exists and is readable.
- One of: `LINEAR_API_KEY` env var is set, OR
  `~/.afk/secrets/linear-api-key` exists.
- `command -v npx` succeeds.

For each missing item, name the specific gap. Do not list everything in
one paragraph — one bullet per missing thing so the human can fix in
order.

## Invocation

Once all six preconditions pass:

1. Resolve the contract path (absolute), attestation path (absolute),
   target repo path (current working directory).
2. Resolve env vars:
   - `AFK_SIGNING_KEY_HOST_PATH` — `~/.afk/keys` (expanded).
   - `AFK_GIT_NAME` — from `git config --get user.name` if not set.
   - `AFK_GIT_EMAIL` — from `git config --get user.email` if not set.
   - `LINEAR_API_KEY` — from env, or read from
     `~/.afk/secrets/linear-api-key` and export for the child process.
3. Shell out to:

   ```
   npx @valesco/afk-runner \
     --contract <abs-path-to-.goal-contract.yml> \
     --attestation <abs-path-to-.afk/attestations/<id>.json> \
     --target-repo <abs-path-to-repo>
   ```

4. **Stream the runner's stdout and stderr to the user as they arrive.**
   The agent stream events surface here — text chunks, tool calls, and
   the eventual JSON result.
5. Capture the exit code:
   - `0` → completed.
   - `1` → failed (non-refusal error).
   - `2` → invalid CLI arguments (this skill's bug — surface and stop).
   - `3` → refused (audit record explains; surface the reason).

## After the run

Read `.afk/audit/<runId>/execution.json` (or `preflight.json` if
refused) and surface key fields:

- `runId`
- `verdict` — `valid` / `invalid_requires_human` / `stale_refreshable`
- `reasons` — list as bullets
- `phase`
- `contract.tier`
- `contract.bootstrap` — when `true`, prefix the report with
  `bootstrap-mode contract` so the human reviewing the branch knows the
  glob-resolution check was inverted, the canary plan was relaxed, and
  the friction-delay matrix used the bootstrap row (per VA-327 / VA-329
  / governance §G14).
- `preflight.bootstrap_allowlist_hits[]` — when present and non-empty,
  list each hit. These are pre-existing paths the bootstrap contract is
  legitimately allowed to touch via
  `afk/protected-paths/bootstrap-allowlist.yml`. Surface for visibility;
  do not flag them as drift.
- `signals.path_facts.bootstrapAllowlistHits[]` — same list as observed
  through the path-facts signal lens. If it disagrees with
  `preflight.bootstrap_allowlist_hits[]`, surface the discrepancy
  prominently — that's a bug in pre-flight or in the audit emitter.

Plus from the runner's stdout JSON:

- `branch` — e.g. `afk/va-200`
- `commitShas` — list (if any)

Do **not** auto-open a PR. Do **not** auto-promote anything. The human
reviews the branch and decides next steps. State this explicitly in the
final report:

> Run complete. Branch `afk/va-200` exists with N signed commits. Audit
> record at `.afk/audit/<runId>/execution.json`. Review the diff and
> open a PR yourself when ready — `/run-attested` deliberately stops
> short of branch promotion.

## Documented limitation

`/run-attested` is the **v1 dogfood path** for the sandcastle adoption
([VA-287](https://linear.app/valescoagency/issue/VA-287)). It exists so
the runner can be exercised end-to-end before the central label
handler ([VA-291](https://linear.app/valescoagency/issue/VA-291)) is
built. Once v2 ships, production runs are triggered by the
`afk-ready` label and this skill becomes dev-only.

It also stops short of v1.5 capabilities still in scope:

- Tier 1 canary plan execution ([VA-289](https://linear.app/valescoagency/issue/VA-289))
- §G1 adversarial pairing ([VA-290](https://linear.app/valescoagency/issue/VA-290))

Tier 1 contracts will run, but the canary plan is a no-op until
v1.5a — note this in the post-run report when `metadata.tier === 1`.

## References

- Cross-repo epic: [VA-287](https://linear.app/valescoagency/issue/VA-287)
- Runner package: [VA-288](https://linear.app/valescoagency/issue/VA-288)
- Signing-key setup: [`afk/runner/docs/signing-key-setup.md`](https://github.com/ValescoAgency/valesco-platform/blob/main/afk/runner/docs/signing-key-setup.md)
- Sandcastle: <https://github.com/mattpocock/sandcastle>
- Skill/pipeline boundary: [`docs/workflow.md`](../../docs/workflow.md#skills-vs-pipeline)
