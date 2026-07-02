#!/usr/bin/env bash
# T17 — preflight abort: dead agent-runner auth (probe emits no OK, or
# fails outright) is the one failure only a human login fixes.
source "$(dirname "$0")/../lib.sh"
t_setup

t_config_set "RUNNER_AUTH_PROBE='echo NOPE'"
t_run_loop orchestrator
t_assert_rc 1
t_assert_eq "$(t_row .result)" "preflight_abort"
t_assert_contains "$T_CAP/notifications.log" "agent runner auth dead"
t_assert_absent "$T_CAP/agent-argv.txt"

t_config_set "RUNNER_AUTH_PROBE='false'"
t_run_loop orchestrator
t_assert_rc 1
t_assert_eq "$(t_row .result)" "preflight_abort"
