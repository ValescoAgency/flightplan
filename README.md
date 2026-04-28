# ValescoAgency/flightplan

Everything an AFK run needs before takeoff. Claude Code skills (and, eventually,
commands, hooks, MCP servers, and subagents) authored by or curated for
[Valesco Agency](https://valescoagency.com).

Primary consumer: the AFK (autonomous) coding governance pipeline at
[`ValescoAgency/valesco-platform`](https://github.com/ValescoAgency/valesco-platform).

## Contents

- [`skills/`](skills/) — authored Claude Code skills, one directory per skill.
  Currently ships:
  - [`linear-triage/`](skills/linear-triage/) — funnel Linear issues toward
    `ready-for-agent`. Upstream of `draft-contract`.
  - [`draft-contract/`](skills/draft-contract/) — lift a Linear issue's Agent
    Brief into `.goal-contract.draft.yml`.
  - [`attest/`](skills/attest/) — walk the tier-scaled attestation checklist
    and write the hash-bound attestation record.
- [`docs/starter-set.md`](docs/starter-set.md) — the specific skills adopted
  for Valesco work, with rationale.
- [`docs/gaps.md`](docs/gaps.md) — skills known to be missing, registered as
  they bite.

Reserved layout (empty for now, populated as needed):

- `commands/` — author-deterministic slash commands
- `hooks/` — Claude Code lifecycle hooks
- `mcp/` — locally-shipped MCP servers
- `agents/` — subagent definitions

## Install

```sh
claude plugin marketplace add github:ValescoAgency/flightplan
claude plugin install valesco@valesco
```

For local development (in-flight changes against a working clone):

```sh
claude plugin marketplace add /path/to/local/flightplan
claude plugin install valesco@valesco
```

After install, skills are invocable as `valesco:<skill-name>` (e.g.
`valesco:linear-triage`, `valesco:draft-contract`, `valesco:attest`).

## Skills-vs-pipeline rule

Load-bearing constraint on what belongs here:

- **Pipeline code** (lives in `valesco-platform/afk/`): capabilities touching
  hash-bound authority, audit records, tier gates, or requiring deterministic +
  replayable behavior. Validator runs, pre-flight checks, authority binding.
- **Skills** (live here): capabilities that are advisory, exploratory, or
  user-invoked. PRD drafting, domain modeling, triage, adversarial review
  passes, attestation walkthroughs.

If a proposed skill would violate the boundary, it becomes a pipeline ticket,
not a skill.

## Why "flightplan"

The AFK governance metaphor is autonomous flight: a goal-contract is an
authorized flight plan, pre-flight is the structural + volumetric + sandbox
check before engines spool, attestation is the captain's pre-departure log.
This repo is what you assemble *before* the run begins — the human-authored
stack of skills and tools that turn an idea into something AFK can fly.

## Related

- [valesco-platform](https://github.com/ValescoAgency/valesco-platform) — AFK
  governance + platform code
- [docs/sdlc/workflow.md](https://github.com/ValescoAgency/valesco-platform/blob/main/docs/sdlc/workflow.md) — Valesco SDLC including §8 AFK governance
- [docs/afk/governance-plan.md](https://github.com/ValescoAgency/valesco-platform/blob/main/docs/afk/governance-plan.md) — boundary constraints any adopted skill must respect
