# Starter skill set

Small, defended set of Claude Code skills Valesco adopts for day-to-day work
around the AFK pipeline. Tuned with Jason 2026-04-21; revisit when a skill
proves redundant or a gap keeps biting.

The skills-vs-pipeline rule in [README](../README.md) governs every entry. If a
skill starts creeping into authority, audit, or tier-gate territory, it moves
to pipeline code at `valesco-platform/afk/` and drops off this list.

---

## Adopted — core (always-on posture)

| Skill | Source | Use case in AFK-adjacent work |
|---|---|---|
| `to-prd` | Matt Pocock | Authors the PRD that becomes a Linear intent issue. Upstream of any AFK contract. |
| `grill-me` | Matt Pocock | Adversarial pass on the PRD before intent is posted. Distinct from the pipeline's adversarial reviewer — this one is user-invoked on drafts, not on contracts. |
| `domain-model` | Matt Pocock | Domain modeling pass before a feature is sliced into issues. Output feeds PRDs + Supabase schemas. |
| `ubiquitous-language` | Matt Pocock | Naming discipline. Pays off downstream in Supabase column names, Zod schema types, server-action names, route handlers. |
| `triage-issue` | — | Linear triage pass. Classifies incoming issues, sets priority/labels/team. |
| `write-a-skill` | Matt Pocock (for now) | Meta. Lets gaps get closed in-flight without filing a ticket per skill. See note on Anthropic's variant in [gaps.md](./gaps.md). |

## Adopted — user-invoked review passes

These do not auto-run. Invoke deliberately.

| Skill | Source | When to invoke |
|---|---|---|
| `tdd` | Matt Pocock | Feature work where TDD is the explicit posture. Discipline — not optional once invoked. |
| `security-and-hardening` | Addy Osmani | Review pass on auth paths, RLS policies, payment flows, any net-new surface that takes untrusted input. |
| `performance-optimization` | Addy Osmani | Review pass when a page or action measurably regresses. Not preventive — reactive to signal. |
| `design-an-interface` | — | Deliberate design-interface work (IA, component contracts, API shapes). User-invoked only. |
| `frontend-ui-engineering` | Addy Osmani | UI-heavy feature work. User-invoked only — house style (Tailwind + shadcn + `react-components.md` rules) wins any conflict. |

**shadcn/ui skill**: adopted per-project, not globally. Added when a project's
frontend surface justifies it.

---

## Rejected / deferred

| Skill | Decision | Rationale |
|---|---|---|
| `improve-codebase-architecture` | Rejected | Overlaps `grill-me` + `domain-model`. |
| `request-refactor-plan` | Rejected | Overlaps the Plan agent / planning phase of AFK contracts. |
| `git-guardrails-claude-code` | Rejected | Lefthook + branch protection cover this mechanically per `workflow.md` §7. Skill would duplicate without adding authority. |
| `obsidian`, `obsidian-vault` | Out of scope | Personal knowledge workflow, orthogonal to AFK. |
| `caveman` | N/A | Response style, not a workflow skill. Loaded per session. |

---

## Conflict rule

If a skill's output contradicts the house rules in
`~/.claude/rules/*.md` or `valesco-platform/docs/afk/governance-plan.md`,
**the rules win**. Skill output is advisory; rules are authority.

---

## Revisit triggers

Revise this list when:
- An adopted skill gets invoked fewer than 1x/month over two months → demote to rejected.
- A rejected skill gets wanted three times → promote.
- A gap in [gaps.md](./gaps.md) gets authored and lands → move to adopted.
