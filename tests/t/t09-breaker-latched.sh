#!/usr/bin/env bash
# T09 — a latched breaker short-circuits the run before any token burn.
source "$(dirname "$0")/../lib.sh"
t_setup

echo "2026-01-01 tripped after: error,error,error" >"$T_STATE/breaker-orchestrator"
t_run_loop orchestrator

t_assert_rc 1
t_assert_eq "$(t_row .result)" "breaker"
t_assert_contains "$(t_runlog orchestrator)" "breaker latched"
t_assert_contains "$T_CAP/notifications.log" "breaker latched"
t_assert_absent "$T_CAP/agent-argv.txt"
t_assert_exists "$T_STATE/breaker-orchestrator"   # latch persists
