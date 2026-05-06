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
  "linearIssueId": "<TEAM-NNN>",
  "attestedContentSha": "sha256:<64 hex chars>",
  "tier": 1 | 2 | 3,
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

- `linearIssueId` is the record's key on disk: file lives at
  `.afk/attestations/<linearIssueId>.json`. One record per Linear
  issue at a time; re-running `/attest` overwrites.
- `attestedContentSha` is the raw SHA-256 of the `.goal-contract.yml`
  file bytes at attestation time. The afk-ready label handler
  re-computes this sha against the current YAML; drift rejects the
  promotion.
- `adversarialReviewStatus` and `timeSinceDraftMinutes` are optional.

## Example 1 — Tier 3, all items ticked

```json
{
  "schemaVersion": "1.0.0",
  "linearIssueId": "VA-160",
  "attestedContentSha": "sha256:7d793037a0760186574b0282f2f435e7b8a9b26edb6c1b0a8d42fd9c8c3e5f01",
  "tier": 3,
  "attestedAt": "2026-04-22T01:12:00Z",
  "attester": "Jason Kennemer <jason@valescoagency.com>",
  "adversarialReviewStatus": "reviewed",
  "timeSinceDraftMinutes": 20,
  "items": [
    {
      "id": "intent-matches-linear",
      "label": "I have re-read the referenced Linear issue within the last 15 minutes. The contract's intent.description, successCriteria, and nonGoals still reflect the issue's current wording — no silent drift between Linear and the YAML.",
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
  "linearIssueId": "VA-242",
  "attestedContentSha": "sha256:c775e7b757ede630cd0aa1113bd102661ab38829ca52a6422ab782862f268646",
  "tier": 1,
  "attestedAt": "2026-04-22T03:04:00Z",
  "attester": "Jason Kennemer <jason@valescoagency.com>",
  "adversarialReviewStatus": "reviewed",
  "timeSinceDraftMinutes": 4,
  "items": [
    { "id": "intent-matches-linear", "label": "...", "state": "ticked" },
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

## Validation

The skill writes the record then validates it against
`attestation-record.v1.json` before returning. On AJV failure, the
record is deleted, not left on disk. See `SKILL.md` step 5.
