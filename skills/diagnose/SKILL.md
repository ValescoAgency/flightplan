---
name: diagnose
description: Disciplined diagnosis loop for hard bugs and performance regressions. Reproduce → hypothesise → instrument → fix → regression-test, with Phase 1 (build a feedback loop) load-bearing. Use when the user says "diagnose this", "debug this", "reproduce this bug", "this is throwing/failing/broken in prod", "why is this slow", or describes a performance regression. Distinct from `/triage` (which decides whether a bug has enough information to be tractable at all). Run this AFTER triage has confirmed the issue is real, BEFORE letting the issue become `ready-for-agent` for runway — the regression test you write seeds the issue's acceptance criteria and the loop you build proves the fix actually closes the bug.
---

# /diagnose

A discipline for hard bugs. Six phases; **Phase 1 is the skill** —
everything else is mechanical once you have a deterministic, agent-runnable
pass/fail signal for the bug. Skip phases only when you can articulate why.

This skill is advisory. It writes test files, scripts, harnesses, and
fixtures — never tracker labels or status changes. Its outputs feed the
next skill in the chain — see [§ Outputs](#outputs-that-flow-downstream).

## When to run

After [`/triage`](../triage/SKILL.md) has classified the issue as a `Bug`
with enough detail to attempt reproduction, but **before** the issue
becomes `ready-for-agent` for runway. An issue that lands in runway without a
concrete reproducer almost always produces a "fix" that passes review
without proving anything — the regression test you build here pins the
behavior down.

Also valid: standalone debugging during HITL work, where the bug never
makes it to runway. The phases still apply.

## When NOT to run

- The reporter's body lacks reproduction steps and the code path is unclear
  → run [`/triage`](../triage/SKILL.md) and post `needs-info` with
  specific questions instead.
- The bug is already reproducing in CI — Phase 1 is mostly free; jump to
  Phase 3.
- The "bug" is actually a missing feature — this is `Feature`/`Improvement`
  work, not diagnosis. Run [`/grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)
  → `/to-prd` → `/to-issues` instead.

## Pre-flight — read project context

Before Phase 1, read [`CONTEXT.md`](../../docs/workflow.md#contextmd--ubiquitous-language)
for the project's domain glossary, and skim [`docs/adr/`](../../docs/workflow.md#adrs)
for any architectural decision in the area you're touching. Use the
glossary vocabulary in everything you write — test names, log prefixes,
hypothesis text — so downstream readers (the reporter, the human PR
reviewer, the Claude Code instance running inside runway) inherit
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
deterministic loop is a debugging superpower.

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
> Recommend handing back to `/triage` to apply `needs-info` with these
> as the specific blockers.

This is the right answer. Hypothesising without a loop produces plausible
fixes that don't prove anything. Take the slower path.

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
Don't block on it — proceed with your ranking if the user is away.

Use the [`CONTEXT.md`](../../docs/workflow.md#contextmd--ubiquitous-language)
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

The whole point of doing this before letting an issue go to runway is that
the artefacts have downstream consumers. After Phase 6, hand the user a
structured summary they can paste into the tracker comment or edit into the
issue body itself.

| Artefact from this run | Where it goes next |
|---|---|
| The Phase 5 regression test | Becomes one of the issue body's testable acceptance criteria. Phrase it as "When `<scenario>`, the system produces `<observation>`" so the spec round-trips. |
| The Phase 1 feedback loop (script / test / harness) | Stays in the repo (or `scripts/debug/`) and serves as a deterministic check Claude Code can run while implementing the fix. Reference it in the issue body so runway picks it up alongside the spec. |
| The hypothesis that turned out correct | Goes in the tracker comment / PR description as the post-mortem one-liner. |
| Architectural finding (no good seam, etc.) | Open a separate tracker issue tagged `Improvement` and route through `/to-issues` → `/triage`. Do **not** bundle architectural work into the bug-fix issue. |
| New domain term encountered | Update [`CONTEXT.md`](../../docs/workflow.md#contextmd--ubiquitous-language) right there — same discipline as `/grill-with-docs`. Lazy-create the file if it doesn't exist. |

After this skill finishes, the next step is [`/triage`](../triage/SKILL.md)
to advance the issue to `ready-for-agent` (or `needs-human` if the diagnosis surfaced
something that runway shouldn't handle).

## AI disclaimer

When this skill posts a comment to the active tracker (e.g. summarising the
diagnosis for a Bug issue before handing back to triage), the comment
**must** start with this disclaimer on its own line, before any other
content:

```
> *This was generated by AI during diagnosis.*
```

When the skill writes only to local files (the regression test, the
feedback loop script, debug logs), no disclaimer is needed — those carry
their own provenance via git history.

## Non-goals

- **No tracker label transitions.** Status / label moves on the active
  tracker are [`/triage`](../triage/SKILL.md)'s job. This skill may
  *recommend* a transition (e.g. "looks ready for `ready-for-agent`") but applies
  nothing itself.
- **No production instrumentation without explicit user approval.** Phase 4
  logs are local; production probes need the user to say yes.
- **No architectural refactoring inline.** Phase 5 may *note* that the
  architecture blocks a regression test, but the actual restructuring is a
  separate skill invocation, not an extension of this one.

## References

- [`../triage/SKILL.md`](../triage/SKILL.md) — upstream
  (decides whether a bug is even tractable).
- [`../feedback-loop/SKILL.md`](../feedback-loop/SKILL.md) — sibling
  reference on constructing loops; pattern detail for the ten approaches in
  Phase 1.
- [Matt Pocock's `diagnose`](https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnose/SKILL.md)
  — upstream inspiration for the six-phase loop. The phases here are the
  same; the tracker integration is what's added.
