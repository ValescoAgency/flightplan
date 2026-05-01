---
name: feedback-loop
description: Construct a deterministic, agent-runnable pass/fail signal for a bug, regression, or feature — fast, sharp, and reproducible without a human in the loop. Use when the user says "build a test harness", "make this reproducible", "set up a verifier for this contract", "what's the cheapest reproducer for this bug", "the dev loop is too slow", or "we need a deterministic check for this". This is the reference skill the rest of the Valesco engineering chain leans on: `/diagnose` Phase 1 invokes it to find a bug's cause, `/tdd` invokes it to drive new code red→green, and `/draft-contract` invokes it when authoring the goal-contract's `verification.commands`. Distinct from `/diagnose` (which *uses* loops to locate causes) and `/tdd` (which *uses* loops to drive incremental implementation) — this skill is about *constructing* the loop itself. Whenever you find yourself debugging by re-reading code or running ad-hoc commands without a deterministic pass/fail, stop and run this.
---

# /feedback-loop

Construct a fast, sharp, deterministic, agent-runnable pass/fail signal for
the behavior under question. Pick from a catalog of ten patterns, harden
the loop against flakes, and hand it off to whatever skill called this one.

This skill is advisory. It writes test files, scripts, harnesses, and
fixtures — never `.goal-contract*.yml`, never `.afk/attestations/`, never
labels. The loop you build here is the *input* to those authority-bearing
artefacts, not the artefact itself.

## Why a deterministic loop is load-bearing

Three things in the Valesco chain depend on the loop existing and behaving
predictably:

1. **AFK pre-flight.** The goal-contract's `verification.commands` are
   executed unattended by the AFK runner. A flaky verifier produces flaky
   AFK runs — bad code merges because the flake masked a real failure, or
   good code rolls back because the flake fired on a clean diff. Per
   governance plan §G10, Tier-1 contracts require deterministic verifiers
   or disqualification.
2. **`/diagnose` Phase 1.** Without a loop, hypothesis-testing degrades to
   hand-waving. Phase 1 is the entire skill — the rest is mechanical once
   the signal exists.
3. **`/tdd` red→green.** A test that takes 30 seconds to fail breaks the
   tracer-bullet rhythm; the agent stops listening to its own feedback.

If you don't have a loop, you don't have engineering — you have
storytelling. Build the loop.

## When to run

- Inside `/diagnose` Phase 1, when you've reproduced the bug by hand but
  need an automatable signal.
- Inside `/tdd`, when picking the seam for the first failing test in a new
  feature slice.
- Inside `/draft-contract`, when the contract needs a `verification.commands`
  entry and the source tracker issue doesn't yet specify one.
- Standalone, when the user says "the dev loop is too slow" — the
  iteration ladder applies even when no specific bug is on the table.

## When NOT to run

- The loop already exists and runs in CI — use it; don't rebuild.
- The "loop" the user wants is a manual checklist for stakeholders. That's
  a runbook, not a feedback loop.
- The bug only matters in production with real customer data. First run
  `/triage` to determine whether you have legitimate access to a
  reproducer; this skill cannot manufacture one out of nothing.

## Pre-flight — read AFK context

Read `.afk/config.yml` at the working repo root to set the determinism bar:

| Field | Determinism requirement |
|---|---|
| `afkEligible: true` + `projectTier: 1` | **Disqualified-or-deterministic.** No documented flakes accepted in `verification.commands`. Every retry attempt is a failure to root-cause. Spend the time. |
| `afkEligible: true` + `projectTier: 2` | Documented flakes tolerated if the flake rate is < 1% and the failure mode is well-understood. Add a `# flake-budget: <reason>` comment in the verifier. |
| `afkEligible: true` + `projectTier: 3` | Best effort. Some flakiness OK if the alternative is no loop at all. |
| `afkEligible: false` | The loop feeds a human PR — use whatever level of determinism the human reviewer is willing to defend. |
| missing | Surface to the maintainer before continuing. |

This bar shapes which patterns are eligible (e.g., HITL bash is never a
Tier-1 verifier — humans aren't part of the AFK runner) and how aggressively
to climb the iteration ladder.

## Three properties of a good loop

Every loop, regardless of pattern, is judged on three axes. A 30-second
flaky loop is barely better than no loop at all; a 2-second deterministic
loop is a debugging superpower.

### Fast

- **Target:** under 5 seconds wall-clock per iteration.
- **Superpower threshold:** under 2 seconds. At this speed the agent (or
  human) iterates without losing context between cycles.
- **Disqualifying:** over 30 seconds per iteration on Tier 1 — the AFK
  runner's retry budget burns too quickly.

How to get fast: cache setup steps (don't re-bootstrap the DB on every
iteration), narrow the scope (run *one* test, not the whole file), skip
unrelated init, swap heavy deps for thin fakes only at the *outer*
boundary.

### Sharp

A sharp loop asserts on the **specific symptom**, not "didn't crash". If
the bug is "wrong total when cart contains a 0-priced item", the
assertion is `assert total == 0`, not `assert order.completed_ok`.

Sharp loops survive refactors because they describe *behavior*, not
*structure*. A loop that fails when you rename an internal function was
testing implementation, not behavior — see [`/tdd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md).

### Deterministic

Same input, same output, every run, on every machine. The four sources of
non-determinism to neutralize:

- **Time** — pin the clock (`vi.useFakeTimers()`, `freezegun`, or inject
  a clock dependency).
- **Randomness** — seed RNG (`Math.random` is rarely the issue; UUIDs and
  test data factories are).
- **Filesystem** — isolate per-test (`tmp.mkdtempSync()`, ephemeral
  Supabase branch via `mcp__a80053c7…__create_branch`).
- **Network** — freeze with a recorded fixture (MSW, VCR, nock) or run
  inside a container with no egress.

If you cannot neutralize one of the four, document which and why in a
comment alongside the loop. AFK pre-flight will read it on Tier 1.

## Pattern catalog

Pick the cheapest pattern that produces a sharp signal. The patterns are
ordered by general preference — when in doubt, try them in this order.

### 1. Failing test

A test at the seam closest to the bug — unit when behavior is local,
integration when the bug only appears across module boundaries, e2e when
the bug is in wiring.

- **When it fits:** the codebase has a test framework, the behavior is
  callable from test code, the bug reproduces with a small input.
- **Pitfalls:** mocking too aggressively (the bug lives in the
  collaboration); writing the test at the wrong seam (unit test for a
  bug that needs three callers to trigger).
- **Skeleton:**
  ```
  test("reproduces <symptom>", () => {
    setup();
    const result = systemUnderTest(triggeringInput);
    expect(result).toBe(expectedSymptom); // initially the bug, then the fix
  });
  ```
- **Iteration ladder:** narrow scope to one test (`vitest <file> -t <name>`),
  skip unrelated setup hooks, switch from full DB to in-memory adapter only
  if the bug isn't in the DB layer.

### 2. Curl / HTTP harness

A shell script that hits a running dev server with a recorded request and
asserts on the response shape, status, or specific field.

- **When it fits:** the bug is reachable via the public API; you have a
  dev server you can keep running.
- **Pitfalls:** auth tokens that expire mid-iteration; non-deterministic
  IDs in the response (compare *shape* with `jq`, not full body diff);
  forgetting to seed the DB to a known state between runs.
- **Skeleton:**
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  RESPONSE=$(curl -sS -X POST http://localhost:3000/api/orders \
    -H "Content-Type: application/json" \
    -d @fixtures/order.json)
  echo "$RESPONSE" | jq -e '.total == 0' > /dev/null
  ```
- **Iteration ladder:** keep the server warm between runs; pre-seed the DB
  with a snapshot; pin the auth token to a long-lived test JWT.

### 3. CLI fixture diff

Invoke the CLI with a fixture input file and diff stdout against a
recorded snapshot.

- **When it fits:** the system is a CLI, code generator, or text
  transformer; output is text.
- **Pitfalls:** newline / trailing-whitespace drift across platforms;
  timestamps in output (filter or normalize before diffing); ANSI color
  codes (strip with `sed -r 's/\x1b\[[0-9;]*m//g'`).
- **Skeleton:**
  ```bash
  ./bin/mytool < fixtures/input.txt > /tmp/actual.txt
  diff -u fixtures/expected.txt /tmp/actual.txt
  ```
- **Iteration ladder:** snapshot tooling (`vitest -u`, `insta`) instead of
  hand-maintained expected files; canonicalize output (sort lines if order
  doesn't matter).

### 4. Headless browser script

Playwright or Puppeteer drives the real UI; the script asserts on DOM
state, console messages, or network calls.

- **When it fits:** the bug is in client-side behavior, layout, or
  browser-only APIs (IndexedDB, service workers, scroll behavior).
- **Pitfalls:** real network calls (mock at the route level, not the
  fetch level — closer to the network seam); racy waits (`waitForSelector`,
  not `setTimeout`); zombie browser processes between runs.
- **Skeleton:**
  ```ts
  test("cart total updates", async ({ page }) => {
    await page.goto("/cart");
    await page.getByRole("button", { name: /add/i }).click();
    await expect(page.getByTestId("total")).toHaveText("$0.00");
  });
  ```
- **Iteration ladder:** use Playwright's `--ui` mode for first-build,
  drop to headless for the production loop; record video on failure only;
  pin viewport size to make selectors stable.

### 5. Replay a captured trace

Save a real network request / payload / event log to disk; replay it
through the code path in isolation.

- **When it fits:** the bug only appears with production-shaped data, but
  the data itself is reproducible (no PII, or PII can be scrubbed); race
  conditions captured by a time-stamped event log.
- **Pitfalls:** PII or secrets in the captured trace (sanitize before
  committing); trace from a deployed version that no longer exists in code
  (note the version in the fixture filename); replays that hit external
  services (stub them).
- **Skeleton:**
  ```ts
  test("processes captured webhook payload", async () => {
    const payload = JSON.parse(fs.readFileSync("fixtures/webhook-2026-04-30.json"));
    const result = await processWebhook(payload);
    expect(result.status).toBe("rejected");
  });
  ```
- **Iteration ladder:** trim the trace to the minimal subset that still
  reproduces; canonicalize timestamps; commit one fixture per shape, not
  one per occurrence.

### 6. Throwaway harness

A minimal subset of the system — one service, faked deps — that exercises
the bug code path with a single function call. Lives in `scripts/debug/`,
not in the test suite.

- **When it fits:** the system is too tangled to test in place; the bug
  spans a refactor that hasn't landed; you need to call into private
  internals.
- **Pitfalls:** the harness diverges from production wiring and "fixes"
  bugs that production still has; harness becomes load-bearing
  infrastructure (it shouldn't — Phase 6 of `/diagnose` deletes it).
- **Skeleton:**
  ```ts
  // scripts/debug/repro-VA-142.ts
  import { internalFunction } from "../../src/feature/private";
  const result = internalFunction(buildInput());
  if (result !== "expected") process.exit(1);
  ```
- **Iteration ladder:** keep the import surface minimal (you're not
  rebuilding the system); add `console.time` blocks to find the slow part;
  delete the harness as soon as a real test seam exists.

### 7. Property / fuzz loop

Run 1000+ random inputs through the system and look for the failure mode.

- **When it fits:** "sometimes wrong output" bugs; serializers, parsers,
  state machines, anything with a large input space; no obvious
  triggering input.
- **Pitfalls:** unbounded test time (cap with `numRuns`); shrinking
  failures the framework can't simplify (write a custom shrinker); flakes
  from network or time inside the property (don't — keep the property
  pure).
- **Skeleton:**
  ```ts
  fc.assert(fc.property(fc.array(fc.integer()), arr => {
    const sorted = mySort(arr);
    return isAscending(sorted);
  }), { numRuns: 1000, seed: 42 });
  ```
- **Iteration ladder:** seed the PRNG (`seed: 42`); save the smallest
  counterexample as a regression test; raise `numRuns` only after the
  shrinker is reliable.

### 8. Bisection harness

`git bisect run` over a script that boots state X, checks the bug,
exits 0 (good) or 1 (bad).

- **When it fits:** the bug appeared between two known states (commits,
  package versions, dataset versions); the bug is reproducible at every
  commit in the range.
- **Pitfalls:** broken intermediate commits (mark with `git bisect skip`);
  the bug requires a re-install of dependencies (script must run `pnpm i`);
  bisecting through a refactor that renamed everything (history-aware
  bisection — `--first-parent`).
- **Skeleton:**
  ```bash
  #!/usr/bin/env bash
  set -e
  pnpm install --frozen-lockfile > /dev/null
  ./bin/repro || exit 1   # bug present
  exit 0                   # bug absent
  ```
- **Iteration ladder:** cache `node_modules` per commit hash to skip the
  reinstall; pre-build once if the build is deterministic; bisect over a
  package-lock range, not source range, when the suspect is a dep.

### 9. Differential loop

Run the same input through two configurations — old version vs new, two
deployments, two implementations — and diff outputs.

- **When it fits:** "this used to work" bugs where you can run the working
  version side-by-side; comparing two implementations during a migration;
  validating a refactor preserves behavior.
- **Pitfalls:** incidental differences swamp the real one (canonicalize
  before diffing); the two configurations don't actually receive the same
  input (log the input on both sides and verify); diff size makes the
  signal unreadable (semantic diff with `jq -S`).
- **Skeleton:**
  ```bash
  ./bin/old-tool < input.json | jq -S . > /tmp/old.json
  ./bin/new-tool < input.json | jq -S . > /tmp/new.json
  diff -u /tmp/old.json /tmp/new.json
  ```
- **Iteration ladder:** strip fields known to differ (timestamps, IDs)
  before diffing; iterate on a curated input corpus, not random inputs;
  pin both versions to specific hashes so the comparison is reproducible.

### 10. HITL bash

A bash script that prompts a human for the action, captures the result,
and feeds it back to the agent. Last resort — humans are not part of the
AFK runner, so this disqualifies the loop as a Tier-1 verifier.

- **When it fits:** the bug is in a closed system (vendor app, hardware,
  external service) where no programmatic loop exists; the human can give
  reliable yes/no per iteration.
- **Pitfalls:** human fatigue (cap iterations); ambiguous answers
  (force yes/no — no free text); using HITL when one of patterns 1–9
  would actually have worked.
- **Skeleton:**
  ```bash
  #!/usr/bin/env bash
  read -p "Click the buy button. Did the modal close? (y/n) " ok
  [[ "$ok" == "y" ]] && exit 0 || exit 1
  ```
- **Iteration ladder:** capture *what* the human did so the next iteration
  can suggest a programmatic alternative; never use HITL twice in a row
  without re-evaluating patterns 1–9.

## Which pattern do I pick?

Walk this tree top-to-bottom. Stop at the first "yes."

1. **Is there an existing test seam that exercises the behavior end-to-end?**
   → Pattern 1 (failing test).
2. **Is the surface an HTTP API and you have a dev server?** → Pattern 2
   (curl harness).
3. **Is the surface a CLI or text transformer?** → Pattern 3 (CLI fixture
   diff).
4. **Is the bug only visible in the rendered UI?** → Pattern 4 (headless
   browser).
5. **Can you replay a captured production trace?** → Pattern 5 (replay
   trace).
6. **Is the system too tangled or mid-refactor to test in place?**
   → Pattern 6 (throwaway harness).
7. **Is the bug "sometimes" — non-deterministic on input?** → Pattern 7
   (property / fuzz).
8. **Did the bug appear between two known commits / versions?** → Pattern 8
   (bisection).
9. **Are there two configurations or versions you can compare?** → Pattern 9
   (differential).
10. **Final fallback** — and only after honestly trying 1–9: Pattern 10
    (HITL bash). Mark the loop as Tier-1-disqualified in any
    `verification.commands` reference.

If you fall off the bottom of the tree without a fit, the bug isn't
loopable yet — return to `/triage` and request reproducer access,
trace capture, or production instrumentation as `needs-info`.

## Iteration ladder

Apply across every pattern. Climb until the loop is fast, sharp, and
deterministic enough to defend at the relevant tier.

| Step | Cheap | Expensive |
|---|---|---|
| Cache setup | Memoize fixture loads, keep dev server warm. | Snapshot the entire DB and restore between runs. |
| Narrow scope | Filter to one test (`-t name`). | Compile a per-test bundle that excludes unrelated code. |
| Pin time | Inject a clock; freeze in the test. | Run inside a container with the system clock pinned. |
| Seed RNG | Pass an explicit seed to test data factories. | Replace global RNG with a deterministic-by-default wrapper. |
| Isolate filesystem | `tmp.mkdtempSync()` per test. | Per-test ephemeral Supabase branch. |
| Freeze network | MSW / VCR / nock at the route level. | Container with no egress; recorded HAR replay. |
| Raise repro rate | Loop the trigger 100×; tighten timing windows. | Inject targeted sleeps to widen the race window; run under TSAN. |

For non-deterministic bugs the goal is not a clean repro but a **higher
reproduction rate**. A 50%-flake bug is debuggable; 1% is not. Climb the
ladder until the rate is workable, then build the loop on top of *that*.

## Hand-off — how the loop becomes downstream input

The loop you build here usually doesn't stay in `scripts/debug/`. It
graduates into the project's permanent infrastructure:

| Caller | What the loop becomes |
|---|---|
| [`/diagnose`](../diagnose/SKILL.md) Phase 1 | The active feedback loop for hypothesis testing. The Phase 5 regression test typically condenses it into a permanent test. |
| [`/tdd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md) | The first failing test in the red→green cycle. Each subsequent slice extends or copies it. |
| [`/draft-contract`](../draft-contract/SKILL.md) | A `verification.commands` entry — phrased as a single shell invocation that exits 0 on pass, non-zero on fail. The AFK runner will execute it unattended. |
| [`/brief-to-contract`](../brief-to-contract/SKILL.md) | The bridge that lifts the loop from "ad-hoc reproducer" to "named verifier in the goal-contract." |

When invoked from `/draft-contract`, output the loop in a form ready to
paste into `verification.commands`:

```yaml
verification:
  commands:
    - "pnpm vitest run src/cart/total.test.ts -t 'zero-priced item'"
    # 2.1s wall-clock, deterministic (clock pinned, RNG seeded, MSW for /api/prices)
```

The trailing comment documents the three-properties evidence so a future
reader (or auditor) knows what was demonstrated, not just claimed.

## Self-validation before declaring done

- [ ] The loop exits 0 on pass, non-zero on fail. No "look for the right
      string in the output."
- [ ] Wall-clock time measured and recorded. (Ideally < 5s, < 2s on Tier
      1 verifiers.)
- [ ] The loop has been run **three times in a row** and produced the same
      result each time.
- [ ] Every source of non-determinism (time / randomness / filesystem /
      network) is either neutralized or explicitly documented in a comment.
- [ ] On Tier 1, no `# flake-budget` comment is present.
- [ ] No human input required mid-loop (or, if HITL, the disqualification
      is noted in the hand-off).

If any check fails, fix the loop before returning. A loop that "mostly
works" is the same as no loop — it pollutes downstream skills with noise.

## Non-goals

- **No test framework prescription.** Use what the project uses. If the
  project doesn't have one, surface that to the user and let them choose
  before continuing — picking a framework is a project-level decision,
  not a per-loop one.
- **No performance budget setting.** "Loop should be fast" is the
  discipline here. "API should respond in < 100ms" is a goal-contract
  field — see [`/draft-contract`](../draft-contract/SKILL.md).
- **No fix authoring.** This skill ends when the loop reliably observes
  the bug. The fix is `/diagnose` Phase 5 or `/tdd` green.
- **No production instrumentation.** Loops live in test code or
  `scripts/debug/`, never in `src/`. Production probes need explicit user
  approval per the protected-paths convention.
- **No CI integration.** Hooking the loop into CI is a project-level
  decision after the loop is proven locally.

## References

- [`../diagnose/SKILL.md`](../diagnose/SKILL.md) — the primary caller;
  Phase 1 is "build a loop using this skill."
- [`../draft-contract/SKILL.md`](../draft-contract/SKILL.md) — consumer
  for `verification.commands`.
- [`../brief-to-contract/SKILL.md`](../brief-to-contract/SKILL.md) —
  orchestrates this skill into the contract pipeline.
- [Matt Pocock's `/tdd`](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md)
  — the red→green caller; this skill is the "build the red" half.
- [Matt Pocock's `/diagnose`](https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnose/SKILL.md)
  — Phase 1 of his version is the doctrinal source for the ten-pattern
  catalog; this skill is the expanded reference.
- `valesco-platform/docs/afk/governance-plan.md` §G10 — Tier-1 verifier
  determinism rule.
- `valesco-platform/afk/schemas/goal-contract.v1.json` — the
  `verification.commands` field shape.
