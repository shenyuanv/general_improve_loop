#!/usr/bin/env bash
# T50 — digest guarantee for failed NON-orchestrator runs (issue #35): any
# loop exiting rc!=0 must append an in-repo trace line to the day's digest.
# Before the fix only orchestrator deaths left a digest trace, so killed
# e2e-user/fixer/pr-verifier attempts were invisible to in-repo trend data
# (runs.jsonl showed the error, the digest showed nothing).
source "$(dirname "$0")/../lib.sh"
t_setup

# Success path unchanged: a clean non-orchestrator run writes no digest.
t_run_loop e2e-user
t_assert_rc 0
t_assert_absent "$(t_digest)"

# Failed run: digest gains exactly the failure trace line.
t_run_loop e2e-user FAKE_AGENT_RC=1
t_assert_rc 1
t_assert_eq "$(t_row .result)" "error"
t_assert_exists "$(t_digest)"
t_assert_contains "$(t_digest)" "> NOTIFY: failure — e2e-user run"
t_assert_contains "$(t_digest)" "rc=1"
t_assert_contains "$(t_digest)" "$(basename "$(t_runlog e2e-user)")"
t_assert_line_count "$(t_digest)" 1

# The trace is appended AFTER the fan-out: the failure is notified once by
# the direct rc!=0 notify, never re-fanned as a digest NOTIFY line.
t_assert_contains "$T_CAP/notifications.log" "rc=1"
t_assert_not_contains "$T_CAP/notifications.log" "failure — e2e-user run"
