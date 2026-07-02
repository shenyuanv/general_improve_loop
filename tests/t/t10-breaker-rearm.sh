#!/usr/bin/env bash
# T10 — breaker re-arm: after the documented recovery (fix cause, `rm` the
# flag — OPERATIONS.md), a healthy next run must proceed and record success.
#
# XFAIL, PINS BUG S4 (run-loop.sh:119-128): rows written on trip are
# result="breaker" and excluded from the last-3 filter, and a tripped run
# never reaches the agent — so after `rm` the filter still sees
# error,error,error and re-trips instantly. The documented recovery cannot
# work. This test asserts the INTENDED behavior and is listed in
# tests/known-failures.txt until the bug is fixed.
source "$(dirname "$0")/../lib.sh"
t_setup

t_seed_runs orchestrator error error error
t_run_loop orchestrator
t_assert_rc 1
t_assert_exists "$T_STATE/breaker-orchestrator"

# The documented recovery:
rm "$T_STATE/breaker-orchestrator"
t_run_loop orchestrator

t_assert_rc 0                                   # healthy run must proceed
t_assert_eq "$(t_row .result)" "success"
t_assert_exists "$T_CAP/agent-argv.txt"         # agent actually ran
t_assert_absent "$T_STATE/breaker-orchestrator" # no instant re-trip
