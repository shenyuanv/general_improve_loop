#!/usr/bin/env bash
# T46 — runner-quota classification (#30): a 429 on the runner's result line
# is an environmental stop, not an agent failure. Pins: (1) the run is
# recorded as result "quota" with resets_at (from the last rate_limit_event),
# not "error"; (2) the notification says quota + local reset time, not rc=1;
# (3) three consecutive quota rows do NOT latch the breaker; (4) control: a
# plain rc=1 without a 429 stays "error".
source "$(dirname "$0")/../lib.sh"
t_setup

# 1783054800 = 2026-07-03T05:00:00Z; TZ pinned so the local HH:MM is stable
t_agent_script <<'EOF'
printf '{"type":"rate_limit_event","rate_limit":{"status":"rejected","resetsAt":1783054800}}\n'
printf '{"type":"result","is_error":true,"api_error_status":429,"result":"You have hit your session limit","total_cost_usd":0.42}\n'
EOF
t_run_loop orchestrator FAKE_AGENT_NO_RESULT=1 FAKE_AGENT_RC=1 TZ=UTC

t_assert_rc 1
t_assert_eq "$(t_row .result)" "quota" "429 must classify as quota, not error"
t_assert_eq "$(t_row .resets_at)" "2026-07-03T05:00:00Z"
t_assert_eq "$(t_row .cost_usd)" "0.42"
t_assert_contains "$T_CAP/notifications.log" "quota exhausted — resets 05:00"
t_assert_not_contains "$T_CAP/notifications.log" "rc=1"

# control: plain rc=1 (no 429 in the result line) stays "error"
t_agent_script </dev/null
t_run_loop orchestrator FAKE_AGENT_RC=1
t_assert_rc 1
t_assert_eq "$(t_row .result)" "error" "plain rc=1 must stay error"
t_assert_contains "$T_CAP/notifications.log" "rc=1"

# breaker exemption: 3 consecutive quota rows must NOT latch — the next run
# proceeds normally (t08 pins the error,error,error control)
rm -f "$T_STATE/runs.jsonl"
t_seed_runs orchestrator quota quota quota
t_run_loop orchestrator
t_assert_rc 0
t_assert_absent "$T_STATE/breaker-orchestrator"
t_assert_eq "$(t_row .result)" "success"
