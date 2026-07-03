#!/usr/bin/env bash
# T32 — install-scheduler.sh cron rendering: tagged lines appended between
# managed markers, the user's own crontab preserved, uninstall clean.
source "$(dirname "$0")/../lib.sh"
t_setup

mkdir -p "$T_SB/xbin"
cp "$T_REPO/tests/stubs/uname" "$T_SB/xbin/uname" && chmod +x "$T_SB/xbin/uname"
sched() {
  env HOME="$T_HOME" PATH="$T_SB/xbin:$T_BIN:$PATH" T_CAP="$T_CAP" UNAME_STUB=Linux \
    bash "$T_REPO/bin/install-scheduler.sh" "$T_CFG" "$@"
}

echo "5 4 * * * /usr/bin/existing-user-job" >"$T_CAP/crontab.current"
t_config_set 'SCHEDULE=("orchestrator|3|33||6000" "e2e-tester|5|33|0|5400" "bogus-loop|1|2||600")'
sched >"$T_CAP/sched.out"

cron="$T_CAP/crontab.current"
t_assert_contains "$cron" "/usr/bin/existing-user-job"
t_assert_contains "$cron" "33 3 * * * LOOP_TIMEOUT_S=6000 /bin/bash $T_REPO/bin/run-loop.sh --scheduled orchestrator $T_CFG # improve-loop:fixture"
t_assert_contains "$cron" "33 5 * * 0 LOOP_TIMEOUT_S=5400 /bin/bash $T_REPO/bin/run-loop.sh --scheduled e2e-tester $T_CFG # improve-loop:fixture"
t_assert_not_contains "$cron" "bogus-loop"
t_assert_contains "$T_CAP/sched.out" "SKIP bogus-loop"

sched --uninstall >/dev/null
t_assert_contains "$cron" "/usr/bin/existing-user-job"
t_assert_not_contains "$cron" "improve-loop:fixture"
