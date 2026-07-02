# Harness audits (append-only; diff each entry against the previous)

## Audit #0 — 2026-07-03 — pre-loop baseline (Phase 1 read-only scoring)

Scored by the owner+Claude during self-hosting bootstrap, before the first
autonomous run. Spec: docs/AUDIT-CHECKLIST.md (fixed 10 items).

| # | Item | Status | Evidence | Failure prevented / smallest fix |
|---|---|---|---|---|
| 1 | Spec anchoring | **present** | ops/DIRECTION.md Focus (falsifiable bar); no-go floor drilled tonight: tamper commit 02c00fd auto-reverted by 86f9265, `--check-nogo` rc 3 | loop drifting from owner intent; loop editing the spec |
| 2 | Scope gate | **present** | fixer eligibility (agents/fixer/AGENT.md §1): accepted OR cooled, bug+Repro, no-feature rule §0; labels live on shenyuanv/general_improve_loop | feature work sneaking into the auto lane |
| 3 | Verify contract | **partial** | contract declares Verify REQUIRED for action:loop (contracts/issue-format.md) but `check_queue_lint` (bin/run-loop.sh:73-89) doesn't enforce it → **issue #6** (fix: mirror the bug⇒Repro jq test) | unfixable-but-eligible filings rotting in the queue |
| 4 | Separate evaluator | **present** | verify-one-pr.md: fresh context, default REJECT, re-repro on base, weakened-test + scope + NOGO checks; dispatcher merges only on PASS | fixer self-certifying; quiet test deletion |
| 5 | Termination logic | **partial** | timeout floor (t15), breaker trip/latch (t08/t09) present; documented re-arm CANNOT work (t10 xfail) → **issue #1** | wedged runs; nightly token burn — but recovery is currently manual-plus |
| 6 | Parsimony | **present** | ≤150-line PR cap (fix-one-issue.md §3, verify-one-pr.md check 5); ratchet measured nightly (gardener §3 + bin/scorecard.sh); regression = ATTENTION finding by design, not a hard gate | invisible scope creep and bloat |
| 7 | Entropy control | **partial** | logs 14 d + runs.jsonl 500 rows capped (t25); digest weekly rollup (gardener §1); `$STATE_DIR/evidence` UNBOUNDED → **issue #7** | harness output becoming the next mess |
| 8 | Memory hygiene | **present** | ledgers append-only w/ rollup; runs.jsonl capped; queue states per contracts/queue-state-machine.md, linted nightly | rewrite-drift; unbounded queues |
| 9 | Permission floor | **present** | floors in bash the agent can't renegotiate; ALL drilled tonight on the real config: `--check-nogo` rc 3 + revert, `--check-self-accept` rc 3 + strip (#1's label), `--check-queue-lint` rc 0; 35 hermetic tests; verify-live re-drills after every promotion | prompt-only safety; silent floor rot |
| 10 | Observability | **present** | runs.jsonl per-run cost/±lines rows (t20 tamper-check contract), stream-json transcripts in $STATE_DIR/logs (14 d), scorecard weekly, digest↔accounting reconciliation mandated (contracts/digest-format.md) | claims without numbers |

**Score: 7 present / 3 partial / 0 missing.** Every partial has a filed,
repro-carrying issue (#1, #6, #7) — the loop's own pipeline is the fix path.

### Metrics baseline (measured 2026-07-03, scorecard-2026-W27.json)

- LOC: product 2547 · tests 1369 · deps 0 · tests collected 35 (2 xfail
  pinning issues #1, #2)
- Queue: 0 loop-filed · 4 accepted action:loop bugs (#1–#4) · 2 cooling
  unaccepted bugs (#6, #7) · 1 open decision (#5) · 0 loop PRs
- Runs: 1 row (tonight's PAUSE drill, result=paused) · $0 cost ·
  0 nogo reverts in accounting
- Pipeline lane: 0 merged / 0 rejected (never run)
- Notification precision: not yet measurable (no autonomous nights)

### Phase 2 proposals (≤5, ranked; all already filed as issues)

1. Fix breaker re-arm (#1) — closes item 5. ~15-line wrapper diff.
2. Enforce Verify in queue lint (#6) — closes item 3. ~10-line diff + t07 case.
3. Evidence retention cap (#7) — closes item 7. ~5-line wrapper diff + t25 case.
4. (deferred) Hard-gate the LOC/deps/tests ratchet — today ATTENTION-only; revisit after a month of trend data.
5. (deferred) Notification-precision tally — needs ≥2 weeks of real alerts to score.

Next audit: ~2026-07-17 (biweekly during bootstrap), then monthly.
