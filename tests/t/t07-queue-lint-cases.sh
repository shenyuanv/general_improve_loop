#!/usr/bin/env bash
# T07 — queue lint: all five malformation classes flagged the night they are
# born; a well-formed filing passes.
source "$(dirname "$0")/../lib.sh"
t_setup

good_body=$'## Found\nseeded\n## Repro\nbash src/app.sh x\n## Verify\nbash src/app.sh x'
bad_body=$'## Found\nseeded, no repro here'
noverify_body=$'## Found\nseeded\n## Repro\nbash src/app.sh x'

t_gh_issue 1 "loop-filed,component:cli" "$good_body"                          # zero action:*
t_gh_issue 2 "loop-filed,action:loop,action:operator,component:cli" "$good_body"  # two action:*
t_gh_issue 3 "loop-filed,action:loop" "$good_body"                            # zero component:*
t_gh_issue 4 "loop-filed,action:loop,component:cli,bug" "$bad_body"           # bug without Repro
t_gh_issue 5 "loop-filed,action:loop,component:cli,bug" "$good_body"          # control: well-formed
t_gh_issue 6 "loop-filed,action:loop,component:cli" "$noverify_body"          # action:loop without Verify
dev_good=$'## Found\nbrief\n## Design\nthe plan\n## Budget\n300\n## Verify\ntrue'
dev_bad=$'## Found\nbrief\n## Verify\ntrue'
t_gh_issue 7 "loop-filed,action:develop,component:cli" "$dev_bad"             # develop without Design
t_gh_issue 8 "loop-filed,action:develop,component:cli" "$dev_good"            # control: well-formed develop

t_run_check --check-queue-lint "2026-01-01T00:00:00Z"
t_assert_rc 3
t_assert_contains "$T_CAP/check.out" "queue_lint_violations=6"
for n in 1 2 3 4 6 7; do
  t_assert_contains "$T_CAP/check.err" "queue lint: #$n malformed"
done
t_assert_not_contains "$T_CAP/check.err" "queue lint: #5"
t_assert_not_contains "$T_CAP/check.err" "queue lint: #8"

# Only the well-formed issue in the queue ⇒ clean pass
rm "$T_GH/issue-meta.jsonl"
t_gh_issue 5 "loop-filed,action:loop,component:cli,bug" "$good_body"
t_run_check --check-queue-lint "2026-01-01T00:00:00Z"
t_assert_rc 0
t_assert_contains "$T_CAP/check.out" "queue_lint_violations=0"
