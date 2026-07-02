#!/usr/bin/env bash
# T10 — breaker re-arm: after the documented recovery (fix cause, `rm` the
# flag — OPERATIONS.md), a healthy next run must proceed and record success.
#
# Pinned bug S4 (fixed): rows written on trip are result="breaker" and were
# excluded from the last-3 filter, so after `rm` the filter still saw
# error,error,error and re-tripped instantly. Breaker rows now count as
# reset markers in the window, so recovery proceeds and only 3 NEW failures
# can re-trip.
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
