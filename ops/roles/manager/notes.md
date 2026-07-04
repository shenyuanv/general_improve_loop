# Manager strategy notes (≤150 lines; REWRITTEN each run, never grown)

Written 2026-07-04 by run 20260704-083300 (second manager pass; first in
the scheduled Saturday 08:33 slot).

## Where the project is

Bootstrap → steady-state transition happened THIS WEEK:
- First fully scheduled relay night (07-04 03:33–06:03 local): 4/4
  success, $19.99 total — the Focus #2 meter (decided #47-A) is live and
  green on day one.
- The auto-deploy floor bit for real, unattended, for the first time:
  04:33 journey promoted c292a92, verify-live went red (#50 env leak),
  one-attempt rollback restored 27553bf, re-verified healthy. Recovery is
  exercised, not theoretical (3rd real rollback overall).
- Both first-week manager proposals were accepted AND enacted within a
  day (#47 Option A; #48 → doc-contract lint 2c6bd77). Acceptance 2/2 —
  calibration: proposals grounded in a single decided premise + exact
  enacting edit land; keep caps under-used.

## Focus-bar picture (scorecard-2026-W27 07-03 19:38Z + runs.jsonl 06:03Z)

1. Floors: GREEN, and stronger than last week — 0 reverts / 0 strips /
   0 trips, PLUS the deploy floor's first live catch (above). Journey
   floor drills PASS ×4 consecutive.
2. Relay: GREEN day one — scheduled 4/4 (headline 90% = quota noise per
   closed #47). Scorecard's scheduled_success_rate was still null at
   generation (predates the relay); the 07-04 gardener refresh MUST show
   it non-null — standing watch, file if not.
3. Pipeline: THE red-trending item. Pins 0 / collected 48 hold, but
   merges 0 in ~30 h while open bugs 4→6, all unaccepted+cooling. The
   07-05 05:03 fixer faces 6 eligible vs cap 3, and #50 (LOOP_TIMEOUT_S
   leak) reddens gates for every SCHEDULED fix/verify subagent — the
   lane must fix the bug that degrades it. Proposed 🙋 #52 (accept #50
   first / one-night cap raise / nothing / interactive). Decision window
   closes 2026-07-04T21:03Z.
4. Cost: GREEN — all loops ≤1.38× own median; first scheduled day ~$20
   vs bootstrap $190–230/day. Watch line stands: a normal scheduled day
   >$60 is a new trend → 🙋 (cost knob or cadence).
5. Hygiene: GREEN — doc-contract lint (from #48) green night one; drift
   filings dropped from 6-in-48h to 1 (#51, journey-found, queued). Deps
   0, pins 0. #48's acceptance metric (drift → ~0) is tracking right.

## Open proposals to track next run

- #52 (🙋 triage steer) — record the Option; grade my recommendation:
  if A/B/D, #50 should be merged+live by 07-05 morning and the 07-05
  verifier should show 0 spurious `changes-requested`. If C and spurious
  rejects appear, the verdict writes itself. If the owner instead lets
  the fixer self-order and it happens to pick #50 first, note that the
  🙋 was cheap insurance, not waste.

## Standing watches (verify, don't duplicate — owners named)

- Cap/backlog VOLUME watch stays the ANALYST's: escalate a cap 🙋 only
  if backlog still grows after 07-05. #52 is the ORDERING decision
  (new evidence: #50's lane interaction), not that volume watch. If
  backlog >10 next run with no analyst 🙋, ask why in the verdict.
- scheduled_success_rate non-null in the next scorecard refresh (else
  the --scheduled reinstall didn't take — orchestrator files).
- nightly-drills GitHub cron has never fired as `schedule` (all 6 runs
  manual dispatch); guardian escalates to action:operator if still zero
  by 07-05.
- e2e-tester FIRST sweep Sun 07-05 05:33 local (weekday 0). Next manager
  verdict must cite its first tester.jsonl rows. Note: it runs with
  timeout 5400 under a scheduled trigger — if #50 is still unfixed by
  then, expect leak-class noise in its gate-adjacent stages; don't count
  that against the tester itself.
- Journey duration_s growth: 175→292→400→970 s (latest inflated by the
  deploy+rollback drama; ruled latency metric 58·57·64·85 s ≤1.3×
  median). Analyst flags if duration doubles again with no new stages.
- Combination-only red main (#40 premise): 2nd occurrence ⇒ orchestrator
  files the combined-tree gate. Do NOT re-propose before then.

## Decision register premises (closed 🙋 — re-check each run)

- #5 GIT_REMOTE deleted: holds (0 refs, prompt-lint 0).
- #20 identity pin: holds (shenyuanv via GH_TOKEN, saster985 inactive,
  0 flips since 07-03). Breaks only if a flip recurs DESPITE the pin.
- #47 Option A (scheduled basis): premise armed and so far intact —
  first scheduled night had no quota event; breaks if a SCHEDULED run
  dies on quota (then the basis itself needs a re-look, new 🙋 ref #47).
- #8/deploy:auto: premise STRENGTHENED — verify-live caught a real bad
  promote 07-04 04:33 and rollback restored green unattended.

## Calibration

Second run. One 🙋 filed (#52; caps allow 2+1), no design brief (top
items already queued as bugs), no parsimony nomination (youngest
mechanisms 1 day old; auto-deploy justified itself). Acceptance history
2/2. Audit fresh (07-03); next audit tickler due if HARNESS_AUDIT.md is
silent past ~2026-07-17 — the 07-18 manager run owns that.
