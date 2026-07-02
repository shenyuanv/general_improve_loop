#!/usr/bin/env bash
# T12 — singleton lock: a live holder makes the second invocation exit 0
# quietly, without a runs.jsonl row, leaving the holder's lock intact.
source "$(dirname "$0")/../lib.sh"
t_setup

pid="$(t_spawn sleep 30)"
mkdir -p "$T_STATE/lock/orchestrator"
echo "$pid" >"$T_STATE/lock/orchestrator/pid"

t_run_loop orchestrator

t_assert_rc 0
t_assert_contains "$(t_runlog orchestrator)" "already running (pid $pid)"
t_assert_absent "$T_CAP/agent-argv.txt"
t_assert_absent "$T_STATE/runs.jsonl"              # early exit records nothing
t_assert_exists "$T_STATE/lock/orchestrator/pid"   # holder's lock untouched
