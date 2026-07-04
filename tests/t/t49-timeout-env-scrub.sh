#!/usr/bin/env bash
# T49 — LOOP_TIMEOUT_S is scheduler→wrapper plumbing, not agent interface
# (#50): the wrapper must honor the knob (deadline, kill timer) but NOT
# leak it into the agent's environment, where any nested run-loop.sh (the
# hermetic suite in GATES) would inherit the OUTER loop's timeout. Also
# pins lib.sh's own hermeticity: an ambient LOOP_TIMEOUT_S must not reach
# the wrapper unless a test passes it explicitly.
source "$(dirname "$0")/../lib.sh"
t_setup

# Scenario runs inside the agent process: record whether the var leaked.
t_agent_script <<'EOF'
if [[ -n "${LOOP_TIMEOUT_S+x}" ]]; then
  printf 'leaked=%s\n' "$LOOP_TIMEOUT_S" >"$CAP/timeout-leak.txt"
else
  printf 'clean\n' >"$CAP/timeout-leak.txt"
fi
EOF

# 1. Explicit knob: wrapper honors 5400 for the deadline, agent env is clean.
start_epoch="$(date +%s)"
t_run_loop orchestrator LOOP_TIMEOUT_S=5400
t_assert_rc 0
t_assert_eq "$(cat "$T_CAP/timeout-leak.txt")" "clean" "LOOP_TIMEOUT_S leaked into agent env"
deadline="$(grep '^ILOOP_DEADLINE_EPOCH=' "$T_CAP/agent-env.txt" | cut -d= -f2)"
expected=$((start_epoch + 5400 - 300))
drift=$((deadline - expected))
(( drift >= 0 && drift <= 60 )) || t_fail "deadline drift $drift s (deadline=$deadline expected≈$expected)"

# 2. Ambient var (exported, NOT passed to t_run_loop): lib.sh scrubs it, so
# the wrapper sees the 6000 default — the suite is hermetic under a wrapped
# ancestor whose timeout ≠ 6000.
export LOOP_TIMEOUT_S=5400
start_epoch="$(date +%s)"
t_run_loop orchestrator
unset LOOP_TIMEOUT_S
t_assert_rc 0
t_assert_eq "$(cat "$T_CAP/timeout-leak.txt")" "clean" "ambient LOOP_TIMEOUT_S leaked into agent env"
deadline="$(grep '^ILOOP_DEADLINE_EPOCH=' "$T_CAP/agent-env.txt" | cut -d= -f2)"
expected=$((start_epoch + 6000 - 300))
drift=$((deadline - expected))
(( drift >= 0 && drift <= 60 )) || t_fail "ambient var reached wrapper: drift $drift s (deadline=$deadline expected≈$expected)"
