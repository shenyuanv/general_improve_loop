#!/usr/bin/env bash
# T40 — digest guarantee, healthy run: if the orchestrator exits 0 but
# writes no digest, the wrapper stub must NOT claim FAILED/🔴 (issue #11).
source "$(dirname "$0")/../lib.sh"
t_setup

t_run_loop orchestrator

t_assert_rc 0
t_assert_eq "$(t_row .result)" "success"
t_assert_exists "$(t_digest)"
t_assert_contains "$(t_digest)" "orchestrator completed (rc=0) but wrote no digest"
t_assert_contains "$(t_digest)" "Status: 🟡 wrapper stub"
t_assert_not_contains "$(t_digest)" "FAILED"
t_assert_not_contains "$(t_digest)" "🔴"
