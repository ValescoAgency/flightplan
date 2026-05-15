# Workflow — flightplan + runway

Reference for how flightplan skills compose with Matt Pocock's engineering
skills to drive a tracker issue from idea to a runway pickup. The
[runway](https://github.com/ValescoAgency/runway) CLI takes it from there.

## End-to-end map

```
idea / conversation / paste
        │
        ▼
   /grill-with-docs        (Matt — alignment + glossary + ADR)
        │
        ▼
        /to-prd            (Matt — synthesizes PRD from context)
        │
        ▼
        /to-issues         (Matt — vertical-slice tracer-bullet issues)
        │
        ▼
   ─── Tracker issue exists ───────────────────────────────────────
        │
        ▼
   /triage                  (Valesco — ensure body has sharp acceptance criteria)
        │
        ├─→ needs-human  → HITL exit (human picks up)
        ├─→ needs-info   → wait for reporter
        └─→ ready-for-agent  (label; runway pickup signal)
                │
                ▼
        /diagnose           (Valesco — Bugs only; build a deterministic loop)
                │           │
                │           └─ uses /feedback-loop for the 10 patterns
                │
                ▼
        /grill-with-docs    (optional, when domain alignment looks suspect)
                │
                ▼
   ─── runway picks the issue up via the `ready-for-agent` label ────
                │
                ▼
   sandcastle (Claude Code in Docker) implements the issue
                │
                ▼
   sub-agent review                       (adversarial pass)
                │
                ▼
   PR opened on GitHub                    (human reviews + merges)
```

The handoff to runway is **the issue body when `ready-for-agent` is
applied**. Whatever's in the issue at that moment is what Claude Code
sees. So `/triage`'s job is to make sure the issue body has clear
acceptance criteria before applying the label. Status is left to the
tracker's GitHub integration (PR open → `In Progress`, PR merge →
`Done`) — it's a useful side effect, not the queue gate.

## Stage ownership

| Stage | Skill | Source | Purpose |
|---|---|---|---|
| Idea → aligned plan | [`/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md) | Matt | Alignment + locks domain language in `CONTEXT.md` + records ADRs inline |
| Plan → PRD | [`/to-prd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-prd/SKILL.md) | Matt | Synthesizes a PRD from current context; posts to the tracker |
| PRD → issues | [`/to-issues`](https://github.com/mattpocock/skills/blob/main/skills/engineering/to-issues/SKILL.md) | Matt | Breaks the PRD into vertical-slice tracer-bullet issues |
| Tracker issue → `ready-for-agent` | [`/triage`](../skills/triage/SKILL.md) | Valesco | Ensure body has sharp acceptance criteria; apply `ready-for-agent` so runway picks it up; HITL-aware |
| Bug needs reproducer | [`/diagnose`](../skills/diagnose/SKILL.md) | Valesco | Six-phase loop; Phase 1 builds a deterministic feedback loop |
| Construct a feedback loop | [`/feedback-loop`](../skills/feedback-loop/SKILL.md) | Valesco | The 10-pattern catalog for deterministic agent-runnable signals |
| Architecture review | [`/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md) | Matt | Find deepening opportunities; informed by `CONTEXT.md` + ADRs |
| Issue → PR | runway | runway CLI | Runs sandcastle, sub-agent review, opens PR |
| PR → main | human | — | Human reviews and merges. Trust comes from review, not from upstream gates. |

## Repo conventions this workflow assumes

For the workflow to compose cleanly, projects under
`github.com/ValescoAgency` adopt these conventions:

1. **`CONTEXT.md`** at the repo root (single-context) or
   **`CONTEXT-MAP.md`** + per-context `CONTEXT.md` (multi-context, e.g.
   monorepos). Holds the project's ubiquitous language. Maintained by
   `/grill-with-docs` and `/improve-codebase-architecture`.
2. **`docs/adr/`** at the repo root, or per-context. Records architectural
   decisions that meet the three-condition rule: hard to reverse,
   surprising without context, result of a real trade-off.
3. **`.afk/config.yml`** (optional). Today the only field these skills
   read is `tracker:` (default `linear`). The directory name is a
   historical artefact and may move in a later cleanup.

## Tracker adapters

The "context layer" — issue body, comments, labels, status — is a
**modular component**. The active adapter is loaded at session start
based on `.afk/config.yml`'s `tracker:` field (or sniffed from the git
remote). Consumer skills speak only canonical names; the adapter
translates to vendor-native form.

| Adapter | Status | Notes |
|---|---|---|
| [`tracker-linear`](../skills/tracker-linear/SKILL.md) | Default, shipped | Full capability set — `customer_field`, `team_namespace`, reliable active-work detection. |
| [`tracker-github`](../skills/tracker-github/SKILL.md) | Shipped | Reduced capabilities — no `customer_field`, best-effort active-work detection. Triage works end-to-end. |
| `tracker-jira`, `tracker-local-md` | Deferred | — |

The contract that defines the adapter API is
[ADR-0001](./adr/0001-tracker-adapter-contract.md).

## CONTEXT.md — Ubiquitous Language

The glossary file. Every term agents and humans use to describe the
project's domain — the Eric Evans "ubiquitous language" idea, made
concrete as a markdown file the agent can read on session start.

### What goes in

- Domain nouns the project distinguishes (`Customer` vs `User`,
  `Order` vs `Cart`, `Subscription` vs `Plan`).
- Domain verbs that mean something specific (`materialize`, `cancel`,
  `enroll`).
- Concepts that have a precise project-specific meaning beyond their
  common-English reading.

### What stays out

- Implementation details — class names, file paths, framework choices.
- Things any reader of the codebase would understand without the file.
- Refactor candidates / code-review observations — those go in
  `docs/adr/` or are addressed in the code itself.

### When to update

Inline, as terms are resolved during a `/grill-with-docs` or
`/improve-codebase-architecture` run. Don't batch.

### Why agents need this

Cold-start agents (Claude Code inside sandcastle, sub-agents spawned by
the Explore tool, fresh Claude Code sessions) start with no project
vocabulary. They guess at "user" vs "customer," reinvent verbs the team
has already named, and produce verbose code that uses 20 words where 1
will do. A read-on-start glossary collapses that to a paragraph.

## ADRs

Architectural Decision Records under `docs/adr/`. One file per decision,
numbered (`0001-event-sourced-orders.md`, `0002-postgres-write-model.md`).

### When an ADR is warranted

All three must hold (Matt's rule, adopted as Valesco doctrine):

1. **Hard to reverse** — changing your mind later costs real engineering.
2. **Surprising without context** — a future reader will wonder "why?"
3. **Result of a real trade-off** — there were genuine alternatives.

If any of the three is missing, skip the ADR. Most decisions don't merit
one.

### What's in the file

Format per Matt's
[ADR-FORMAT.md](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/ADR-FORMAT.md).
Short version:

- Context (the trade-off as it was at decision time)
- Decision (what was chosen)
- Consequences (what becomes easier and harder)
- Status (proposed / accepted / superseded by NNNN)

### How flightplan skills use ADRs

- [`/diagnose`](../skills/diagnose/SKILL.md) reads ADRs in the bug's area
  before hypothesising — sometimes a "bug" is the documented behavior of
  an ADR'd decision.
- [`/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md)
  surfaces ADR conflicts as part of its candidate-deepening list.
- Claude Code (running inside runway) inherits the same posture by
  reading the same files.

ADRs are read more often than they're written. That's the ratio you
want — six months later they're a navigation aid, not a notebook.

## HITL fork

Not every issue is runway-eligible. The workflow is built around accepting
that gracefully and routing to a human without losing work.

| Trigger | Where it fires | Skill response |
|---|---|---|
| Triage decides this needs a human | `/triage` Step 5 | Apply `needs-human`, post a Human Brief explaining why. runway drains by `ready-for-agent` label, so an issue tagged `needs-human` (and not `ready-for-agent`) is invisible to runway. |
| `/diagnose` cannot build a feedback loop | Phase 1 fallback | Drop back to `/triage` with `needs-info` listing the specific blockers. |
| Sub-agent review surfaces a real concern | runway (not a skill) | runway opens the PR with the concern in the body; the human decides whether to merge or close. |

The HITL fork is a feature, not a failure. An issue routed to
`needs-human` has been triaged, briefed, and (if a bug) often diagnosed —
the human picking it up has the same context Claude Code would have had.

## Conflict rule

When skill output (Matt's or Valesco's) contradicts:

- The house rules in `~/.claude/rules/*.md`,
- An ADR in `docs/adr/`,

**the rules / ADR win.** Skill output is advisory; those are authority.

## References

- [`runway`](https://github.com/ValescoAgency/runway) — the autonomous
  CLI flightplan feeds.
- `valesco-platform/docs/sdlc/workflow.md` — Valesco SDLC.
- [Matt Pocock's skills](https://github.com/mattpocock/skills) — upstream
  for `/grill-with-docs`, `/to-prd`, `/to-issues`,
  `/improve-codebase-architecture`, `/zoom-out`, `/tdd`.
