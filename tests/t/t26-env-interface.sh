#!/usr/bin/env bash
# T26 — the env interface the prompts rely on: verbatim AGENT.md piped via
# -p, RUNNER_FLAGS appended, all five ILOOP_* vars set, cwd = PROJECT_DIR.
source "$(dirname "$0")/../lib.sh"
t_setup

start_epoch="$(date +%s)"
t_run_loop orchestrator
t_assert_rc 0

argv="$T_CAP/agent-argv.txt"
t_assert_eq "$(head -1 "$argv")" "-p"
t_assert_contains "$argv" "orchestrator — the nightly conductor"   # real prompt text
grep -qx -- "--stub" "$argv" || t_fail "RUNNER_FLAGS not passed verbatim"

envf="$T_CAP/agent-env.txt"
t_assert_contains "$envf" "ILOOP_ROOT=$T_REPO"
t_assert_contains "$envf" "ILOOP_CONFIG=$T_CFG"
t_assert_contains "$envf" "ILOOP_STATE=$T_STATE"
t_assert_contains "$envf" "PWD=$T_PROJ"
grep -Eq '^ILOOP_RUN_ID=[0-9]{8}-[0-9]{6}$' "$envf" || t_fail "bad ILOOP_RUN_ID"

deadline="$(grep '^ILOOP_DEADLINE_EPOCH=' "$envf" | cut -d= -f2)"
expected=$((start_epoch + 6000 - 300))     # default LOOP_TIMEOUT_S − 5 min
drift=$((deadline - expected))
(( drift >= 0 && drift <= 60 )) || t_fail "deadline drift $drift s (deadline=$deadline expected≈$expected)"
