#!/usr/bin/env bash
# T35 — notify.sh osascript quoting: a message containing double quotes must
# arrive with them crushed to single quotes (the code's visible intent), and
# must never leak expansion garbage into the AppleScript command.
#
# XFAIL, PINS BUG S6 (bin/notify.sh:18): on modern bash the replacement in
# ${MSG//\"/'} mis-pairs its single quote with the one in the TITLE
# expansion, so the "replacement" becomes the literal text between them —
# the delivered notification is garbled, and because \" can terminate the
# AppleScript string context, digest-derived text can inject into osascript.
# Listed in tests/known-failures.txt until fixed.
source "$(dirname "$0")/../lib.sh"
t_setup

set +e
t_env bash "$T_REPO/bin/notify.sh" "$T_CFG" "my title" 'has "double" quotes inside' >/dev/null 2>&1
T_RC=$?
set -e

t_assert_rc 0
t_assert_contains "$T_CAP/notifications.log" "has 'double' quotes inside"   # intended crush
t_assert_not_contains "$T_CAP/notifications.log" '${TITLE'                  # no expansion garbage
