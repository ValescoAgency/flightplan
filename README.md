# ValescoAgency/skills

Claude Code skills authored by or curated for [Valesco Agency](https://valescoagency.com).

Primary consumer: the AFK (autonomous) coding governance pipeline at
[`ValescoAgency/valesco-platform`](https://github.com/ValescoAgency/valesco-platform).

## Contents

- [`docs/starter-set.md`](docs/starter-set.md) — the specific skills adopted for
  Valesco work, with rationale.
- [`docs/gaps.md`](docs/gaps.md) — skills known to be missing, registered as they
  bite.
- `<skill-name>/SKILL.md` — authored Valesco skills live at the repo root,
  one directory per skill (Claude Code plugin convention). Empty at repo
  birth; populated as gaps are closed.

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

## Related

- [valesco-platform](https://github.com/ValescoAgency/valesco-platform) — AFK
  governance + platform code
- [docs/sdlc/workflow.md](https://github.com/ValescoAgency/valesco-platform/blob/main/docs/sdlc/workflow.md) — Valesco SDLC including §8 AFK governance
- [docs/afk/governance-plan.md](https://github.com/ValescoAgency/valesco-platform/blob/main/docs/afk/governance-plan.md) — boundary constraints any adopted skill must respect
