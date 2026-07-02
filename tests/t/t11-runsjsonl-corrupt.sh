#!/usr/bin/env bash
# T11 — corrupt runs.jsonl tolerance: garbage lines must not disable (or
# false-trip) the breaker; the run proceeds normally.
source "$(dirname "$0")/../lib.sh"
t_setup

mkdir -p "$T_STATE"
printf 'this is not json\n{"broken": \n' >>"$T_STATE/runs.jsonl"
t_seed_runs orchestrator error success error
printf '\x00\x01 binary-ish garbage line\n' >>"$T_STATE/runs.jsonl"

t_run_loop orchestrator

t_assert_rc 0
t_assert_eq "$(t_row .result)" "success"
t_assert_exists "$T_CAP/agent-argv.txt"
t_assert_absent "$T_STATE/breaker-orchestrator"
