#!/usr/bin/env bash
# T24 — fan-out silence: a clean run that appends no NOTIFY lines sends
# nothing at all (no duplicate/starved notifications).
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop orchestrator

t_assert_rc 0
t_assert_eq "$(t_row .result)" "success"
t_assert_line_count "$T_CAP/notifications.log" 0
