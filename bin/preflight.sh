#!/usr/bin/env bash
# bin/preflight.sh <loop-name> <config> — cheap checks before burning tokens.
# Emits ONE JSON object; always exits 0. verdict=abort only for failures no
# run can survive: broken git, <5 GB disk, dead agent auth, gh unable to
# reach GH_REPO. Everything else is a soft flag the agent maps to skipped
# stages (see contracts/safety-floors.md).
set -uo pipefail
LOOP="${1:-orchestrator}"; CONFIG="${2:?config path}"
# shellcheck source=/dev/null
source "$CONFIG"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
# Same resolution as run-loop.sh: stock macOS has no unprefixed GNU timeout
TIMEOUT_BIN=$(command -v gtimeout || command -v timeout)

git_ok=false; disk_gb=0; agent_auth=false; repo_dirty=true; deploy_healthy=null; gh_ok=false

git -C "$PROJECT_DIR" rev-parse HEAD >/dev/null 2>&1 && git_ok=true
if [[ "$(uname)" == "Darwin" ]]; then disk_gb=$(df -g / 2>/dev/null | awk 'NR==2{print $4}')
else disk_gb=$(df -BG / 2>/dev/null | awk 'NR==2{gsub("G","",$4); print $4}'); fi
disk_gb=${disk_gb:-0}

# Tracked modifications only (ops/ churn is the loops' own output)
[[ -z "$(git -C "$PROJECT_DIR" status --porcelain --untracked-files=no -- ':(exclude)ops' 2>/dev/null)" ]] && repo_dirty=false

# ~1-cent probe; the one failure only a human login can fix — surface loudly
if (cd "$HOME" && eval "$TIMEOUT_BIN 90 $RUNNER_AUTH_PROBE" 2>/dev/null | grep -q OK); then agent_auth=true; fi

gh auth status >/dev/null 2>&1 && gh_ok=true

if [[ -n "${DEPLOY_VERIFY_CMD:-}" ]]; then
  if (cd "$PROJECT_DIR" && eval "$TIMEOUT_BIN 30 $DEPLOY_VERIFY_CMD" >/dev/null 2>&1); then deploy_healthy=true; else deploy_healthy=false; fi
fi

extra="{}"
if [[ -n "${PROJECT_PREFLIGHT_HOOK:-}" && -x "$PROJECT_PREFLIGHT_HOOK" ]]; then
  extra=$("$PROJECT_PREFLIGHT_HOOK" "$LOOP" 2>/dev/null) || extra="{}"
  jq -e . >/dev/null 2>&1 <<<"$extra" || extra="{}"
fi

verdict=run; abort_reason=null
if [[ "$git_ok" != true ]]; then verdict=abort; abort_reason='"git repo broken"'
elif (( disk_gb < 5 )); then verdict=abort; abort_reason='"disk <5 GB free"'
elif [[ "$agent_auth" != true ]]; then verdict=abort; abort_reason='"agent runner auth dead — log in to your agent CLI"'
elif ! gh api "repos/$GH_REPO" --jq .id >/dev/null 2>&1; then
  # A gh account flip makes every gh call fail open (silently empty queues,
  # dead wrapper floors) — that's an abort, not a soft flag. Distinct from
  # gh_ok above: `gh auth status` can pass on an account that cannot see
  # GH_REPO. Pin GH_AUTH_USER in the config to prevent flips.
  verdict=abort; abort_reason="\"gh cannot reach $GH_REPO (auth/account flip) — silent-empty-queue floors\""
fi

jq -n --arg loop "$LOOP" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg verdict "$verdict" --argjson abort_reason "$abort_reason" \
  --argjson git_ok "$git_ok" --argjson disk_gb_free "$disk_gb" \
  --argjson agent_auth "$agent_auth" --argjson repo_dirty "$repo_dirty" \
  --argjson gh_ok "$gh_ok" --argjson deploy_healthy "$deploy_healthy" \
  --argjson project "$extra" \
  '{loop:$loop, ts:$ts, verdict:$verdict, abort_reason:$abort_reason,
    checks:{git_ok:$git_ok, disk_gb_free:$disk_gb_free, agent_auth:$agent_auth,
            repo_dirty:$repo_dirty, gh_ok:$gh_ok, deploy_healthy:$deploy_healthy,
            project:$project}}'
exit 0
