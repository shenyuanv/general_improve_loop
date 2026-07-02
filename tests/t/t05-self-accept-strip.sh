#!/usr/bin/env bash
# T05 — self-accept guard: an `accepted` label applied during the run window
# is stripped via the issue-events timeline; DEMOTED + notification follow.
source "$(dirname "$0")/../lib.sh"
t_setup

t_gh_events <<'EOF'
[
  {"event":"labeled","label":{"name":"accepted"},"created_at":"2999-01-01T00:00:00Z","issue":{"number":12}},
  {"event":"labeled","label":{"name":"bug"},"created_at":"2999-01-01T00:00:00Z","issue":{"number":13}},
  {"event":"labeled","label":{"name":"accepted"},"created_at":"2000-01-01T00:00:00Z","issue":{"number":14}}
]
EOF
t_run_loop orchestrator

t_assert_rc 0
t_assert_contains "$T_CAP/gh-mutations.log" "issue edit 12"
t_assert_contains "$T_CAP/gh-mutations.log" "--remove-label accepted"
t_assert_not_contains "$T_CAP/gh-mutations.log" "issue edit 14"   # outside window
t_assert_not_contains "$T_CAP/gh-mutations.log" "issue edit 13"   # not 'accepted'
t_assert_exists "$T_PROJ/ops/DEMOTED"
t_assert_contains "$T_PROJ/ops/DEMOTED" "self-accept guard"
t_assert_contains "$T_CAP/notifications.log" "self-accept guard: stripped 1"
