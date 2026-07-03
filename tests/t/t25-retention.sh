#!/usr/bin/env bash
# T25 — retention caps: logs older than 14 days deleted, runs.jsonl trimmed
# to its newest 500 rows (plus this run's), evidence entries older than
# 30 days removed (fresh ones kept).
source "$(dirname "$0")/../lib.sh"
t_setup

mkdir -p "$T_STATE/logs"
touch -t 202601010000 "$T_STATE/logs/old1.log" "$T_STATE/logs/old2.log"
touch "$T_STATE/logs/fresh.log"
mkdir -p "$T_STATE/evidence/e2e-user-2020-01-01" "$T_STATE/evidence/fresh-run"
touch "$T_STATE/evidence/e2e-user-2020-01-01/journey.txt"
touch -t 202001010000 "$T_STATE/evidence/e2e-user-2020-01-01"
touch "$T_STATE/evidence/fresh-run/journey.txt"
for ((i = 1; i <= 510; i++)); do
  printf '{"loop":"other","i":%d,"result":"success"}\n' "$i"
done >>"$T_STATE/runs.jsonl"

t_run_loop orchestrator

t_assert_rc 0
t_assert_absent "$T_STATE/logs/old1.log"
t_assert_absent "$T_STATE/logs/old2.log"
t_assert_exists "$T_STATE/logs/fresh.log"
t_assert_absent "$T_STATE/evidence/e2e-user-2020-01-01"
t_assert_exists "$T_STATE/evidence/fresh-run/journey.txt"
t_assert_line_count "$T_STATE/runs.jsonl" 501
t_assert_eq "$(head -1 "$T_STATE/runs.jsonl" | jq -r .i)" "11"   # rows 1–10 trimmed
t_assert_eq "$(t_row .result)" "success"
