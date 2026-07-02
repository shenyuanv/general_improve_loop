#!/usr/bin/env bash
# T36 — preflight must resolve its timeout binary the way the wrapper does
# (`command -v gtimeout || command -v timeout`), not hardcode bare `timeout`:
# stock macOS ships no unprefixed GNU timeout, so a bare call kills the auth
# probe and aborts every run. Stubs in $T_BIN shadow any host binaries (the
# PATH re-export puts $HOME/.local/bin first), so the log records exactly
# which name preflight resolved for the 90s auth probe and 30s deploy probe.
source "$(dirname "$0")/../lib.sh"
t_setup

cat >"$T_BIN/gtimeout" <<'EOF'
#!/usr/bin/env bash
echo "via-gtimeout $1" >>"$T_CAP/timeout-resolution.log"
shift; exec "$@"
EOF
cat >"$T_BIN/timeout" <<'EOF'
#!/usr/bin/env bash
echo "via-bare-timeout $1" >>"$T_CAP/timeout-resolution.log"
shift; exec "$@"
EOF
chmod +x "$T_BIN/gtimeout" "$T_BIN/timeout"

t_config_set 'DEPLOY_VERIFY_CMD="true"'
t_preflight orchestrator
t_assert_rc 0
t_assert_eq "$(jq -r .verdict "$T_CAP/preflight.json")" "run"
t_assert_eq "$(jq -r .checks.agent_auth "$T_CAP/preflight.json")" "true"
t_assert_eq "$(jq -r .checks.deploy_healthy "$T_CAP/preflight.json")" "true"
# gtimeout wins resolution for both probes; bare timeout is never invoked
t_assert_contains "$T_CAP/timeout-resolution.log" "via-gtimeout 90"
t_assert_contains "$T_CAP/timeout-resolution.log" "via-gtimeout 30"
t_assert_not_contains "$T_CAP/timeout-resolution.log" "via-bare-timeout"
