#!/usr/bin/env bash
# bin/run-loop.sh <loop-name> <path-to-loop.config.sh>
#
# The mechanical shell around every agent run. Thin and dumb by design: all
# judgment lives in agents/<loop>/AGENT.md; everything here is what the
# agent must NOT be able to renegotiate mid-run — locks, kill switch,
# breaker, timeout, and the post-run floors (no-go revert, self-accept
# guard, queue lint, stale loop-branch prune, diff accounting, digest
# guarantee, notify fan-out).
#
# Test modes (used by docs/AUDIT-CHECKLIST.md):
#   run-loop.sh --check-nogo <base-sha> <config>
#   run-loop.sh --check-self-accept <since-iso> <config>
#   run-loop.sh --check-queue-lint <since-iso> <config>
set -uo pipefail   # NOT -e: every failure is handled explicitly

LOOP="${1:?usage: run-loop.sh <loop-name>|--check-* <arg> <config>}"
if [[ "$LOOP" == --check-* ]]; then CHECK_ARG="${2:?missing arg}"; CONFIG="${3:?missing config path}"; else CONFIG="${2:?usage: run-loop.sh <loop-name> <config>}"; fi
# shellcheck source=/dev/null
source "$CONFIG" || { echo "cannot source config $CONFIG" >&2; exit 1; }

LOG_DIR="$STATE_DIR/logs"
mkdir -p "$LOG_DIR" "$STATE_DIR/lock" "$STATE_DIR/evidence"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# GH identity floor: headless runs have no GH_TOKEN and gh's *active* keyring
# account can flip to one that cannot see $GH_REPO — every wrapper gh call
# then fails open (empty lists = dead self-accept guard and queue lint, and
# dispatchers seeing an empty queue). When GH_AUTH_USER is configured, pin
# the token from that keyring entry regardless of the active account;
# exported so the agent run and preflight inherit it too.
if [[ -n "${GH_AUTH_USER:-}" ]]; then
  GH_TOKEN="${GH_TOKEN:-$(gh auth token --user "$GH_AUTH_USER" 2>/dev/null || true)}"
  [[ -n "${GH_TOKEN:-}" ]] && export GH_TOKEN
fi

TS=$(date +%Y%m%d-%H%M%S)
START_ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG="$LOG_DIR/$LOOP-$TS.log"
TIMEOUT_S="${LOOP_TIMEOUT_S:-6000}"
NOTIFY="$ILOOP_ROOT/bin/notify.sh"
RC=0

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; }
notify() { "$NOTIFY" "$CONFIG" "$1" "$2"; }

record_run() { # $1=result
  jq -cn --arg loop "$LOOP" --arg started "$START_ISO" \
    --arg ended "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson rc "${RC:-0}" \
    --argjson timed_out "$( [[ "${RC:-0}" == 124 ]] && echo true || echo false )" \
    --argjson cost_usd "${COST:-0}" --argjson nogo "${NOGO_REVERTS:-0}" \
    --argjson commits "${COMMITS:-0}" --argjson ins "${INS:-0}" --argjson del "${DEL:-0}" \
    --arg log "$LOG" --arg result "$1" \
    '{loop:$loop,started:$started,ended:$ended,rc:$rc,timed_out:$timed_out,cost_usd:$cost_usd,commits:$commits,insertions:$ins,deletions:$del,nogo_reverts:$nogo,log:$log,result:$result}' \
    >>"$STATE_DIR/runs.jsonl" 2>/dev/null
}

# ── Floor: no-go revert — commits touching forbidden paths are reverted ──
check_nogo() { # $1=repo dir, $2=base sha; reverts violators, echoes "<reverted> <failed>"
  local dir=$1 base=$2 n=0 f=0 sha
  for sha in $(git -C "$dir" log --format=%H "$base"..HEAD -- "${NOGO_PATHS[@]}" 2>/dev/null); do
    if git -C "$dir" revert --no-edit "$sha" >>"$LOG" 2>&1; then n=$((n+1)); else
      git -C "$dir" revert --abort >/dev/null 2>&1
      f=$((f+1)); log "no-go revert FAILED for $sha — needs human"
    fi
  done
  echo "$n $f"
}

# ── Floor: self-accept guard — loops never authorize their own work ──────
# A single-identity setup can't attribute a label event to owner vs loop,
# so stripping is gated on evidence in THIS run's transcript ($LOG) that
# the loop itself added the label (gh issue edit --add-label, or the labels
# API). No evidence ⇒ assume the owner acted mid-run: keep the label and
# send an FYI instead of strip + demotion. The grep is a heuristic — a
# deliberately obfuscated add evades it; accepted residual, the write-policy
# contract and the verifier lane still cover it. The manual drill
# (--check-self-accept) strips unconditionally: it has no transcript, so the
# evidence gate applies only when $LOG is a real file.
check_self_accept() { # $1=since ISO; strips loop-evidenced accepted labels applied in-window
  local since=$1 n=0 inum ldate
  while IFS=$'\t' read -r inum ldate; do
    [[ -z "$inum" ]] && continue
    if [[ "$LOG" != /dev/stderr ]] && \
       ! grep -Eq "issue edit.*[^0-9]${inum}[^0-9].*--add-label.*accepted|issues/${inum}/labels" "$LOG" 2>/dev/null; then
      log "self-accept guard: #$inum labeled 'accepted' $ldate (in-window) — no loop evidence in transcript, kept (assuming owner)"
      notify "$PROJECT_NAME $LOOP" "FYI: #$inum gained 'accepted' during this run — kept (no loop evidence); remove the label if that wasn't you"
      continue
    fi
    if gh issue edit "$inum" -R "$GH_REPO" --remove-label accepted >>"$LOG" 2>&1; then
      n=$((n+1)); log "self-accept guard: stripped 'accepted' from #$inum (labeled $ldate in-window)"
    fi
  done < <(gh api "repos/$GH_REPO/issues/events?per_page=100" \
    --jq ".[] | select(.event==\"labeled\" and .label.name==\"accepted\" and .created_at >= \"$since\") | [.issue.number, .created_at] | @tsv" 2>/dev/null)
  echo "$n"
}

# ── Floor: queue lint — malformed filings are flagged the night they're born
check_queue_lint() { # $1=since ISO; logs violations, echoes count
  local since=$1 n=0 inum
  while read -r inum; do
    [[ -z "$inum" ]] && continue
    local j actions comps isbug hasrepro isloop hasverify
    j=$(gh issue view "$inum" -R "$GH_REPO" --json labels,body 2>/dev/null) || continue
    actions=$(jq -r '[.labels[].name | select(startswith("action:"))] | length' <<<"$j")
    comps=$(jq -r '[.labels[].name | select(startswith("component:"))] | length' <<<"$j")
    isbug=$(jq -r '[.labels[].name | select(.=="bug")] | length' <<<"$j")
    isloop=$(jq -r '[.labels[].name | select(.=="action:loop")] | length' <<<"$j")
    hasrepro=$(jq -r '.body | test("(?i)##? ?Repro|Repro:") | if . then 1 else 0 end' <<<"$j")
    hasverify=$(jq -r '.body | test("(?i)##? ?Verify|Verify:") | if . then 1 else 0 end' <<<"$j")
    if [[ "$actions" != 1 || "$comps" == 0 || ( "$isbug" == 1 && "$hasrepro" == 0 ) || ( "$isloop" == 1 && "$hasverify" == 0 ) ]]; then
      n=$((n+1)); log "queue lint: #$inum malformed (action=$actions comp=$comps bug=$isbug repro=$hasrepro verify=$hasverify) — no executor will pick it up"
    fi
  done < <(gh issue list -R "$GH_REPO" --label loop-filed --state open \
    --search "created:>=${since%T*}" --json number --jq '.[].number' 2>/dev/null)
  echo "$n"
}

# ── Floor: stale loop-branch prune — a merged/closed loop PR must not leave
# its local loop/fix-GH<n> branch behind (the fixer treats "branch exists"
# as ineligible, so one stale ref silently blocks every future re-fix of
# that issue). Loop-prefixed refs ONLY — never human branches; a branch
# whose newest PR is OPEN, or with no PR / unreadable state, is KEPT.
prune_stale_loop_branches() {
  local b state
  while IFS= read -r b; do
    [[ "$b" =~ ^loop/fix-GH[0-9]+$ ]] || continue
    state=$(gh pr list -R "$GH_REPO" --head "$b" --state all --limit 1 \
      --json state --jq '.[0].state' 2>/dev/null)
    if [[ "$state" == "MERGED" || "$state" == "CLOSED" ]]; then
      if git -C "$PROJECT_DIR" branch -D "$b" >>"$LOG" 2>&1; then
        log "stale-branch prune: deleted $b (PR $state)"
      else
        log "stale-branch prune: could not delete $b (PR $state) — checked out in a worktree?"
      fi
    fi
  done < <(git -C "$PROJECT_DIR" for-each-ref --format='%(refname:short)' \
    'refs/heads/loop/fix-GH*' 2>/dev/null)
}

case "$LOOP" in
  --check-nogo)        LOG=/dev/stderr; read -r N F <<<"$(check_nogo "$PROJECT_DIR" "$CHECK_ARG")"; echo "nogo_reverts=$N nogo_revert_failures=$F"; (( N + F > 0 )) && exit 3 || exit 0 ;;
  --check-self-accept) LOG=/dev/stderr; N=$(check_self_accept "$CHECK_ARG"); echo "self_accepts_stripped=$N"; (( N > 0 )) && exit 3 || exit 0 ;;
  --check-queue-lint)  LOG=/dev/stderr; N=$(check_queue_lint "$CHECK_ARG"); echo "queue_lint_violations=$N"; (( N > 0 )) && exit 3 || exit 0 ;;
esac

# ── 1. singleton lock (mkdir is atomic; macOS ships no flock) ─────────────
LOCK="$STATE_DIR/lock/$LOOP"
if ! mkdir "$LOCK" 2>/dev/null; then
  OLD_PID=$(cat "$LOCK/pid" 2>/dev/null)
  if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
    log "already running (pid $OLD_PID); exiting"; exit 0
  fi
  rm -rf "$LOCK"; mkdir "$LOCK" 2>/dev/null || exit 0
fi
echo $$ >"$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT INT TERM

# ── 2. kill switch, breaker, retention ────────────────────────────────────
if [[ -e "$PROJECT_DIR/ops/PAUSE" ]]; then
  log "PAUSED: $(head -c 200 "$PROJECT_DIR/ops/PAUSE" 2>/dev/null)"; record_run paused; exit 0
fi
BRK="$STATE_DIR/breaker-$LOOP"
if [[ -e "$BRK" ]]; then
  log "breaker latched ($(head -c 120 "$BRK" 2>/dev/null)); rm $BRK to re-arm"
  notify "$PROJECT_NAME $LOOP" "breaker latched — fix the cause, then: rm $BRK"
  record_run breaker; exit 1
fi
# "breaker" rows count as reset markers: a trip writes one, so after the
# documented recovery (rm the flag) the window is error,error,breaker — not
# three straight failures — and only 3 NEW failures can re-trip.
LAST3=$(tail -200 "$STATE_DIR/runs.jsonl" 2>/dev/null | jq -rRs --arg l "$LOOP" \
  '[split("\n")[] | select(length>0) | (fromjson? // empty)
    | select(.loop==$l and (.result=="success" or .result=="error" or .result=="timeout" or .result=="breaker"))]
   | .[-3:] | map(.result) | join(",")' 2>/dev/null)
if [[ "$LAST3" =~ ^(error|timeout),(error|timeout),(error|timeout)$ ]]; then
  printf '%s tripped after: %s\n' "$(date +%F)" "$LAST3" >"$BRK"
  log "circuit breaker tripped: $LAST3"
  notify "$PROJECT_NAME $LOOP" "breaker: 3 consecutive failed runs ($LAST3) — fix cause, then rm $BRK"
  record_run breaker; exit 1
fi
find "$LOG_DIR" -name '*.log' -mtime +14 -delete 2>/dev/null
find "$STATE_DIR/evidence" -mindepth 1 -maxdepth 1 -mtime +30 -exec rm -rf {} + 2>/dev/null
if [[ -f "$STATE_DIR/runs.jsonl" ]] && (( $(wc -l <"$STATE_DIR/runs.jsonl") > 500 )); then
  tail -500 "$STATE_DIR/runs.jsonl" >"$STATE_DIR/runs.jsonl.tmp" && mv "$STATE_DIR/runs.jsonl.tmp" "$STATE_DIR/runs.jsonl"
fi

# ── 3. preflight ───────────────────────────────────────────────────────────
log "preflight starting"
"$ILOOP_ROOT/bin/preflight.sh" "$LOOP" "$CONFIG" >"$STATE_DIR/preflight-$LOOP.json" 2>>"$LOG"
VERDICT=$(jq -r '.verdict // "abort"' "$STATE_DIR/preflight-$LOOP.json" 2>/dev/null || echo abort)
if [[ "$VERDICT" != "run" ]]; then
  REASON=$(jq -r '.abort_reason // "preflight unreadable"' "$STATE_DIR/preflight-$LOOP.json" 2>/dev/null)
  log "preflight abort: $REASON"; notify "$PROJECT_NAME $LOOP" "preflight abort: $REASON"
  RC=1; record_run preflight_abort; exit 1
fi
log "preflight ok"

# ── 4. the run: keep-awake + hard timeout around one headless agent ───────
export ILOOP_ROOT ILOOP_CONFIG="$CONFIG" ILOOP_RUN_ID="$TS" ILOOP_STATE="$STATE_DIR"
export ILOOP_DEADLINE_EPOCH=$(( $(date +%s) + TIMEOUT_S - 300 ))
TIMEOUT_BIN=$(command -v gtimeout || command -v timeout)
KEEPAWAKE=(env); [[ "$(uname)" == "Darwin" ]] && KEEPAWAKE=(/usr/bin/caffeinate -dims)
AGENT_PROMPT_FILE="$ILOOP_ROOT/agents/$LOOP/AGENT.md"
[[ -f "$AGENT_PROMPT_FILE" ]] || { log "no agent prompt at $AGENT_PROMPT_FILE"; RC=1; record_run error; exit 1; }
DIGEST="$PROJECT_DIR/ops/reports/$(date +%F).md"
DIGEST_PRE_LINES=$(wc -l 2>/dev/null <"$DIGEST" || echo 0)
HEAD_BEFORE=$(git -C "$PROJECT_DIR" rev-parse HEAD)
cd "$PROJECT_DIR" || { RC=1; record_run error; exit 1; }
log "invoking $RUNNER_BIN for $LOOP (timeout ${TIMEOUT_S}s)"
"${KEEPAWAKE[@]}" "$TIMEOUT_BIN" --kill-after=60 "$TIMEOUT_S" \
  "$RUNNER_BIN" -p "$(cat "$AGENT_PROMPT_FILE")" "${RUNNER_FLAGS[@]}" >>"$LOG" 2>&1
RC=$?
COST=$(grep '"type":"result"' "$LOG" | tail -1 | jq -r '.total_cost_usd // 0' 2>/dev/null); COST=${COST:-0}
log "agent exited rc=$RC cost=\$$COST"

# ── 5. post-run floors ──────────────────────────────────────────────────────
read -r NOGO_OK NOGO_FAILED <<<"$(check_nogo "$PROJECT_DIR" "$HEAD_BEFORE")"
NOGO_REVERTS=$(( NOGO_OK + NOGO_FAILED ))   # a failed revert is still a violation
if (( NOGO_OK > 0 )); then
  printf '%s no-go violation: %s commit(s) reverted by wrapper\n' "$(date +%F)" "$NOGO_OK" >"$PROJECT_DIR/ops/DEMOTED"
  notify "$PROJECT_NAME $LOOP" "NO-GO VIOLATION: $NOGO_OK commit(s) reverted; loops demoted to propose-only"
fi
if (( NOGO_FAILED > 0 )); then
  printf '%s no-go violation: %s commit(s) could NOT be reverted — needs human\n' "$(date +%F)" "$NOGO_FAILED" >>"$PROJECT_DIR/ops/DEMOTED"
  notify "$PROJECT_NAME $LOOP" "NO-GO VIOLATION: $NOGO_FAILED commit(s) could NOT be reverted — needs human; loops demoted to propose-only"
fi
SELF_ACCEPTS=$(check_self_accept "$START_ISO")
if (( SELF_ACCEPTS > 0 )); then
  printf '%s self-accept guard: %s label(s) stripped\n' "$(date +%F)" "$SELF_ACCEPTS" >"$PROJECT_DIR/ops/DEMOTED"
  notify "$PROJECT_NAME $LOOP" "self-accept guard: stripped $SELF_ACCEPTS accepted label(s) applied mid-run — re-apply if that was you"
fi
QUEUE_LINT=$(check_queue_lint "$START_ISO")
(( QUEUE_LINT > 0 )) && notify "$PROJECT_NAME $LOOP" "queue lint: $QUEUE_LINT malformed issue(s) filed this run — see $(basename "$LOG")"
prune_stale_loop_branches
COMMITS=$(git rev-list --count "$HEAD_BEFORE"..HEAD 2>/dev/null || echo 0)
read -r INS DEL <<<"$(git diff --numstat "$HEAD_BEFORE"..HEAD 2>/dev/null | awk '{i+=$1; d+=$2} END{printf "%d %d", i, d}')"

# ── 6. digest guarantee, per-run notify fan-out, run history ───────────────
if [[ "$LOOP" == "orchestrator" && ! -f "$DIGEST" ]]; then
  mkdir -p "$PROJECT_DIR/ops/reports"
  if (( RC == 0 )); then
    printf '# %s daily — %s — orchestrator completed (rc=0) but wrote no digest — wrapper fallback\n\nStatus: 🟡 wrapper stub\nSee log: %s\n' \
      "$PROJECT_NAME" "$(date +%F)" "$LOG" >"$DIGEST"
  else
    printf '# %s daily — %s — orchestrator FAILED before writing a digest (rc=%s)\n\nStatus: 🔴 wrapper stub\nSee log: %s\n' \
      "$PROJECT_NAME" "$(date +%F)" "$RC" "$LOG" >"$DIGEST"
  fi
fi
if (( RC != 0 )); then
  MSG="rc=$RC"; (( RC == 124 )) && MSG="TIMED OUT after ${TIMEOUT_S}s"
  notify "$PROJECT_NAME $LOOP failed" "$MSG — log: $(basename "$LOG")"
fi
if [[ -f "$DIGEST" ]]; then
  tail -n +"$(( DIGEST_PRE_LINES + 1 ))" "$DIGEST" 2>/dev/null | \
  grep '^> NOTIFY:' | sed 's/^> NOTIFY:[[:space:]]*//' | head -3 | \
  while IFS= read -r m; do notify "$PROJECT_NAME $LOOP" "$m"; done
fi
case "$RC" in
  0)   record_run success ;;
  124) record_run timeout ;;
  *)   record_run error ;;
esac
exit "$RC"
