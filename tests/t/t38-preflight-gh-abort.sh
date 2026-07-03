#!/usr/bin/env bash
# T38 — preflight abort: gh unable to reach $GH_REPO (auth/account flip).
# Every wrapper gh floor fails OPEN on silently-empty lists when the active
# gh account cannot see the repo — so unreachability is a hard abort, not a
# soft flag. Distinct from `gh auth status` (gh_ok), which stays soft (T19d):
# auth can be alive on an account that still cannot see GH_REPO.
source "$(dirname "$0")/../lib.sh"
t_setup

t_preflight orchestrator T_GH_REPO_RC=22
t_assert_rc 0                                     # preflight itself always exits 0
t_assert_eq "$(jq -r .verdict "$T_CAP/preflight.json")" "abort"
t_assert_contains "$T_CAP/preflight.json" "gh cannot reach"
t_assert_contains "$T_CAP/preflight.json" "auth/account flip"

t_run_loop orchestrator T_GH_REPO_RC=22
t_assert_rc 1
t_assert_eq "$(t_row .result)" "preflight_abort"
t_assert_contains "$T_CAP/notifications.log" "gh cannot reach"
t_assert_absent "$T_CAP/agent-argv.txt"           # no tokens burned
