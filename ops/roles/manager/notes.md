# Manager strategy notes (≤150 lines; REWRITTEN each run, never grown)

Written 2026-07-03 by run 20260703-195446 (first manager pass — ran Friday,
supervised; scheduled slot is Saturdays 08:33).

## Where the project is

Bootstrap is essentially COMPLETE after ~2 days of operation:
- 16 loop PRs merged in the window (median 0.2 h to merge); every seeded
  baseline bug (#1–#4, #6, #7) plus 10 organic findings fixed and verified.
- All three 🙋/operator standing items closed by the owner TODAY: #5
  (GIT_REMOTE deleted, Option B), #20 (gh identity pinned via GH_AUTH_USER
  + GH_TOKEN — premise verified live), #8 (rollback drill run for real).
- `deploy` flipped ack→auto 2026-07-03 after the staged bad-deploy drill;
  the auto lane has NOT yet fired in production (live == main all night).
  First unattended auto-promotion is a watch item, not a worry.
- Track R (roles/ architecture + this manager role) and Track C (CI finder
  workflows) landed by the owner 2026-07-03.

## Focus-bar picture (numbers as of scorecard-2026-W27 + 19:34 digest)

1. Floors: GREEN. 0 reverts / 0 strips / 0 trips; drills exit 3/0 correctly
   (journey-proven twice); rollback exercised twice live.
2. Relay: headline 87% vs ≥95% bar, but all 3 errors = environmental
   quota-429, 0 code-caused; scheduled relay 100% per digests. The bar
   MEASURES wrong → proposed 🙋 #47 (Option A: scheduled_success_rate
   basis + scheduler reinstall so trigger rows exist). If owner picks C,
   quota pressure becomes a real red — watch cadence/cost then.
3. Pipeline: GREEN AT THE BAR — pins 2→0 (known-failures.d/ empty),
   collected 35→48, xpass 0. Watch that it STAYS green with collected
   still rising; a re-pin is normal, a falling collected is blindness.
4. Cost: within 2× medians everywhere (max 1.38×). $189.54/24 h is
   bootstrap volume (24 runs vs ~5 scheduled/day). Expect steady-state
   $30–50/day; if a normal scheduled day opens >$60 total, that is a new
   trend — consider a 🙋 (cost knob or cadence).
5. Hygiene: TRENDING WRONG — doc drift is the modal defect (4 of 8 open:
   #29 #36 #45 #46; 6 findings in 48 h, all found post-merge). Proposed
   design brief #48 (doc-contract lint in prompt-lint). Deps 0 holds.

## Open proposals to track next run

- #47 (🙋, Focus #2 basis) — record Option chosen; if A, verify
  scheduled_success_rate is non-null in the next scorecard.
- #48 (design brief, doc-contract lint) — unaccepted by design; if owner
  runs it, drift filings should drop to ~0 — that's the acceptance metric.
  If declined and drift keeps outpacing fixes, the NEW evidence threshold
  for re-raising is: drift filings still ≥2/week two weeks from now.

## Standing watches inherited from the loops (do not duplicate — verify)

- Backlog vs cap: 07-04 05:03 fixer is a guaranteed no-op (all 8 open
  cooling past it); 07-05 fixer faces 8 eligible vs MAX_FIXES_PER_NIGHT=3.
  Analyst escalates to a 🙋 cap decision only if backlog still grows after
  07-05. Manager: if that 🙋 hasn't appeared by next run and open>10, ask
  why in the verdict.
- Combination-only red main: happened once (t46, 17:31Z incident); owner
  post-mortem #40 scoped prevention to dispatcher id pre-assignment.
  Second occurrence ⇒ the orchestrator files the combined-tree gate. Do
  NOT re-propose it before then (#40 is a same-day owner decision).
- First real auto-deploy: expect within days once a fix PR merges. Check
  deploys.jsonl for a loop-triggered row; #44 (deploys.jsonl reconcile)
  covers the manual-promote trace gap.
- e2e-tester first sweep Sunday 2026-07-05; manager verdict next week
  should cite its first rows.

## Decision register premises (closed 🙋 — re-check each run)

- #5 GIT_REMOTE deleted: holds (prompt-lint warns 1→0).
- #20 identity pin: holds (shenyuanv active via GH_TOKEN; saster985
  present-inactive). Premise breaks if a flip recurs DESPITE the pin.
- #8/deploy:auto: rollback proven; premise breaks on a failed auto-deploy
  that verify-live misses.

## Calibration

First run — no acceptance-rate history. Two proposals filed (cap is 2+1);
chose restraint elsewhere: no parsimony nomination (2 days of data), no
cap-bump 🙋 (analyst's watch owns the trigger), no re-file of the
combined-tree gate (owner decided same-day). Next audit due ~2026-07-17 —
the 07-18 manager run must tickle it if HARNESS_AUDIT.md is silent by then.
