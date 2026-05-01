---
name: diagnose
description: Disciplined diagnosis loop for hard bugs and performance regressions inside the Valesco AFK pipeline. Reproduce → hypothesise → instrument → fix → regression-test, with Phase 1 (build a feedback loop) load-bearing. Use when the user says "diagnose this", "debug this", "reproduce this bug", "this is throwing/failing/broken in prod", "why is this slow", or describes a performance regression. Distinct from `/linear-triage` (which decides whether a bug has enough information to be tractable at all) and `/draft-contract` (which lifts an already-diagnosed issue into a goal-contract). Run this AFTER triage has confirmed the issue is real, BEFORE drafting a contract — the feedback loop you build here is a candidate verifier for the contract's `verification.commands`, and the regression test you write seeds `intent.successCriteria`.
---

# /diagnose

A discipline for hard bugs. Six phases; **Phase 1 is the skill** — everything
else is mechanical once you have a deterministic, agent-runnable pass/fail
signal for the bug. Skip phases only when you can articulate why.

This skill is advisory. It never mutates AFK authority records (no contract
edits, no attestation writes, no label changes). Its outputs are intended to
feed the next skill in the chain — see [§ Outputs](#outputs-that-flow-downstream).

## When to run

After [`/linear-triage`](../linear-triage/SKILL.md) has classified the issue
as a `Bug` with enough detail to attempt reproduction, but **before**
[`/draft-contract`](../draft-contract/SKILL.md) lifts it into
`.goal-contract.draft.yml`. A contract drafted from an undiagnosed bug almost
always has weak `successCriteria` and no real verifier — pre-flight will
accept it, and the AFK run will produce code that "passes" without proving
anything.

Also valid: standalone debugging during HITL work, where the bug never makes
it to a contract. The phases still apply.

## When NOT to run

- The reporter's body lacks reproduction steps and the code path is unclear
  → run [`/linear-triage`](../linear-triage/SKILL.md) and post `needs-info`
  with specific questions instead.
- The bug is already reproducing in CI — Phase 1 is mostly free; jump to
  Phase 3.
- The "bug" is actually a missing feature — this is `Feature`/`Improvement`
  work, not diagnosis. Run [`/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)
  → `/to-prd` → `/to-issues` instead.

## Pre-flight — read AFK context

Before Phase 1, read `.afk/config.yml` at the working repo root:

| Field | Effect on diagnosis |
|---|---|
| `afkEligible: false` | The repo is a control plane (e.g. `valesco-platform`). Diagnose still runs, but the loop you build will feed a **human** PR, not an AFK contract. Skip the contract-handoff steps in [§ Outputs](#outputs-that-flow-downstream). |
| `afkEligible: true` + `projectTier: 1` | Production / client-critical. The feedback loop you build is a **load-bearing** verifier. Be aggressive about determinism — flaky verifiers on Tier 1 are unacceptable per governance plan §G10. |
| `afkEligible: true` + `projectTier: 2` or `3` | Standard discipline applies. |
| missing | Surface to the maintainer before continuing. |

Also: read [`CONTEXT.md`](../docs/workflow.md#contextmd--ubiquitous-language)
for the project's domain glossary, and skim [`docs/adr/`](../docs/workflow.md#adrs)
for any architectural decision in the area you're touching. Use the glossary
vocabulary in everything you write — test names, log prefixes, hypothesis
text — so downstream skills (`/draft-contract`, `/to-issues`) inherit
consistent language.

## Phase 1 — Build a feedback loop

**This is the skill.** If you have a fast, deterministic, agent-runnable
pass/fail signal for the bug, you will find the cause — bisection,
hypothesis-testing, and instrumentation all just consume that signal. If
you don't have one, no amount of staring at code will save you.

Spend disproportionate effort here. **Be aggressive. Be creative. Refuse
to give up.**

### Ten patterns, in roughly this order

Try them in order; stop at the first one that works for this bug. Deep
detail on each lives in [`/feedback-loop`](../feedback-loop/SKILL.md) — that
sibling skill is the reference for *constructing* loops; this skill is the
reference for *using* them inside a diagnosis.

1. **Failing test** at whatever seam reaches the bug — unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI fixture diff** — invoke the CLI with a known input, diff stdout
   against a recorded snapshot.
4. **Headless browser script** (Playwright / Puppeteer) — drives the UI,
   asserts on DOM / console / network.
5. **Replay a captured trace** — save a real network request / payload /
   event log to disk; replay it through the code path in isolation.
6. **Throwaway harness** — minimal subset of the system (one service, mocked
   deps) exercising the bug code path with a single function call.
7. **Property / fuzz loop** — for "sometimes wrong output" bugs, run 1000
   random inputs and look for the failure mode.
8. **Bisection harness** — `git bisect run` over a script that boots state X,
   checks, repeats.
9. **Differential loop** — same input through old-version vs new-version (or
   two configs); diff outputs.
10. **HITL bash** — last resort. Drive the human via
    `scripts/hitl-loop.template.sh` so the loop is still structured. Captured
    output feeds back to the agent.

### Iterate on the loop itself

The loop is a product. Once you have *a* loop, ask:

- **Faster?** Cache setup, skip unrelated init, narrow scope.
- **Sharper?** Assert on the specific symptom, not "didn't crash".
- **More deterministic?** Pin time, seed RNG, isolate filesystem, freeze
  network.

A 30-second flaky loop is barely better than no loop. A 2-second
deterministic loop is a debugging superpower — and on Tier 1, anything less
disqualifies it as a verifier.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the
trigger 100×, parallelise, add stress, narrow timing windows, inject
sleeps. A 50%-flake bug is debuggable; 1% is not — keep raising the rate
until it's debuggable.

### When you genuinely cannot build a loop

Stop. Do **not** proceed to hypothesise. Output:

> Cannot construct a feedback loop. Tried: <list>. Need one of:
>   (a) access to the environment that reproduces it,
>   (b) a captured artifact (HAR, log dump, core dump, screen recording with
>       timestamps),
>   (c) permission to add temporary production instrumentation.
>
> Recommend handing back to `/linear-triage` to apply `needs-info` with these
> as the specific blockers.

This is the right answer. Hypothesising without a loop produces plausible
fixes that don't prove anything — exactly what AFK pre-flight is supposed
to prevent. Take the slower path.

## Phase 2 — Reproduce

Run the loop. Watch the bug appear. Confirm:

- [ ] The loop produces the failure mode the **user** described — not a
      different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for
      non-deterministic bugs, at a high enough rate to debug against).
- [ ] The exact symptom (error message, wrong output, slow timing) is
      captured so later phases can verify the fix actually addresses it.

Do not proceed until you reproduce the bug.

## Phase 3 — Hypothesise

Generate **3–5 ranked hypotheses** before testing any of them.
Single-hypothesis generation anchors on the first plausible idea.

Each hypothesis must be **falsifiable** — state the prediction it makes:

> If `<X>` is the cause, then `<changing Y>` will make the bug disappear /
> `<changing Z>` will make it worse.

If you cannot state the prediction, the hypothesis is a vibe — discard or
sharpen it.

**Show the ranked list to the user before testing.** They often have domain
knowledge that re-ranks instantly ("we just deployed a change to #3"), or
know hypotheses they've already ruled out. Cheap checkpoint, big time saver.
Don't block on it — proceed with your ranking if the user is AFK.

Use the [`CONTEXT.md`](../docs/workflow.md#contextmd--ubiquitous-language)
glossary in hypothesis names so the user reads them in the project's
language, not generic terms.

## Phase 4 — Instrument

Each probe maps to a specific prediction from Phase 3. **Change one variable
at a time.**

Tool preference:

1. **Debugger / REPL inspection** if the env supports it. One breakpoint
   beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup
becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong.
Establish a baseline measurement (timing harness, `performance.now()`,
profiler, `EXPLAIN ANALYZE` for queries), then bisect. Measure first, fix
second.

## Phase 5 — Fix + regression test

Write the regression test **before the fix** — but only if there is a
**correct seam** for it.

A correct seam exercises the **real bug pattern** as it occurs at the call
site. If the only available seam is too shallow (a single-caller test when
the bug needs multiple callers, a unit test that can't replicate the chain
that triggered the bug), a regression test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The
codebase architecture is preventing the bug from being locked down — flag
this for Phase 6 and for [`/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md).

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop against the original (un-minimised)
   scenario.

## Phase 6 — Cleanup + post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop).
- [ ] Regression test passes (or absence of seam is documented).
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix).
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug
      location like `scripts/debug/`).
- [ ] The hypothesis that turned out correct is stated in the commit / PR
      message — so the next debugger learns.

**Then ask: what would have prevented this bug?** If the answer involves
architectural change (no good test seam, tangled callers, hidden coupling),
hand off to [`/improve-codebase-architecture`](https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md)
with the specifics. Make the recommendation **after** the fix is in, not
before — you have more information now than when you started.

If the bug surfaced an architectural decision worth recording (a non-obvious
constraint that future debuggers should know), offer an ADR via
[`/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md).
Same three-condition rule: hard to reverse, surprising without context,
result of a real trade-off.

## Outputs that flow downstream

The whole point of doing this before contract drafting is that the artefacts
have downstream consumers. After Phase 6, hand the user a structured summary
they can paste into Linear or feed to the next skill.

| Artefact from this run | Where it goes next |
|---|---|
| The Phase 1 feedback loop (script / test / harness) | Becomes a candidate `verification.commands` entry in the goal-contract — the AFK run will execute it and pre-flight requires it to be deterministic. Reference it explicitly when invoking `/draft-contract`. |
| The Phase 5 regression test | Seeds an `intent.successCriteria` bullet — phrase it as "When `<scenario>`, the system produces `<observation>`" so it round-trips through the schema's ≥ 5-char testable rule. |
| The hypothesis that turned out correct | Goes in the Linear comment / PR description as the post-mortem one-liner. |
| Architectural finding (no good seam, etc.) | Open a separate Linear issue tagged `Improvement` and route through `/to-issues` → `/linear-triage`. Do **not** bundle architectural work into the bug-fix contract. |
| New domain term encountered | Update [`CONTEXT.md`](../docs/workflow.md#contextmd--ubiquitous-language) right there — same discipline as `/grill-with-docs`. Lazy-create the file if it doesn't exist. |

If `afkEligible: false`, the first two rows do not apply — feed straight to
a human PR instead.

## AI disclaimer

When this skill posts a comment to Linear (e.g. summarising the diagnosis
for a Bug issue before handing back to triage), the comment **must** start
with this disclaimer on its own line, before any other content:

```
> *This was generated by AI during diagnosis.*
```

When the skill writes only to local files (the regression test, the
feedback loop script, debug logs), no disclaimer is needed — those carry
their own provenance via git history.

## Non-goals

- **No contract authoring.** Output feeds [`/draft-contract`](../draft-contract/SKILL.md);
  this skill never writes `.goal-contract*.yml`.
- **No attestation.** Diagnosis is upstream of attestation — see
  [`/attest`](../attest/SKILL.md).
- **No label transitions.** Status / label moves on Linear are
  [`/linear-triage`](../linear-triage/SKILL.md)'s job. This skill may
  *recommend* a transition (e.g. "looks ready for `/draft-contract`") but
  applies nothing itself.
- **No production instrumentation without explicit user approval.** Phase 4
  logs are local; production probes need the user to say yes per the
  governance plan's protected-paths convention.
- **No architectural refactoring inline.** Phase 5 may *note* that the
  architecture blocks a regression test, but the actual restructuring is a
  separate skill invocation, not an extension of this one.

## References

- [`../linear-triage/SKILL.md`](../linear-triage/SKILL.md) — upstream
  (decides whether a bug is even tractable).
- [`../feedback-loop/SKILL.md`](../feedback-loop/SKILL.md) — sibling
  reference on constructing loops; pattern detail for the ten approaches in
  Phase 1.
- [`../draft-contract/SKILL.md`](../draft-contract/SKILL.md) — downstream
  (lifts a diagnosed bug into a goal-contract).
- [`../attest/SKILL.md`](../attest/SKILL.md) — gates the contract.
- [Matt Pocock's `diagnose`](https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnose/SKILL.md)
  — upstream inspiration for the six-phase loop. The phases here are the
  same; the AFK / Linear / contract integration is what's added.
- `valesco-platform/docs/afk/governance-plan.md` §G8 (planner → main handoff
  — why a contract drafted from an undiagnosed bug is structurally weak).
- `valesco-platform/docs/afk/governance-plan.md` §G10 (Tier-1 verifier
  determinism requirement).
