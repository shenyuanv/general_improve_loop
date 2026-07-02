#!/usr/bin/env bash
# T27 — exit-code fidelity: the agent's rc propagates through the wrapper
# and into the accounting row and failure notification.
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop e2e-user FAKE_AGENT_RC=7

t_assert_rc 7
t_assert_eq "$(t_row .rc)" "7"
t_assert_eq "$(t_row .result)" "error"
t_assert_eq "$(t_row .loop)" "e2e-user"
t_assert_contains "$T_CAP/notifications.log" "rc=7"
