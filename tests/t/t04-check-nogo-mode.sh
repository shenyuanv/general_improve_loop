#!/usr/bin/env bash
# T04 — `--check-nogo` test mode: exit 3 + revert on violation, exit 0 clean.
source "$(dirname "$0")/../lib.sh"
t_setup

base="$(t_git rev-parse HEAD)"
before="$(cat "$T_PROJ/ops/DIRECTION.md")"
t_commit_nogo >/dev/null

t_run_check --check-nogo "$base"
t_assert_rc 3
t_assert_contains "$T_CAP/check.out" "nogo_reverts=1"
t_assert_eq "$(cat "$T_PROJ/ops/DIRECTION.md")" "$before" "violation reverted"

clean_base="$(t_git rev-parse HEAD)"
t_commit_ok >/dev/null
t_run_check --check-nogo "$clean_base"
t_assert_rc 0
t_assert_contains "$T_CAP/check.out" "nogo_reverts=0"
