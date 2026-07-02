#!/usr/bin/env bash
# T29 — notify.sh matrix: every method delivers (or degrades) without ever
# failing the caller; special characters arrive literal, not executed.
source "$(dirname "$0")/../lib.sh"
t_setup

n() { # <config> <title> <msg> — returns notify.sh's rc
  set +e
  t_env bash "$T_REPO/bin/notify.sh" "$@" >/dev/null 2>&1
  T_RC=$?
  set -e
}

# osascript (fixture config): delivered, command substitution arrives inert
# (quote-CRUSHING correctness is t35 — a pinned known bug)
msg='plain message with $(reboot) and back\slash'
n "$T_CFG" "my title" "$msg"
t_assert_rc 0
t_assert_contains "$T_CAP/notifications.log" '$(reboot)'
t_assert_contains "$T_CAP/notifications.log" 'back\slash'
t_assert_contains "$T_CAP/notifications.log" 'Submarine'

# notify-send: args verbatim
echo 'NOTIFY_METHOD="notify-send"' >"$T_SB/n2.cfg"
n "$T_SB/n2.cfg" "linux title" "plain body"
t_assert_rc 0
t_assert_contains "$T_CAP/notifications.log" "notify-send linux title plain body"

# webhook: jq-encoded {"text": "title: msg"} posted to the URL
{
  echo 'NOTIFY_METHOD="webhook"'
  echo 'NOTIFY_WEBHOOK_URL="http://sandbox.invalid/hook"'
} >"$T_SB/n3.cfg"
n "$T_SB/n3.cfg" "hook" 'payload with "quotes"'
t_assert_rc 0
t_assert_contains "$T_CAP/curl.log" "http://sandbox.invalid/hook"
t_assert_contains "$T_CAP/curl.log" 'payload {"text":"hook: payload with \"quotes\""}'

# none: silence
before_n="$(wc -l <"$T_CAP/notifications.log" | tr -d '[:space:]')"
echo 'NOTIFY_METHOD="none"' >"$T_SB/n4.cfg"
n "$T_SB/n4.cfg" "quiet" "nothing"
t_assert_rc 0
t_assert_line_count "$T_CAP/notifications.log" "$before_n"

# missing config file: still exits 0 (auto fallback, best-effort)
n "$T_SB/does-not-exist.cfg" "lost" "config"
t_assert_rc 0

# a failing notifier binary must not fail the caller
n "$T_CFG" "flaky" "notifier" T_OSA_RC=1 || true
set +e
t_env T_OSA_RC=1 bash "$T_REPO/bin/notify.sh" "$T_CFG" "flaky" "notifier" >/dev/null 2>&1
T_RC=$?
set -e
t_assert_rc 0
