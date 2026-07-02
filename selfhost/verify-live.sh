#!/usr/bin/env bash
# selfhost/verify-live.sh [--live <dir>]
#
# DEPLOY_VERIFY_CMD for the self-hosted engine: exit 0 iff the LIVE checkout
# is healthy — clean tree, its OWN test suite green, prompt-lint green,
# lint-clean shell (shellcheck), and a real floor drill (a planted no-go
# violation in a throwaway fixture must be caught with exit 3). This proves
# the deployed floors BITE, not merely that files copied.
set -uo pipefail

LIVE="$HOME/.improve-loop/general_improve_loop/live"
while (( $# )); do
  case "$1" in
    --live) LIVE="${2:?}"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 1 ;;
  esac
done

TO="$(command -v gtimeout || command -v timeout)"
[[ -n "$TO" ]] || { echo "verify-live: need GNU timeout" >&2; exit 1; }
fail() { echo "verify-live FAIL: $*" >&2; exit 1; }

[[ -d "$LIVE/.git" ]] || fail "no live checkout at $LIVE"
[[ -z "$(git -C "$LIVE" status --porcelain 2>/dev/null)" ]] || fail "live tree dirty"

echo "verify-live: [1/4] live test suite"
( cd "$LIVE" && "$TO" 600 bash tests/run.sh ) || fail "live tests red"

echo "verify-live: [2/4] prompt-lint"
( cd "$LIVE" && "$TO" 120 bash tests/prompt-lint.sh ) || fail "prompt-lint red"

echo "verify-live: [3/4] shellcheck"
command -v shellcheck >/dev/null || fail "shellcheck not installed"
( cd "$LIVE" && "$TO" 120 shellcheck --severity=warning bin/*.sh install.sh templates/labels.sh selfhost/*.sh tests/*.sh ) \
  || fail "shellcheck red"

echo "verify-live: [4/4] floor drill (no-go revert must bite)"
DRILL="$(mktemp -d "${TMPDIR:-/tmp}/verify-live-drill.XXXXXX")"
trap 'rm -rf "$DRILL"' EXIT INT TERM
CFG="$("$TO" 120 bash "$LIVE/selfhost/fixture.sh" "$DRILL" --engine "$LIVE" --force)" || fail "fixture generation broke"
denv() { env HOME="$DRILL/home" GIT_CONFIG_NOSYSTEM=1 "$@"; }
BASE="$(denv git -C "$DRILL/proj" rev-parse HEAD)"
echo "drill tamper" >>"$DRILL/proj/ops/DIRECTION.md"
denv git -C "$DRILL/proj" add ops/DIRECTION.md
denv git -C "$DRILL/proj" commit -qm "drill: nogo violation"

set +e
denv "$TO" 300 bash "$LIVE/bin/run-loop.sh" --check-nogo "$BASE" "$CFG" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" == 3 ]] || fail "planted violation not caught (--check-nogo rc=$rc, want 3)"

set +e
denv "$TO" 300 bash "$LIVE/bin/run-loop.sh" --check-nogo "$(denv git -C "$DRILL/proj" rev-parse HEAD)" "$CFG" >/dev/null 2>&1
rc=$?
set -e
[[ "$rc" == 0 ]] || fail "clean tree flagged (--check-nogo rc=$rc, want 0)"

echo "verify-live: healthy at $(git -C "$LIVE" rev-parse --short HEAD)"
exit 0
