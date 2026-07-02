#!/usr/bin/env bash
# T15 — hard timeout: a wedged agent is killed at LOOP_TIMEOUT_S; rc 124 is
# recorded as result=timeout with timed_out=true and a loud notification.
source "$(dirname "$0")/../lib.sh"
t_setup

t_agent_script <<'EOF'
exec sleep 10
EOF
t_run_loop orchestrator LOOP_TIMEOUT_S=2

t_assert_rc 124
t_assert_eq "$(t_row .result)" "timeout"
t_assert_eq "$(t_row .timed_out)" "true"
t_assert_contains "$T_CAP/notifications.log" "TIMED OUT after 2s"
