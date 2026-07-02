#!/usr/bin/env bash
# T16 — preflight abort: a broken PROJECT_DIR git repo stops the run before
# any token burn, loudly.
source "$(dirname "$0")/../lib.sh"
t_setup

mkdir -p "$T_SB/notrepo"
t_config_set "PROJECT_DIR=\"$T_SB/notrepo\""
t_run_loop orchestrator

t_assert_rc 1
t_assert_eq "$(t_row .result)" "preflight_abort"
t_assert_contains "$T_CAP/notifications.log" "preflight abort: git repo broken"
t_assert_eq "$(jq -r .verdict "$T_STATE/preflight-orchestrator.json")" "abort"
t_assert_absent "$T_CAP/agent-argv.txt"
