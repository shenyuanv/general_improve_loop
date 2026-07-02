#!/usr/bin/env bash
# T03 — no-go revert FAILURE path: an uncommitted edit to the same fenced
# file makes `git revert` refuse; the wrapper must survive and log it.
#
# PINS BUG S5: the failed revert is not counted, so the WORST case —
# violation still in history — creates no DEMOTED and no notification.
# When that bug is fixed, flip the marked assertions to their intended
# versions (DEMOTED present, notification sent).
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
# ── current (buggy) behavior pinned below — see bug S5 ──
t_assert_eq "$(t_row .nogo_reverts)" "0"
t_assert_absent "$T_PROJ/ops/DEMOTED"
t_assert_not_contains "$T_CAP/notifications.log" "NO-GO VIOLATION"
