# Attestation record — worked example

Authoritative shape lives in
`valesco-platform/afk/schemas/attestation-record.v1.json`. This file
is a human-readable reference showing two worked examples (all-ticked
and mixed ticked/skipped). The schema is the source of truth; if this
file drifts, the schema wins.

## Shape

```json
{
  "schemaVersion": "1.0.0",
  "trackerIssueId": "<TEAM-NNN | owner/repo#NNN>",
  "attestedContentSha": "sha256:<64 hex chars>",
  "tier": 1 | 2 | 3,
  "bootstrap": false,
  "attestedAt": "<ISO 8601 datetime>",
  "attester": "<git user.name <user.email>>",
  "adversarialReviewStatus": "reviewed" | "pending" | "not-run",
  "timeSinceDraftMinutes": <non-negative integer>,
  "items": [
    {
      "id": "<kebab-case>",
      "label": "<verbatim prompt as rendered>",
      "state": "ticked" | "skipped",
      "rationale": "<required when skipped; forbidden when ticked>"
    }
  ]
}
```

Keys:

- `trackerIssueId` is the record's key on disk: file lives at
  `.afk/attestations/<trackerIssueId>.json`. One record per tracker
  issue at a time; re-running `/attest` overwrites. The field was
  named `linearIssueId` pre-schemaVersion 2.0.0; pre-2.0.0 records on
  disk remain valid under the legacy key.
- `attestedContentSha` is the raw SHA-256 of the `.goal-contract.yml`
  file bytes at attestation time. The afk-ready label handler
  re-computes this sha against the current YAML; drift rejects the
  promotion.
- `bootstrap` mirrors `metadata.bootstrap` from the contract. Surfaced
  on the record so downstream consumers (label handler, run-attested,
  audit emitter) know to apply the bootstrap-mode invariants without
  re-parsing the contract YAML. Defaults to `false` if absent.
- `adversarialReviewStatus` and `timeSinceDraftMinutes` are optional.

## Example 1 — Tier 3, all items ticked

```json
{
  "schemaVersion": "1.0.0",
  "trackerIssueId": "VA-160",
  "attestedContentSha": "sha256:7d793037a0760186574b0282f2f435e7b8a9b26edb6c1b0a8d42fd9c8c3e5f01",
  "tier": 3,
  "bootstrap": false,
  "attestedAt": "2026-04-22T01:12:00Z",
  "attester": "Jason Kennemer <jason@valescoagency.com>",
  "adversarialReviewStatus": "reviewed",
  "timeSinceDraftMinutes": 20,
  "items": [
    {
      "id": "intent-matches-tracker",
      "label": "I have re-read the referenced tracker issue within the last 15 minutes. The contract's intent.description, successCriteria, and nonGoals still reflect the issue's current wording — no silent drift between the tracker and the YAML.",
      "state": "ticked"
    },
    {
      "id": "paths-are-minimal",
      "label": "scope.requiredPaths and scope.writePaths are the minimum set required to satisfy the contract. I have not included a broad glob (e.g., src/**) when a narrower one would work.",
      "state": "ticked"
    },
    {
      "id": "no-hard-floor-in-writepaths",
      "label": "No hard-floor path appears in scope.writePaths. ...",
      "state": "ticked"
    },
    {
      "id": "cost-estimate-acknowledged",
      "label": "I have reviewed the pre-flight cost estimate (or acknowledged that pre-flight has not yet been run and the tier's default per-contract budget will apply).",
      "state": "ticked"
    },
    {
      "id": "time-delay-elapsed",
      "label": "At least the required delay has elapsed between the contract's initial draft write and now. ...",
      "state": "ticked"
    },
    {
      "id": "adversarial-review-considered",
      "label": "I have considered the adversarial review outcome. ...",
      "state": "ticked"
    },
    {
      "id": "tier-3-not-expired",
      "label": ".afk/config.yml has a tier_expires date and that date has not yet passed. ...",
      "state": "ticked"
    }
  ]
}
```

## Example 2 — Tier 1, incident override, time-delay skipped

```json
{
  "schemaVersion": "1.0.0",
  "trackerIssueId": "VA-242",
  "attestedContentSha": "sha256:c775e7b757ede630cd0aa1113bd102661ab38829ca52a6422ab782862f268646",
  "tier": 1,
  "bootstrap": false,
  "attestedAt": "2026-04-22T03:04:00Z",
  "attester": "Jason Kennemer <jason@valescoagency.com>",
  "adversarialReviewStatus": "reviewed",
  "timeSinceDraftMinutes": 4,
  "items": [
    { "id": "intent-matches-tracker", "label": "...", "state": "ticked" },
    { "id": "paths-are-minimal", "label": "...", "state": "ticked" },
    { "id": "no-hard-floor-in-writepaths", "label": "...", "state": "ticked" },
    { "id": "cost-estimate-acknowledged", "label": "...", "state": "ticked" },
    {
      "id": "time-delay-elapsed",
      "label": "At least the required delay has elapsed ...",
      "state": "skipped",
      "rationale": "Incident override VA-241 — prod auth regression; 15-min sensitive-path delay waived per G1 incidentOverride rule. Logged as urgent_business_need override."
    },
    { "id": "adversarial-review-considered", "label": "...", "state": "ticked" },
    { "id": "customer-identifier-correct", "label": "...", "state": "ticked" },
    { "id": "canary-plan-sensible", "label": "...", "state": "ticked" },
    { "id": "incident-override-rationale", "label": "...", "state": "ticked" }
  ]
}
```

## Example 3 — Tier 1 bootstrap (foundation slice)

A bootstrap-mode contract attesting a green-field scaffolding slice.
Note: `bootstrap: true`, `canary-plan-sensible` is **not present** (its
`applies` clause excluded it), and `bootstrap-claim-self-verifying`
appears as a ticked item.

```json
{
  "schemaVersion": "1.0.0",
  "trackerIssueId": "VA-312",
  "attestedContentSha": "sha256:a3f2b1c8e0d4f5e6b7a8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0",
  "tier": 1,
  "bootstrap": true,
  "attestedAt": "2026-05-08T14:30:00Z",
  "attester": "Jason Kennemer <jason@valescoagency.com>",
  "adversarialReviewStatus": "reviewed",
  "timeSinceDraftMinutes": 6,
  "items": [
    { "id": "intent-matches-tracker", "label": "...", "state": "ticked" },
    { "id": "paths-are-minimal", "label": "...", "state": "ticked" },
    { "id": "no-hard-floor-in-writepaths", "label": "...", "state": "ticked" },
    { "id": "cost-estimate-acknowledged", "label": "...", "state": "ticked" },
    { "id": "time-delay-elapsed", "label": "... bootstrap row of matrix ...", "state": "ticked" },
    { "id": "adversarial-review-considered", "label": "...", "state": "ticked" },
    { "id": "customer-identifier-correct", "label": "...", "state": "ticked" },
    { "id": "bootstrap-claim-self-verifying", "label": "Every glob in scope.requiredPaths either resolves to zero files on the current main branch, OR resolves only to paths listed in afk/protected-paths/bootstrap-allowlist.yml. ...", "state": "ticked" }
  ]
}
```

## Validation

The skill writes the record then validates it against
`attestation-record.v1.json` before returning. On AJV failure, the
record is deleted, not left on disk. See `SKILL.md` step 5.
