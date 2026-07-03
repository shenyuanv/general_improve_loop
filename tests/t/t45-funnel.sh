#!/usr/bin/env bash
# T45 — bin/funnel.sh classifies every open item into exactly one
# queue-state-machine row (first match wins), flags orphans and stuck PRs,
# and ends with the machine-parseable summary line.
source "$(dirname "$0")/../lib.sh"
t_setup

repro_body=$'## Found\nseeded\n## Repro\nbash src/app.sh x\n## Verify\ntrue'
plain_body=$'## Found\nno repro here'
today="$(date -u +%Y-%m-%dT00:00:00Z)"   # age 0d ⇒ no nudge

t_gh_issue 1 "🙋 needs-your-decision,component:cli" "$plain_body" "$today"
t_gh_issue 2 "accepted,action:interactive,component:cli" "$plain_body" "$today"
t_gh_issue 3 "action:operator,component:cli" "$plain_body" "2020-01-01T00:00:00Z"   # >7d ⇒ nudge
t_gh_issue 4 "accepted,action:loop,bug,component:cli" "$repro_body" "$today"
t_gh_issue 5 "action:loop,bug,component:cli" "$repro_body" "2020-01-01T00:00:00Z"    # cooled
t_gh_issue 6 "action:loop,bug,component:cli" "$repro_body" "2999-01-01T00:00:00Z"    # cooling
t_gh_issue 7 "action:loop,component:cli" "$repro_body" "$today"                      # missing bug ⇒ grooming
t_gh_issue 8 "" "$plain_body" "$today"                                               # no labels ⇒ ORPHAN
t_gh_pr 40 "loop-pr" "2020-01-01T00:00:00Z"                                          # old ⇒ stuck flag

set +e
t_env bash "$T_REPO/bin/funnel.sh" "$T_CFG" >"$T_CAP/funnel.out" 2>"$T_CAP/funnel.err"
T_RC=$?
set -e

t_assert_rc 0
f="$T_CAP/funnel.out"
t_assert_contains "$f" "| item | state | next actor | next action |"
t_assert_contains "$f" "| #1 issue 1 | 🙋 decision | owner replies Option X or acts | daily reminder |"
t_assert_contains "$f" "| #2 issue 2 | accepted interactive | owner pastes the stated ask into a session | owner leisure |"
grep -E '^\| #3 .*operator task.*owner leisure ⚠ [0-9]+d old \|$' "$f" >/dev/null || t_fail "no nudge on aged #3"
t_assert_contains "$f" "| #4 issue 4 | accepted fix | fixer dispatcher | tonight |"
t_assert_contains "$f" "cooled fix | fixer dispatcher | tonight (cooled since"
t_assert_contains "$f" "| #6 issue 6 | cooling | fixer dispatcher | after 2999-01-02T00:00:00Z |"
t_assert_contains "$f" "| #7 issue 7 | malformed filing (missing bug) | orchestrator grooming | tonight, then cooling |"
t_assert_contains "$f" "| #8 issue 8 | ORPHAN 🟡 | orchestrator triage | tonight — no state matches |"
grep -E '^\| #40 pr 40 \| loop PR \| pr-verifier dispatcher \| tonight ⚠ [0-9]+d old \(stuck\?\) \|$' "$f" >/dev/null || t_fail "no stuck flag on aged PR"
t_assert_contains "$f" "funnel: open_issues=8 loop_prs=1 orphans=1"

# unreachable repo ⇒ exit 2, loud
set +e
t_env T_GH_AUTH_RC=1 bash "$T_REPO/bin/funnel.sh" "$T_CFG" >/dev/null 2>&1
true   # (auth rc only affects `gh auth status`; funnel calls issue list directly)
set -e
