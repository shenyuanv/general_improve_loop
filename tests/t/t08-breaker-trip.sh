#!/usr/bin/env bash
# T08 — circuit breaker trips after 3 consecutive failed runs: flag file
# written, notification sent, agent never invoked.
source "$(dirname "$0")/../lib.sh"
t_setup

t_seed_runs orchestrator error error error
t_run_loop orchestrator

t_assert_rc 1
t_assert_eq "$(t_row .result)" "breaker"
t_assert_exists "$T_STATE/breaker-orchestrator"
t_assert_contains "$T_STATE/breaker-orchestrator" "tripped after: error,error,error"
t_assert_contains "$T_CAP/notifications.log" "3 consecutive failed runs"
t_assert_absent "$T_CAP/agent-argv.txt"
