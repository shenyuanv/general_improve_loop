#!/usr/bin/env bash
# T06 — self-accept guard window boundary: the real jq `>=` filter decides,
# exercised through the stub (which applies the caller's own --jq).
source "$(dirname "$0")/../lib.sh"
t_setup

t_gh_events <<'EOF'
[{"event":"labeled","label":{"name":"accepted"},"created_at":"2000-06-15T12:00:00Z","issue":{"number":14}}]
EOF

t_run_check --check-self-accept "2020-01-01T00:00:00Z"   # event is BEFORE window
t_assert_rc 0
t_assert_contains "$T_CAP/check.out" "self_accepts_stripped=0"
t_assert_not_contains "$T_CAP/gh-mutations.log" "issue edit 14"

t_run_check --check-self-accept "1999-01-01T00:00:00Z"   # event is INSIDE window
t_assert_rc 3
t_assert_contains "$T_CAP/check.out" "self_accepts_stripped=1"
t_assert_contains "$T_CAP/gh-mutations.log" "issue edit 14"
