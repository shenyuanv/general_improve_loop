# Harness audits (append-only; diff each entry against the previous)

## Architecture addendum — 2026-07-03 night — CI participant + roles/

**Track C (CI as participant).** Branch protection requires check `test`
on main (repo made public after a clean secret sweep — owner decision;
loop merges without `--admin` are server-refused, admin ops/ pushes bypass
with notice, confirmed live on push). Two self-filing finder workflows:
`nightly-drills` (ubuntu daily 02:17, gates + hermetic floor drill) and
`weekly-macos` (Sun, system bash 3.2 parity) — filing + dedup proven live
(#42 real catch of a workflow bug, #43 planted drill: filed once,
commented on repeat). Guardian watches their conclusions.

**Track R (role architecture).** `agents/` → `roles/{owner,manager,
orchestrator,developer,tester,reviewer}/` via git mv; loop names and all
state identifiers unchanged; wrapper/scheduler resolve `roles/*/<loop>.md`
by glob; every role carries a CHARTER.md (mission/authority/workspace/
KPIs); prompt-lint gained classes 10 (unique loop names) + 11 (charter
present, role has a loop). NEW manager role (Saturdays 08:33,
proposals-only): first supervised run scored the Focus bar, filed 🙋 #47
(Focus #2 should measure scheduled_success_rate — quota noise isn't code
failure) + design brief #48 (doc-contract lint; doc drift = modal defect,
4/8 open), exercised restraint per charter, workspace within caps, $5.01,
0 violations. Developer design lane wired knob-OFF (`develop_pipeline`,
action:develop ⇒ Design+Budget+Verify, verifier lane-split). Orchestrator
smoke on the new layout: contract-clean, 9 roles-path subagent
resolutions, 0 stale paths — and it caught the owner's own stale issue
body (#40 amended) plus fresh doc-drift (#45/#46).

Tests 47→48 (t48 proves glob resolution on the newest role). Live engine
`0cc1362`, 6 launchd jobs. Open for the owner: manager proposals #47/#48.

## Hardening addendum — 2026-07-03 evening — boundary closures + cycle 6

Post-convergence plan executed (owner Track O + loop cycle 6). The four
boundary classes the 5-cycle run exposed are closed:

- **Quota**: 429s now `result:"quota"` + `resets_at`, breaker-exempt,
  reset-time notification (#30 → PR #37; t46 pins 3×quota ⇒ no latch).
- **Identity**: `GH_AUTH_USER="shenyuanv"` pinned (mechanism from 8db3860);
  live flip-drill passed — active-account switch can no longer touch a run
  (#20 closed).
- **Contention**: pins are per-test marker files (`tests/known-failures.d/`,
  #34 → PR #38) — concurrent flips conflict-free; verifier stale-PASS now
  closes+deletes-branch (write-policy lane extended) instead of the PR#13
  dead-end.
- **Remote blindness**: post-run floors scan the fetched tip (#25 → PR #39).
  L4 drill exposed that the `--check-nogo` DRILL mode still scans local-only
  → #41 filed (the floor is wired; the audit tooling isn't).
- **Mechanization**: `bin/funnel.sh` computes the funnel (operator annotates);
  first mechanized digest was also the **first 🟢 GREEN digest**.
- **Drills run for real**: staged bad-deploy → verify-live RED → rollback →
  green (#8 closed; promote/rollback/promote triplet in promotions.jsonl)
  → `deploy: auto` flipped. Defense-in-depth proven in anger the same
  evening: PRs #37+#38 collided on test id t46 — guard t43 (loop-built)
  went red on merged main, verify-live blocked the promotion, rollback
  restored green, owner red-gate-renamed, #40 files the dispatcher-side
  prevention.
- **Steady state entered**: launchd schedule installed (03:33→06:03,
  e2e-tester Sundays); queue = 5 cooling loop-filed items, 0 orphans,
  0 decisions open; tests 47 (0 pins); LOC 2723/1823; deps 0.

Next audit: full 10-item re-score ~2026-07-17.

## Convergence run — 2026-07-03 — 5 supervised self-improvement cycles

First end-to-end dogfood: the harness ran its full relay against its own
repo 5 times, each cycle promoted into the live checkout the next cycle
executed. Evidence the self-improvement is real and converging:

- **13 issues found→fixed→merged→promoted, zero human code edits**:
  #1 #2 #3 #4 #6 #7 #9 #10 #11 #15 #16 #21 #22. All via the
  fixer→adversarial-verifier→CI→merge pipeline.
- **Engine trajectory** (7 gated promotions, each verify-live green before
  the next cycle): 57a9968 → e8de994 → a51444e → 6eb6b6a → 8db3860 →
  95fee08 → 5b743a3.
- **The loop closes, observed**: the e2e adoption journey FAILED
  docs-honesty in cycle 1 (PARTIAL), and after that fix merged+promoted the
  same journey PASSed in cycle 3 — a defect the harness found, fixed, and
  re-verified on itself.
- **It fixes its own audit gaps**: baseline #0 flagged items 3 and 7 as
  partial (queue-lint missing Verify enforcement; unbounded evidence dir).
  The loop filed those as #6/#7 and closed both in cycle 5.
- **It hardens against bug classes, not instances**: caught a regression it
  introduced itself (#21 duplicate test id) and added a uniqueness guard
  test; converted a manual branch-prune into a mechanical floor (#15);
  found its own operational bug (#30: rate-limit 429 miscounted as error).
- **Ratchet**: tests 35→43 (all green, known-failures pins 2→0);
  product LOC 2554, deps 0.
- **Reliability**: 21 runs, 17 success / 3 error / 1 paused-drill. All 3
  errors were external Fable-5 quota exhaustion (429), not harness faults —
  the wrapper recorded each honestly and opened nothing; #22/#30 (loop-
  found) address the accounting so quota pauses stop skewing the rate.
  0 no-go reverts, 0 self-accept strips, 0 breaker trips, no DEMOTED/BLOCKED.
- **Cost**: ~$155 across all cycles (elevated by running stages back-to-back
  and re-driving rate-limited stages; a nightly cadence would be far lower).

Still open (named owners, no orphans): #25 (floor-blindness, rolled by the
3/night cap — first pick next cycle); decisions #5 #20 #29 #30; operator
drill #8. Next full 10-item audit due ~2026-07-17 per docs/AUDIT-CHECKLIST.md.

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
