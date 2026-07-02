#!/usr/bin/env bash
# T13 — stale lock reclaim: a dead pid (and an empty pid file) must not
# block the run; the lock is released afterwards by the trap.
source "$(dirname "$0")/../lib.sh"
t_setup

# (a) reaped pid
sleep 0.01 &
dead=$!
wait "$dead"
mkdir -p "$T_STATE/lock/orchestrator"
echo "$dead" >"$T_STATE/lock/orchestrator/pid"
t_run_loop orchestrator
t_assert_rc 0
t_assert_eq "$(t_row .result)" "success"
t_assert_exists "$T_CAP/agent-argv.txt"
t_assert_absent "$T_STATE/lock/orchestrator"   # trap released it

# (b) empty pid file
rm -f "$T_CAP/agent-argv.txt"
mkdir -p "$T_STATE/lock/orchestrator"
: >"$T_STATE/lock/orchestrator/pid"
t_run_loop orchestrator
t_assert_rc 0
t_assert_exists "$T_CAP/agent-argv.txt"
t_assert_absent "$T_STATE/lock/orchestrator"
