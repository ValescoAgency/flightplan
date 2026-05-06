# Out-of-Scope Knowledge Base

Each Valesco repo can have an `.out-of-scope/` directory at its root for persistent records of rejected `Feature` / `Improvement` requests. The directory serves two purposes:

1. **Institutional memory** — why a feature was rejected, so the reasoning isn't lost when the issue is closed `canceled`
2. **Deduplication** — when a new issue lands that matches a prior rejection, the skill can surface the previous decision instead of re-litigating it

The directory is per-repo, not per-tracker-team, because the rejection context is usually rooted in a specific codebase's architecture and scope.

## Directory structure

```
<repo-root>/.out-of-scope/
├── dark-mode.md
├── plugin-system.md
└── graphql-api.md
```

One file per **concept**, not per issue. Multiple tracker issues requesting the same thing share one file.

## File format

Write each file in a relaxed, readable style — closer to a short design doc than a database row. Paragraphs, code samples, and examples are welcome; the goal is for someone encountering the file fresh to understand the reasoning.

```markdown
# Dark Mode

This project does not support dark mode or user-facing theming.

## Why this is out of scope

The rendering pipeline assumes a single color palette defined in
`ThemeConfig`. Supporting multiple themes would require:

- A theme context provider wrapping the entire component tree
- Per-component theme-aware style resolution
- A persistence layer for user theme preferences

This is a significant architectural change that doesn't align with the
project's focus on content authoring. Theming is a concern for downstream
consumers who embed or redistribute the output.

```ts
// The current ThemeConfig is not designed for runtime switching:
interface ThemeConfig {
  colors: ColorPalette; // single palette, resolved at build time
  fonts: FontStack;
}
```

## Prior requests

- [VA-42](https://linear.app/valescoagency/issue/VA-42) — "Add dark mode support"
- [VA-87](https://linear.app/valescoagency/issue/VA-87) — "Night theme for accessibility"
- [VA-134](https://linear.app/valescoagency/issue/VA-134) — "Dark theme option"
```

### Naming the file

Use a short, descriptive kebab-case concept name: `dark-mode.md`, `plugin-system.md`, `graphql-api.md`. Someone browsing the directory should recognize what was rejected without opening the file.

### Writing the reason

The reason should be substantive — not "we don't want this" but **why**. Good reasons reference:

- Project scope or philosophy ("This project focuses on X; theming is a downstream concern")
- Technical constraints ("Supporting this would require Y, which conflicts with our Z architecture")
- Strategic decisions ("We chose A instead of B because…")
- Governance ("`valesco-platform` is `afkEligible: false` and this would require AFK to modify its own policies — §14.3")

The reason should be **durable**. Avoid temporary circumstances ("we're too busy right now") — those aren't real rejections, they're deferrals. Deferrals belong in `Backlog` status, not `.out-of-scope/`.

### Linking to Linear

Always link prior requests as full Markdown links to the Linear issue URL (`https://linear.app/valescoagency/issue/<KEY>-<NUM>`), not bare identifiers. The skill posts a comment on the Linear issue that links **back** to the `.out-of-scope/` file in the repo, so the trail is bidirectional.

## When to check `.out-of-scope/`

During triage Step 1 (gather context), read every `.out-of-scope/*.md` file in the working repo. When evaluating a new issue:

- Check whether the request matches an existing concept
- Match by **concept similarity**, not keywords — "night theme" matches `dark-mode.md`
- If there's a match, surface it: "This looks like `.out-of-scope/dark-mode.md` — we rejected this before because [reason]. Do you still feel the same way?"

The maintainer may:

- **Confirm** — append the new Linear issue to the existing file's "Prior requests" list, then close the Linear issue as `Canceled`
- **Reconsider** — delete or update the `.out-of-scope/` file, and let the issue proceed through normal triage
- **Disagree** — the issues are related but distinct; proceed with normal triage

## When to write to `.out-of-scope/`

Only when a `Feature` or `Improvement` is closed as `Canceled` (not `Duplicate`, not `Backlog`, and never for `Bug`). The flow:

1. Maintainer decides the request is out of scope.
2. Check whether a matching `.out-of-scope/` file exists.
3. If yes — append the new Linear issue to its "Prior requests" list.
4. If no — create a new file with the concept name, decision, reason, and the first prior request.
5. Post a comment on the Linear issue explaining the decision and linking to the `.out-of-scope/` file in the repo.
6. Set the Linear issue status to `Canceled`.

The order matters: write the file **before** posting the comment, so the comment can include a real link.

## Updating or removing out-of-scope files

If the maintainer changes their mind about a previously rejected concept:

- Delete (or rewrite) the `.out-of-scope/<concept>.md` file
- The skill does **not** reopen old Linear issues — they're historical records
- The new issue that triggered the reconsideration proceeds through normal triage

## Per-repo scope vs. cross-repo concepts

If a concept genuinely applies across multiple repos (rare), keep one file per repo and link them via "See also" lines at the bottom of each. Don't try to centralize — the rejection reason is almost always tied to *that* repo's architecture.
