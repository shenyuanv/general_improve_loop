#!/usr/bin/env bash
# T21 — cost parse degradation: no claude-style result line ⇒ cost 0 (pins
# the documented non-claude-runner behavior); multiple result lines ⇒ the
# LAST one wins.
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop orchestrator FAKE_AGENT_NO_RESULT=1
t_assert_rc 0
t_assert_eq "$(t_row .cost_usd)" "0"

t_agent_script <<'EOF'
printf '{"type":"result","subtype":"success","total_cost_usd":9.99}\n'
EOF
t_run_loop orchestrator            # scenario line first, final line 0.42 last
t_assert_rc 0
t_assert_eq "$(t_row .cost_usd)" "0.42"
