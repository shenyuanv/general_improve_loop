#!/usr/bin/env bash
# T19 — preflight JSON contract: soft flags flip without ever aborting;
# ops/-only churn is not "dirty"; the project hook merges (or degrades to {}).
source "$(dirname "$0")/../lib.sh"
t_setup

pf() { jq -r "$1" "$T_CAP/preflight.json"; }

# (a) pristine fixture
t_preflight orchestrator
t_assert_rc 0
t_assert_eq "$(pf .verdict)" "run"
t_assert_eq "$(pf .checks.repo_dirty)" "false"
t_assert_eq "$(pf .checks.gh_ok)" "true"
t_assert_eq "$(pf .checks.deploy_healthy)" "null"
t_assert_eq "$(pf '.checks.project | length')" "0"

# (b) dirty tracked file outside ops/ ⇒ repo_dirty, still verdict=run
echo "wip" >>"$T_PROJ/README.md"
t_preflight orchestrator
t_assert_eq "$(pf .checks.repo_dirty)" "true"
t_assert_eq "$(pf .verdict)" "run"

# (c) ops/-only churn is the loops' own output ⇒ not dirty
t_git checkout -- README.md
echo "note" >>"$T_PROJ/ops/DIRECTION.md"
t_preflight orchestrator
t_assert_eq "$(pf .checks.repo_dirty)" "false"
t_git checkout -- ops/DIRECTION.md

# (d) gh auth dead is a soft flag
t_preflight orchestrator T_GH_AUTH_RC=1
t_assert_eq "$(pf .checks.gh_ok)" "false"
t_assert_eq "$(pf .verdict)" "run"

# (e) deploy health probe: healthy / unhealthy / unset(=null above)
t_config_set 'DEPLOY_VERIFY_CMD="true"'
t_preflight orchestrator
t_assert_eq "$(pf .checks.deploy_healthy)" "true"
t_config_set 'DEPLOY_VERIFY_CMD="false"'
t_preflight orchestrator
t_assert_eq "$(pf .checks.deploy_healthy)" "false"

# (f) project hook: valid JSON merges; invalid degrades to {}
cat >"$T_SB/hook.sh" <<'EOF'
#!/usr/bin/env bash
echo '{"custom": 1}'
EOF
chmod +x "$T_SB/hook.sh"
t_config_set "PROJECT_PREFLIGHT_HOOK=\"$T_SB/hook.sh\""
t_preflight orchestrator
t_assert_eq "$(pf .checks.project.custom)" "1"

cat >"$T_SB/hook.sh" <<'EOF'
#!/usr/bin/env bash
echo 'this is not json'
EOF
t_preflight orchestrator
t_assert_eq "$(pf '.checks.project | length')" "0"
