#!/usr/bin/env bash
# T44 — scorecard success_rate: intentional "paused" rows (PAUSE drills /
# owner pauses) leave the success-rate denominator, a scheduled-only rate
# is reported from the trigger field, and run-loop.sh records
# trigger:"scheduled"|"manual" per its invocation (#22).
source "$(dirname "$0")/../lib.sh"
t_setup

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
seed() { # <result> <trigger> — recent row so the 14d cutoff keeps it
  printf '{"loop":"orchestrator","started":"%s","ended":"%s","rc":0,"timed_out":false,"cost_usd":0,"commits":0,"insertions":0,"deletions":0,"nogo_reverts":0,"log":"seeded","result":"%s","trigger":"%s"}\n' \
    "$NOW" "$NOW" "$1" "$2" >>"$T_STATE/runs.jsonl"
}
mkdir -p "$T_STATE"

# The #22 shape: every scheduled run green, one intentional PAUSE drill,
# one off-schedule owner run that failed.
seed success scheduled
seed success scheduled
seed success scheduled
seed paused  scheduled
seed error   manual

t_env bash "$T_REPO/bin/scorecard.sh" "$T_CFG" >"$T_CAP/scorecard.out" 2>&1 \
  || t_fail "scorecard.sh failed: $(tail -5 "$T_CAP/scorecard.out")"
CARD="$(ls "$T_PROJ"/ops/metrics/scorecard-*.json | head -1)"

t_assert_eq "$(jq -r .runs.window_runs "$CARD")" "5" "paused row still counted in window_runs"
t_assert_eq "$(jq -r .runs.results.paused "$CARD")" "1" "paused row still visible in results"
# 3 success / 4 graded (paused excluded) — was 3/5=60 when drills counted.
t_assert_eq "$(jq -r .runs.success_rate "$CARD")" "75" "paused must leave the denominator"
# scheduled relay alone: 3/3, the off-schedule failure does not pollute it.
t_assert_eq "$(jq -r .runs.scheduled_success_rate "$CARD")" "100" "scheduled-only rate"

# run-loop.sh records the trigger. PAUSE makes both runs cheap (no agent).
echo "drill" >"$T_PROJ/ops/PAUSE"
set +e
t_env bash "$T_REPO/bin/run-loop.sh" --scheduled orchestrator "$T_CFG" >"$T_CAP/run.out" 2>&1
RC=$?
set -e
[[ "$RC" == 0 ]] || t_fail "run-loop --scheduled rc=$RC, want 0"
t_assert_eq "$(t_row .trigger)" "scheduled"
t_assert_eq "$(t_row .result)" "paused"

t_run_loop orchestrator
t_assert_rc 0
t_assert_eq "$(t_row .trigger)" "manual" "default trigger is manual"
