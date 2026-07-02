#!/usr/bin/env bash
# T14 — ops/PAUSE kill switch: nothing runs, row says paused, exit 0.
source "$(dirname "$0")/../lib.sh"
t_setup

echo "stopping for the weekend" >"$T_PROJ/ops/PAUSE"
t_run_loop orchestrator

t_assert_rc 0
t_assert_eq "$(t_row .result)" "paused"
t_assert_eq "$(t_row .loop)" "orchestrator"
t_assert_absent "$T_CAP/agent-argv.txt"                  # agent never invoked
t_assert_contains "$(t_runlog orchestrator)" "PAUSED: stopping for the weekend"
