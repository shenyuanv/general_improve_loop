#!/usr/bin/env bash
# T22 — digest guarantee: if the orchestrator dies before writing a digest,
# the wrapper leaves a stub so the morning is never silent.
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop orchestrator FAKE_AGENT_RC=1

t_assert_rc 1
t_assert_eq "$(t_row .result)" "error"
t_assert_exists "$(t_digest)"
t_assert_contains "$(t_digest)" "orchestrator FAILED before writing a digest (rc=1)"
t_assert_contains "$(t_digest)" "wrapper stub"
t_assert_contains "$T_CAP/notifications.log" "rc=1"
