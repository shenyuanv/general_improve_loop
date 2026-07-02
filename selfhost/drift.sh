#!/usr/bin/env bash
# selfhost/drift.sh [--live <dir>] [--no-fetch]
#
# DEPLOY_DRIFT_CMD for the self-hosted engine: exit 0 iff the live checkout
# is exactly at its origin/main. 1 = drifted (deploy wanted, incl. live
# missing entirely) · 2 = cannot answer (a Needs-you diagnostic).
set -uo pipefail

LIVE="$HOME/.improve-loop/general_improve_loop/live"
FETCH=1
while (( $# )); do
  case "$1" in
    --live) LIVE="${2:?}"; shift 2 ;;
    --no-fetch) FETCH=0; shift ;;
    *) echo "unknown arg $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$LIVE/.git" ]]; then
  echo "drifted: live absent at $LIVE — first promote needed"
  exit 1
fi
if (( FETCH )); then
  git -C "$LIVE" fetch -q origin || { echo "cannot fetch live origin" >&2; exit 2; }
fi
HEAD_SHA="$(git -C "$LIVE" rev-parse HEAD 2>/dev/null)" || { echo "cannot resolve live HEAD" >&2; exit 2; }
MAIN_SHA="$(git -C "$LIVE" rev-parse origin/main 2>/dev/null)" || { echo "cannot resolve origin/main" >&2; exit 2; }

if [[ "$HEAD_SHA" == "$MAIN_SHA" ]]; then
  echo "current at ${HEAD_SHA:0:12}"
  exit 0
fi
echo "drifted: live ${HEAD_SHA:0:12}, origin/main ${MAIN_SHA:0:12}"
exit 1
