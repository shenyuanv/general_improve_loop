#!/usr/bin/env bash
# selfhost/promote.sh [--live <dir>] [--state <dir>] <source-repo> [<sha>]
#
# "Deploy" for the self-hosted engine: fast-forward the LIVE checkout (the
# one launchd/cron actually executes) to verified main. The live checkout's
# origin is the source repo's origin URL — promotion follows what was
# MERGED, never the dev tree's local state. Records every move in
# $state/promotions.jsonl so rollback.sh can undo it.
#
# Exit: 0 promoted/already-current · 2 diverged (human) · 3 dirty live
#       (tamper signal) · 4 cannot resolve source/sha · 5 misuse.
set -euo pipefail

LIVE="$HOME/.improve-loop/general_improve_loop/live"
STATE="$HOME/.improve-loop/general_improve_loop"
SRC=""; SHA_ARG=""
while (( $# )); do
  case "$1" in
    --live)  LIVE="${2:?}"; shift 2 ;;
    --state) STATE="${2:?}"; shift 2 ;;
    -*) echo "unknown flag $1" >&2; exit 5 ;;
    *) if [[ -z "$SRC" ]]; then SRC="$1"; else SHA_ARG="$1"; fi; shift ;;
  esac
done
[[ -n "$SRC" ]] || { echo "usage: promote.sh [--live <dir>] [--state <dir>] <source-repo> [<sha>]" >&2; exit 5; }

# Never run the gate from inside the artifact it manages
if [[ -d "$LIVE" && "$(pwd -P)" == "$(cd "$LIVE" 2>/dev/null && pwd -P)" ]]; then
  echo "refusing to run from inside the live checkout" >&2; exit 5
fi

URL="$(git -C "$SRC" remote get-url origin 2>/dev/null)" || {
  echo "source $SRC has no origin remote — push it first" >&2; exit 4; }

mkdir -p "$STATE/lock"
LOCK="$STATE/lock/promote"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "another promote is running ($LOCK exists)" >&2; exit 5
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT INT TERM

record() { # $1=action $2=from $3=to
  jq -cn --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg action "$1" \
    --arg from "$2" --arg to "$3" --arg url "$URL" \
    '{ts:$ts, action:$action, from:(if $from=="" then null else $from end), to:$to, url:$url}' \
    >>"$STATE/promotions.jsonl"
}

if [[ ! -d "$LIVE/.git" ]]; then
  mkdir -p "$(dirname "$LIVE")"
  git clone -q "$URL" "$LIVE"
  if [[ -n "$SHA_ARG" ]]; then
    git -C "$LIVE" -c advice.detachedHead=false checkout -q -B main "$SHA_ARG" || {
      echo "cannot check out $SHA_ARG" >&2; exit 4; }
  fi
  TO="$(git -C "$LIVE" rev-parse HEAD)"
  record first-promote "" "$TO"
  echo "first promote: live created at ${TO:0:12}"
  exit 0
fi

if [[ -n "$(git -C "$LIVE" status --porcelain 2>/dev/null)" ]]; then
  echo "live checkout is DIRTY — tamper signal, not auto-cleaned:" >&2
  git -C "$LIVE" status --porcelain >&2
  exit 3
fi

git -C "$LIVE" fetch -q origin
TO="${SHA_ARG:-$(git -C "$LIVE" rev-parse origin/main)}"
git -C "$LIVE" cat-file -e "$TO^{commit}" 2>/dev/null || { echo "cannot resolve target sha $TO" >&2; exit 4; }
FROM="$(git -C "$LIVE" rev-parse HEAD)"

if [[ "$FROM" == "$TO" ]]; then
  echo "already at ${TO:0:12}"
  exit 0
fi
if ! git -C "$LIVE" merge-base --is-ancestor "$FROM" "$TO"; then
  echo "live has DIVERGED from target (live ${FROM:0:12}, target ${TO:0:12}) — needs a human" >&2
  exit 2
fi
git -C "$LIVE" merge -q --ff-only "$TO"
record promote "$FROM" "$TO"
echo "promoted ${FROM:0:12} → ${TO:0:12}"
