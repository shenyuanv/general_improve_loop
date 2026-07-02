#!/usr/bin/env bash
# T31 — install-scheduler.sh launchd rendering, fully sandboxed: plists into
# the fake HOME, launchctl stubbed, forced-Darwin via a uname shim so this
# also runs on Linux CI.
source "$(dirname "$0")/../lib.sh"
t_setup

mkdir -p "$T_SB/xbin"
cp "$T_REPO/tests/stubs/uname" "$T_SB/xbin/uname" && chmod +x "$T_SB/xbin/uname"
sched() {
  env HOME="$T_HOME" PATH="$T_SB/xbin:$T_BIN:$PATH" T_CAP="$T_CAP" UNAME_STUB=Darwin \
    bash "$T_REPO/bin/install-scheduler.sh" "$T_CFG" "$@"
}

t_config_set 'SCHEDULE=("orchestrator|3|33||6000" "e2e-tester|5|33|0|5400" "bogus-loop|1|2||600")'
sched >"$T_CAP/sched.out"

LA="$T_HOME/Library/LaunchAgents"
orch="$LA/com.improve-loop.fixture.orchestrator.plist"
tester="$LA/com.improve-loop.fixture.e2e-tester.plist"
t_assert_exists "$orch"
t_assert_exists "$tester"
t_assert_absent "$LA/com.improve-loop.fixture.bogus-loop.plist"
t_assert_contains "$T_CAP/sched.out" "SKIP bogus-loop"

t_assert_contains "$orch" "<string>/bin/bash</string><string>$T_REPO/bin/run-loop.sh</string><string>orchestrator</string><string>$T_CFG</string>"
t_assert_contains "$orch" "<key>Hour</key><integer>3</integer><key>Minute</key><integer>33</integer>"
t_assert_not_contains "$orch" "<key>Weekday</key>"
t_assert_contains "$orch" "<key>LOOP_TIMEOUT_S</key><string>6000</string>"
t_assert_contains "$orch" "<key>WorkingDirectory</key><string>$T_PROJ</string>"
t_assert_contains "$tester" "<key>Weekday</key><integer>0</integer>"
t_assert_contains "$T_CAP/launchctl.log" "bootstrap"
t_assert_contains "$T_CAP/launchctl.log" "orchestrator.plist"

sched --uninstall >"$T_CAP/sched-un.out"
t_assert_absent "$orch"
t_assert_absent "$tester"
t_assert_contains "$T_CAP/launchctl.log" "bootout"
t_assert_contains "$T_CAP/sched-un.out" "removed"
