#!/usr/bin/env bash
# selfhost/rollback.sh [--live <dir>] [--state <dir>]
#
# Restore the live checkout to the sha recorded before the last promote.
# CODE ONLY by construction: live is a deploy artifact holding nothing but
# the engine's files — reset --hard is correct here (the write-policy's
# no-reset rule protects shared working trees, which live is not). A dirty
# live gets its evidence quarantined first, never silently destroyed.
#
# Exit: 0 rolled back · 4 nothing to roll back to.
set -euo pipefail

LIVE="$HOME/.improve-loop/general_improve_loop/live"
STATE="$HOME/.improve-loop/general_improve_loop"
while (( $# )); do
  case "$1" in
    --live)  LIVE="${2:?}"; shift 2 ;;
    --state) STATE="${2:?}"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 4 ;;
  esac
done

[[ -d "$LIVE/.git" ]] || { echo "no live checkout at $LIVE" >&2; exit 4; }
PROM="$STATE/promotions.jsonl"
PREV="$(tail -1 "$PROM" 2>/dev/null | jq -r '.from // empty')"
if [[ -z "$PREV" ]]; then
  echo "no previous sha recorded (first promote?) — leaving live alone" >&2
  exit 4
fi

if [[ -n "$(git -C "$LIVE" status --porcelain 2>/dev/null)" ]]; then
  Q="$STATE/rollback-quarantine-$(date +%Y%m%d-%H%M%S).txt"
  {
    echo "== dirty live checkout at rollback =="
    git -C "$LIVE" status --porcelain
    git -C "$LIVE" diff
  } >"$Q" 2>&1
  echo "dirty live quarantined to $Q" >&2
fi

FROM="$(git -C "$LIVE" rev-parse HEAD)"
git -C "$LIVE" reset -q --hard "$PREV"
jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg from "$FROM" --arg to "$PREV" \
  '{ts:$ts, action:"rollback", from:$from, to:$to}' >>"$PROM"
echo "rolled back ${FROM:0:12} → ${PREV:0:12}"
