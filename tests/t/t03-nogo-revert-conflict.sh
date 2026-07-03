#!/usr/bin/env bash
# T03 — no-go revert FAILURE path: an uncommitted edit to the same fenced
# file makes `git revert` refuse; the wrapper must survive, log it, and
# escalate at least as loudly as a successful revert — the violation is
# still in history, so it is counted, creates ops/DEMOTED, and notifies
# with "needs human" wording (fixed bug S5, issue #3).
source "$(dirname "$0")/../lib.sh"
t_setup

t_agent_script <<'EOF'
echo "tampered by agent" >>ops/DIRECTION.md
git add ops/DIRECTION.md
git commit -qm "loop: tamper with DIRECTION"
echo "dirty uncommitted edit" >>ops/DIRECTION.md   # blocks the revert
EOF
t_run_loop orchestrator

t_assert_rc 0                                       # wrapper must not crash
t_assert_contains "$(t_runlog orchestrator)" "no-go revert FAILED"
t_assert_contains "$T_PROJ/ops/DIRECTION.md" "tampered by agent"  # still tampered!
# ── intended behavior (was pinned buggy: count 0, no DEMOTED, no notify) ──
t_assert_eq "$(t_row .nogo_reverts)" "1"            # failed revert is counted
t_assert_exists "$T_PROJ/ops/DEMOTED"
t_assert_contains "$T_PROJ/ops/DEMOTED" "needs human"
t_assert_contains "$T_CAP/notifications.log" "NO-GO VIOLATION"
t_assert_contains "$T_CAP/notifications.log" "needs human"
