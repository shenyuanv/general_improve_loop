#!/usr/bin/env bash
# T37 — first run of a day (no digest yet) must not leak
# "No such file or directory" to the terminal: the wc -l digest
# pre-count's stderr redirect must take effect before the failing
# input redirect (GH#10).
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop orchestrator

t_assert_rc 0
t_assert_eq "$(t_row .result)" "success"
t_assert_not_contains "$T_CAP/run.out" "No such file or directory"
