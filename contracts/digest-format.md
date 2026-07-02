# Contract: the morning digest

One file per day: `ops/reports/YYYY-MM-DD.md`. The orchestrator creates it;
later loops APPEND their own `## <stage>` sections (never rewrite earlier
ones); a manual re-run appends `## Re-run HH:MM`. It is the operator's
single pane of glass: a GREEN digest must be skimmable in 15 seconds.

```markdown
# <project> daily — YYYY-MM-DD   (run $ILOOP_RUN_ID; duration/cost in runs.jsonl)
Status: 🟢 GREEN | 🟡 ATTENTION | 🔴 INCIDENT — <one sentence>
> NOTIFY: <max 3 lines per run, whitelist categories only; omit if none>

## Needs you   (omit when empty)
- [ ] Every item MUST state: WHY the loop is blocked (the exact knob or
      rule), the EXACT action (copy-pasteable command, or URL + precise
      edit), and what happens once done. Vague asks are forbidden.

## Guardian (safety)         ← orchestrator subagent sections
## Operator (deploys · prod health · queue funnel)
## Analysis (E2E trends)
## Gardener (hygiene · ratchet)
## Changes committed
## Proposals (ranked) / issues filed
## Skipped / degraded

## E2E user journey          ← appended by later loops, one section each
## E2E tester sweep
## Fixer
## PR verifier
```

Rules:

- **Status:** 🔴 any incident · 🟡 any Needs-you item, rollback, flaky test,
  or degraded stage · 🟢 otherwise.
- **The funnel table is mandatory** (Operator section): every open issue →
  state → next actor → next action time, per contracts/queue-state-machine.md.
  Orphans are a 🟡 finding.
- Every claim links a ledger row, metrics field, issue/PR number, or log
  path. INCIDENT sections carry raw command output, not summaries.
- `> NOTIFY:` lines are the ONLY notification channel (wrapper fans out
  lines this run appended, max 3). Respect the DIRECTION notify whitelist.
- Retention: dailies older than `DIGEST_RETENTION_DAYS` get one summary line
  each in `ops/reports/weekly/YYYY-Www.md`, then are deleted (gardener duty).
- Machine-readable siblings: `ops/metrics/YYYY-MM-DD.json` (telemetry +
  gates + repo ratchet: LOC, deps, tests-collected), `ops/ledger/*.jsonl`
  (journeys, deploys, tester rows), `$STATE_DIR/runs.jsonl` (wrapper-written
  per-run cost/diff row — the tamper check against digest claims).
