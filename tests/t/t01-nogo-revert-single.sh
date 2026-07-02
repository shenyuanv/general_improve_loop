#!/usr/bin/env bash
# T01 — no-go revert floor: a commit touching a NOGO path is reverted,
# DEMOTED is created, and the violation is notified and accounted.
source "$(dirname "$0")/../lib.sh"
t_setup

before="$(cat "$T_PROJ/ops/DIRECTION.md")"
t_agent_script <<'EOF'
echo "tampered by agent" >>ops/DIRECTION.md
git add ops/DIRECTION.md
git commit -qm "loop: tamper with DIRECTION"
EOF
t_run_loop orchestrator

t_assert_rc 0
t_assert_eq "$(t_row .nogo_reverts)" "1"
t_assert_eq "$(cat "$T_PROJ/ops/DIRECTION.md")" "$before" "file restored"
t_assert_contains "$(t_git log -1 --format=%s)" "Revert"
t_assert_exists "$T_PROJ/ops/DEMOTED"
t_assert_contains "$T_PROJ/ops/DEMOTED" "no-go violation"
t_assert_contains "$T_CAP/notifications.log" "NO-GO VIOLATION: 1"
