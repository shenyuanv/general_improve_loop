#!/usr/bin/env bash
# T23 — NOTIFY fan-out: only lines THIS run appended are sent, capped at 3;
# pre-existing digest lines are never re-sent.
source "$(dirname "$0")/../lib.sh"
t_setup

mkdir -p "$T_PROJ/ops/reports"
cat >"$(t_digest)" <<'EOF'
# fixture daily — pre-existing
Status: 🟢 GREEN — carried over
> NOTIFY: old-one should never fan out again
> NOTIFY: old-two should never fan out again
EOF

t_agent_script <<'EOF'
{
  echo "## Re-run section"
  echo "> NOTIFY: new-1 fresh line"
  echo "> NOTIFY: new-2 fresh line"
  echo "filler between notify lines"
  echo "> NOTIFY: new-3 fresh line"
  echo "> NOTIFY: new-4 must be capped away"
  echo "> NOTIFY: new-5 must be capped away"
} >>"ops/reports/$(date +%F).md"
EOF
t_run_loop orchestrator

t_assert_rc 0
t_assert_line_count "$T_CAP/notifications.log" 3
t_assert_contains "$T_CAP/notifications.log" "new-1 fresh line"
t_assert_contains "$T_CAP/notifications.log" "new-2 fresh line"
t_assert_contains "$T_CAP/notifications.log" "new-3 fresh line"
t_assert_not_contains "$T_CAP/notifications.log" "new-4"
t_assert_not_contains "$T_CAP/notifications.log" "old-one"
