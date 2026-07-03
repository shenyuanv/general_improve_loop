# Self-hosting — the loop improving the loop

This engine is dogfooded on itself: the repo is its own target project, and
every merged improvement is *deployed* before the next relay runs on it.
This document is the intent; `ops/loop.config.sh` is the wiring.

## Topology: two checkouts, gated promotion

```
~/sourcecode/general_improve_loop            ~/.improve-loop/general_improve_loop/
  the TARGET (PROJECT_DIR)                     ├── live/    ← the ENGINE (ILOOP_ROOT)
  what the loops edit via PRs                  │    what launchd/cron actually executes
  ops/ digests · ledgers · config              └── state: logs, runs.jsonl, locks,
                                                    promotions.jsonl, evidence

fixer PR → pr-verifier (adversarial) + CI → merge to origin/main
   → selfhost/promote.sh   (ff-only the live checkout to origin/main)
   → selfhost/verify-live.sh (live runs ITS OWN suite + a floor drill)
   → on failure: selfhost/rollback.sh (reset live to the recorded prior sha)
   → the next relay executes the improved engine; the nightly journey
     re-tests it like a fresh adopter — the loop closes ⟳
```

**The loop never runs from the tree it edits.** A change reaches execution
only after fixer → verifier → CI → promote → verify-live, and promotion is
reversible from `promotions.jsonl`.

## The rails, reinterpreted

The design law "the harness never edits its own rails" maps here to:

| Rail | Protection |
|---|---|
| the live checkout | outside the repo; only `selfhost/promote.sh`/`rollback.sh` write it |
| `selfhost/` (promote/verify/rollback/drift + e2e rubric) | `NOGO_PATHS` — the loop cannot soften its own promotion gate or grading bar |
| `ops/DIRECTION.md`, `ops/loop.config.sh` | `NOGO_PATHS` (standard) |
| `.github/` (CI) | `NOGO_PATHS` + the verifier hard-rejects CI-workflow diffs |
| `.gitattributes`, `.gitignore` | `NOGO_PATHS` (standard) |

Everything else — `bin/`, `roles/`, `contracts/`, `docs/`, `templates/`,
`tests/` — is ordinary product code the loop may change through the PR lane.

## Deploy-stage mapping (in ops/loop.config.sh)

```bash
DEPLOY_DRIFT_CMD     selfhost/drift.sh          # 0 current · 1 drifted · 2 can't answer
DEPLOY_CMD           selfhost/promote.sh …      # clone-or-ff-only; records prior sha
DEPLOY_VERIFY_CMD    selfhost/verify-live.sh    # live's own tests + prompt-lint +
                                                #   shellcheck + no-go floor drill
DEPLOY_ROLLBACK_CMD  selfhost/rollback.sh       # reset live to recorded prior sha
```

Start with the DIRECTION knob `deploy: ack` (every promotion is a
Needs-you item); flip to `auto` only after watching one staged bad deploy
get caught by verify-live and rolled back.

## Known-failures contract (fail-before/pass-after, mechanically)

A marker file `tests/known-failures.d/<test-name>` pins an OPEN bug (its
content is the tracking issue ref): the test reports `xfail` while the bug
exists, and a pinned test that *passes* fails the whole suite (`XPASS`).
So the PR that fixes a pinned bug must also `git rm` its marker — the
suite itself enforces fail-before/pass-after, and the pr-verifier sees it
as a test-count/gate diff. One marker file per pin keeps concurrent pin
flips conflict-free (issue #34).

## Measurement

- Per change: `GATES` = `tests/run.sh` + `tests/prompt-lint.sh` + shellcheck
  (also CI on every PR).
- Per run/week: `bin/scorecard.sh ops/loop.config.sh` →
  `ops/metrics/scorecard-YYYY-Www.json` (run success %, cost, funnel,
  merge latency, floor violations, LOC/deps/tests ratchet).
- Monthly-ish: docs/AUDIT-CHECKLIST.md → `ops/HARNESS_AUDIT.md` (fixed
  10-item score; entry #0 is the pre-loop baseline).

Convergence bar lives in `ops/DIRECTION.md` Focus — rolling 14 days: zero
floor violations, zero breaker trips, ≥95 % run success, zero funnel
orphans, digest↔runs.jsonl reconciliation, audit ≥9/10, cost flat-or-down,
and self-defects found trending down while the test count trends up.

## Runbook

```bash
CFG=~/sourcecode/general_improve_loop/ops/loop.config.sh
bash selfhost/drift.sh                       # is live behind merged main?
bash selfhost/promote.sh ~/sourcecode/general_improve_loop
bash selfhost/verify-live.sh                 # must be green after every promote
bash selfhost/rollback.sh                    # undo the last promote
tail -5 ~/.improve-loop/general_improve_loop/promotions.jsonl | jq .
bash bin/scorecard.sh "$CFG"                 # the weekly numbers
```

First-ever promote requires the repo to have an `origin` remote (the live
checkout clones from it). A dirty live checkout is a tamper signal: promote
refuses (exit 3), rollback quarantines the evidence first, verify-live fails.
