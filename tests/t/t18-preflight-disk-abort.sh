#!/usr/bin/env bash
# T18 — preflight abort: under 5 GB free disk (deterministic via the df
# stub, which answers 50 GB in every other test).
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop orchestrator DF_STUB_GB=2

t_assert_rc 1
t_assert_eq "$(t_row .result)" "preflight_abort"
t_assert_contains "$T_CAP/notifications.log" "disk <5 GB"
t_assert_eq "$(jq -r .checks.disk_gb_free "$T_STATE/preflight-orchestrator.json")" "2"
t_assert_absent "$T_CAP/agent-argv.txt"
