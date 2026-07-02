#!/usr/bin/env bash
# T02 — no-go revert, multiple violations: both fenced commits are reverted,
# an innocent commit in between survives untouched.
source "$(dirname "$0")/../lib.sh"
t_setup

dir_before="$(cat "$T_PROJ/ops/DIRECTION.md")"
ign_before="$(cat "$T_PROJ/.gitignore")"
t_agent_script <<'EOF'
echo "tamper one" >>ops/DIRECTION.md
git add ops/DIRECTION.md && git commit -qm "loop: tamper 1"
echo "innocent feature note" >>README.md
git add README.md && git commit -qm "loop: innocent"
echo "tamper two" >>.gitignore
git add .gitignore && git commit -qm "loop: tamper 2"
EOF
t_run_loop orchestrator

t_assert_rc 0
t_assert_eq "$(t_row .nogo_reverts)" "2"
t_assert_eq "$(cat "$T_PROJ/ops/DIRECTION.md")" "$dir_before" "DIRECTION restored"
t_assert_eq "$(cat "$T_PROJ/.gitignore")" "$ign_before" ".gitignore restored"
t_assert_contains "$T_PROJ/README.md" "innocent feature note"
t_assert_exists "$T_PROJ/ops/DEMOTED"
t_assert_contains "$T_CAP/notifications.log" "NO-GO VIOLATION: 2"
