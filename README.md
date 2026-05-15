<a href="https://valescoagency.com">
  <img src="assets/va-bowtie-logo-primary.svg" alt="Valesco Agency" width="80" />
</a>

# ValescoAgency/flightplan

Claude Code skills authored by or curated for [Valesco Agency](https://valescoagency.com)
to drive tracker issues from idea to a clean handoff state for
[runway](https://github.com/ValescoAgency/runway), Valesco's autonomous
coding CLI.

## Install

```sh
claude plugin marketplace add ValescoAgency/flightplan
claude plugin install flightplan@valesco
```

For local development against a working clone:

```sh
claude plugin marketplace add /path/to/local/flightplan
claude plugin install flightplan@valesco
```

After install, skills are invocable as `flightplan:<skill-name>` (e.g.
`flightplan:triage`, `flightplan:diagnose`).

## Contents

- [`CONTEXT.md`](CONTEXT.md) — ubiquitous-language glossary for
  flightplan + runway. Read on session start.
- [`docs/workflow.md`](docs/workflow.md) — end-to-end map from idea to
  PR, repo conventions, HITL fork.
- [`docs/adr/`](docs/adr/) — architectural decision records.
- `skills/<skill-name>/SKILL.md` — Valesco-authored skills, one
  directory per skill (Claude Code plugin convention).

## Consumer skills

User-invoked skills that drive issues toward the runway pickup state
(label `ready-for-agent`). Vendor-agnostic — they read the active tracker via
the adapter system below.

| Skill | Purpose |
|---|---|
| [`/triage`](skills/triage/SKILL.md) | Funnel issues to the `ready-for-agent` label with sharp acceptance criteria so runway will pick them up. HITL-aware. |
| [`/diagnose`](skills/diagnose/SKILL.md) | Six-phase debugging discipline; Phase 1 builds a deterministic feedback loop. |
| [`/feedback-loop`](skills/feedback-loop/SKILL.md) | The 10-pattern catalog for constructing deterministic agent-runnable signals. |
| [`/handoff`](skills/handoff/SKILL.md) | Compact the current conversation into a handoff document so another agent can continue the work. |

## Tracker adapters

Modular per-vendor adapters that satisfy the
[tracker contract](docs/adr/0001-tracker-adapter-contract.md). The
active adapter is selected via `tracker:` in `.afk/config.yml` (default
`linear`).

| Adapter | Status | Capabilities |
|---|---|---|
| [`tracker-linear`](skills/tracker-linear/SKILL.md) | Shipped (default) | Full — customer field, project/cycle membership, team namespace, reliable active-work detection |
| [`tracker-github`](skills/tracker-github/SKILL.md) | Shipped | Reduced — no customer field, best-effort active-work detection |
| `tracker-jira`, `tracker-local-md` | Deferred | — |

These compose with Matt Pocock's
[engineering skills](https://github.com/mattpocock/skills/tree/main/skills/engineering)
(`/grill-with-docs`, `/to-prd`, `/to-issues`,
`/improve-codebase-architecture`, `/zoom-out`, `/tdd`) per the workflow
in [`docs/workflow.md`](docs/workflow.md). Matt's `/triage` is **not**
adopted — flightplan's `/triage` adds runway-prep discipline (sharp
acceptance criteria, HITL routing) on top of the same canonical state
machine.

## Related

- [`runway`](https://github.com/ValescoAgency/runway) — autonomous CLI;
  reads issues from the tracker, runs Claude Code in
  [`@ai-hero/sandcastle`](https://www.npmjs.com/package/@ai-hero/sandcastle),
  runs an adversarial sub-agent review, opens a PR.
- [Matt Pocock's skills](https://github.com/mattpocock/skills) —
  upstream for `/grill-with-docs`, `/to-prd`, `/to-issues`,
  `/improve-codebase-architecture`, `/zoom-out`, `/tdd`.
