#!/usr/bin/env bash
# T20 — diff accounting + cost: the wrapper's runs.jsonl row is the tamper
# check, so commits/±lines/cost must reflect what actually happened.
source "$(dirname "$0")/../lib.sh"
t_setup

t_agent_script <<'EOF'
printf 'a\nb\nc\n' >src/three.txt
grep -v '^# fixture-product' README.md >README.tmp && mv README.tmp README.md
git add -A
git commit -qm "loop: accounting probe"
EOF
t_run_loop orchestrator FAKE_AGENT_COST=1.23

t_assert_rc 0
t_assert_eq "$(t_row .result)" "success"
t_assert_eq "$(t_row .commits)" "1"
t_assert_eq "$(t_row .insertions)" "3"
t_assert_eq "$(t_row .deletions)" "1"
t_assert_eq "$(t_row .cost_usd)" "1.23"
t_assert_contains "$(t_runlog orchestrator)" 'cost=$1.23'
