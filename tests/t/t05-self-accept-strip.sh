#!/usr/bin/env bash
# T05 — self-accept guard, evidence-gated: an `accepted` label applied during
# the run window is stripped ONLY when this run's transcript shows the loop
# adding it (DEMOTED + notification follow); an in-window label WITHOUT loop
# evidence is kept — assumed owner — with an FYI notification instead.
source "$(dirname "$0")/../lib.sh"
t_setup

t_gh_events <<'EOF'
[
  {"event":"labeled","label":{"name":"accepted"},"created_at":"2999-01-01T00:00:00Z","issue":{"number":12}},
  {"event":"labeled","label":{"name":"bug"},"created_at":"2999-01-01T00:00:00Z","issue":{"number":13}},
  {"event":"labeled","label":{"name":"accepted"},"created_at":"2000-01-01T00:00:00Z","issue":{"number":14}},
  {"event":"labeled","label":{"name":"accepted"},"created_at":"2999-01-01T00:00:00Z","issue":{"number":15}}
]
EOF
# The scenario's stdout lands in the run transcript ($LOG): loop evidence
# exists for #15 only — #12's in-window label has no transcript trace.
t_agent_script <<'EOF'
echo "gh issue edit 15 -R stub-owner/stub-repo --add-label accepted"
EOF
t_run_loop orchestrator

t_assert_rc 0
t_assert_contains "$T_CAP/gh-mutations.log" "issue edit 15"
t_assert_contains "$T_CAP/gh-mutations.log" "--remove-label accepted"
t_assert_not_contains "$T_CAP/gh-mutations.log" "issue edit 12"   # in-window, no evidence -> kept
t_assert_not_contains "$T_CAP/gh-mutations.log" "issue edit 14"   # outside window
t_assert_not_contains "$T_CAP/gh-mutations.log" "issue edit 13"   # not 'accepted'
t_assert_exists "$T_PROJ/ops/DEMOTED"
t_assert_contains "$T_PROJ/ops/DEMOTED" "self-accept guard"
t_assert_contains "$T_CAP/notifications.log" "self-accept guard: stripped 1"
t_assert_contains "$T_CAP/notifications.log" "FYI: #12 gained 'accepted' during this run"
t_assert_contains "$T_CAP/notifications.log" "kept (no loop evidence)"
