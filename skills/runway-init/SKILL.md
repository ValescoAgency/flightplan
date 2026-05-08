---
name: runway-init
description: Scaffold a target repo so [runway](https://github.com/ValescoAgency/runway) can drive coding agents against it via [@ai-hero/sandcastle](https://github.com/mattpocock/sandcastle). Wraps `npx sandcastle init` and layers on Valesco's customizations — varlock + 1Password integration, in-container secret resolution, drop-the-`.env` posture. Use when the user wants to onboard a new repo to runway, set up sandcastle in a repo that doesn't have it, or rotate an existing `.sandcastle/` to the secrets-free shape.
---

# /runway-init — onboard a repo to runway in one pass

The purpose of this skill is to take a clean target repo and leave it
in the exact shape runway needs:

- `.sandcastle/` (Sandcastle's own scaffold) present
- `.env.schema` at repo root, with `op://` references the user has
  confirmed point at real items in their 1Password vault
- `.sandcastle/Dockerfile` patched to bake in `varlock` + `op` CLI +
  a `claude` shim so the agent runs inside `varlock run -- claude.real`
- `.sandcastle/.env` deleted (no secrets at rest)
- A clean commit on a fresh branch ready for the user to push

Anything more than that is out of scope. This skill is **advisory** —
it produces a branch + commit, never auto-pushes, never opens a PR.

## When to run

- A target repo has just been created and needs to receive runway runs.
- An existing target repo predates the varlock customizations and
  still has secrets in `.sandcastle/.env` or its repo root `.env`.
- After a major Sandcastle bump that changes the generated Dockerfile
  template (re-run, re-apply the patch).

## When NOT to run

- The user wants to edit the issue body / triage the inbox → `/triage`.
- The user wants to debug code or build a feedback loop → `/diagnose`,
  `/feedback-loop`.
- The user wants to scaffold runway *itself* (the orchestrator
  package). runway-init only sets up *target repos* runway will drive.
- The repo is a control-plane / non-coding repo (docs site, design
  files). Sandcastle expects a code repo.

## Inputs you must collect from the user up front

Before running any script, confirm these. Don't assume.

1. **Tier choice.** Tier 2 is the recommended path:
   - **Tier 1** — sandcastle init only, secrets live in `.sandcastle/.env`
     on disk. Faster to set up, weaker security posture. Use if the user
     has explicitly opted out of varlock.
   - **Tier 2** — sandcastle init + varlock + 1Password CLI inside the
     container. Zero secrets at rest. **Default.**
2. **1Password vault layout.** For Tier 2 you need to scaffold the
   `.env.schema` with concrete `op://...` paths. Ask:
   - Which 1Password account (e.g. `valesco`)?
   - Which vault (e.g. `runway`, `engineering`)?
   - Item names for `ANTHROPIC_API_KEY` and `GH_TOKEN` — do they live in
     a single shared item with multiple fields, or one item per secret?
3. **Idempotency.** If `.sandcastle/` already exists, ask:
   - Re-init from scratch (delete and recreate)?
   - Patch in place (just apply the varlock layer to the existing
     Dockerfile and re-write `.env.schema`)?

If any of these is unclear, stop and ask. Don't pick defaults silently.

## How to run

The scripts in [`scripts/`](scripts/) are sequenced 00 → 30. Run them
from the **target repo's root**, not from within flightplan.

| Script | What it does | When to skip |
|---|---|---|
| [`00-preflight.sh`](scripts/00-preflight.sh) | Check the host has Docker running, `gh` authenticated, `node` ≥ 22, and (Tier 2 only) `varlock` + `op` installed. Confirm we're inside a clean git tree. | Never. |
| [`10-sandcastle-init.sh`](scripts/10-sandcastle-init.sh) | `npx sandcastle init`. Creates `.sandcastle/` in the cwd. | If `.sandcastle/` already exists and the user chose patch-in-place. |
| [`20-apply-varlock.sh`](scripts/20-apply-varlock.sh) | Tier 2 only. Patches `.sandcastle/Dockerfile`, scaffolds `.env.schema` at repo root, deletes `.sandcastle/.env`. Takes vault layout as args. | Skip for Tier 1. |
| [`30-verify.sh`](scripts/30-verify.sh) | Static checks: `.env.schema` syntactically valid, Dockerfile shim references `varlock`, no plaintext secrets in `.sandcastle/.env`. | Never. |

The skill body is responsible for:

1. Asking the user for the inputs above.
2. Calling the scripts in order with the right flags.
3. Showing the user the diff before staging.
4. Staging on a fresh branch named
   `chore/runway-init-{epoch-ms}` (no force pushes, no main branch
   commits).
5. Committing with this message body:

   ```
   chore: scaffold for runway via /runway-init

   Tier: <1|2>
   sandcastle: <version>
   varlock: <version, Tier 2 only>
   1Password vault: <account>/<vault>

   Per .claude/skills/runway-init from flightplan.
   ```

6. Telling the user to push and open a PR. Never push for them.

## Templates this skill ships

Vendored copies of the canonical files from
[ValescoAgency/runway](https://github.com/ValescoAgency/runway). They
live in [`templates/`](templates/) so the skill is self-contained
(works offline, doesn't depend on runway's main being current at the
moment of invocation).

| Template | Source of truth |
|---|---|
| [`templates/env.schema.target-repo`](templates/env.schema.target-repo) | `runway/templates/.env.schema.target-repo` |
| [`templates/dockerfile-varlock.snippet`](templates/dockerfile-varlock.snippet) | `runway/templates/dockerfile-varlock.snippet` |

When you bump these, also bump
[`runway/templates/`](https://github.com/ValescoAgency/runway/tree/main/templates).
Drift between the two is a bug.

## AI disclaimer

The commit message this skill produces does NOT need a "generated by
AI" disclaimer — the skill name + the commit body identify provenance
clearly. If the skill posts a comment to a tracker issue (it shouldn't,
but if it does), the standard disclaimer applies:

```
> *This was generated by AI during runway-init.*
```

## What this skill deliberately does NOT do

- **Push or open a PR.** User reviews the diff and ships it themselves.
- **Touch 1Password.** No `op item create` calls. The user is
  responsible for putting items in their vault before invoking this
  skill; we read but don't write.
- **Validate that secrets exist in 1Password.** If the user gave a
  nonexistent path, the first runway run will fail informatively. We
  don't pre-fetch.
- **Update runway itself.** This skill operates on target repos.
- **Modify `.github/workflows/`.** Out of scope for runway adoption.

## Gotchas

- Sandcastle's generated Dockerfile uses `ENTRYPOINT ["sleep",
  "infinity"]` — the agent isn't PID 1, it's `docker exec`'d. That's
  why our shim approach replaces the `claude` binary in
  `/home/agent/.local/bin/`. If a future Sandcastle release changes
  the agent invocation path, the patch in
  `templates/dockerfile-varlock.snippet` may need updating.
- The `op` CLI inside the container needs `OP_SERVICE_ACCOUNT_TOKEN` —
  runway's orchestrator passes that in via Sandcastle's
  `docker({ env })` option. The user does not need to bake the token
  into the image.
- `.env.schema` lives at repo **root**, not under `.sandcastle/`.
  varlock's convention. Don't move it.

## References

- [runway README](https://github.com/ValescoAgency/runway#readme)
- [runway secrets-with-varlock walkthrough](https://github.com/ValescoAgency/runway/blob/main/docs/secrets-with-varlock.md)
- [@ai-hero/sandcastle docs](https://github.com/mattpocock/sandcastle/tree/main/docs)
- [varlock Docker workflows](https://varlock.dev/llms-full.txt)
