#!/usr/bin/env bash
# T28 — unknown loop name: no roles/*/<loop>.md prompt ⇒ clean error, recorded.
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop no-such-loop

t_assert_rc 1
t_assert_eq "$(t_row .result)" "error"
t_assert_eq "$(t_row .loop)" "no-such-loop"
t_assert_contains "$(t_runlog no-such-loop)" "no agent prompt at"
t_assert_absent "$T_CAP/agent-argv.txt"
