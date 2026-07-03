#!/usr/bin/env bash
# tests/run.sh [name-filter…] [--list] [-v] — the harness's own test suite.
#
# Zero-dependency runner: each tests/t/*.sh is one hermetic test process;
# nonzero exit = failure. A marker file tests/known-failures.d/<test-name>
# pins a KNOWN bug: the test reports xfail while the bug exists and XPASS
# (suite failure) once fixed without flipping the pin — a PR that fixes a
# pinned bug must also `git rm` its marker, which is the mechanical
# fail-before/pass-after evidence the pr-verifier checks. One marker file
# per pin keeps concurrent pin flips conflict-free (issue #34).
#
# Final line is machine-parseable (the gardener ratchet reads `collected=`):
#   collected=N passed=N failed=N xfail=N xpass=N
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

VERBOSE=0; LIST=0; FILTERS=()
for a in "$@"; do
  case "$a" in
    -v) VERBOSE=1 ;;
    --list) LIST=1 ;;
    *) FILTERS+=("$a") ;;
  esac
done

TIMEOUT_BIN=$(command -v gtimeout || command -v timeout)
[[ -n "$TIMEOUT_BIN" ]] || { echo "need GNU timeout (gtimeout) on PATH" >&2; exit 2; }
KNOWN_D="tests/known-failures.d"
ART="$(mktemp -d "${TMPDIR:-/tmp}/iloop-test-art.XXXXXX")"

is_known() { [[ -f "$KNOWN_D/$1" ]]; }

collected=0; passed=0; failed=0; xfail=0; xpass=0
for f in tests/t/*.sh; do
  [[ -e "$f" ]] || break
  name="$(basename "$f" .sh)"
  if (( ${#FILTERS[@]} )); then
    hit=0
    for flt in "${FILTERS[@]}"; do [[ "$name" == *"$flt"* ]] && hit=1; done
    (( hit )) || continue
  fi
  if (( LIST )); then echo "$name"; continue; fi
  collected=$((collected + 1))
  start=$SECONDS
  out="$ART/$name.out"
  if "$TIMEOUT_BIN" --kill-after=10 90 bash "$f" >"$out" 2>&1; then
    if is_known "$name"; then
      xpass=$((xpass + 1)); printf 'not ok %s XPASS — passes but pinned by %s (bug fixed? git rm the marker)\n' "$name" "$KNOWN_D/$name"
    else
      passed=$((passed + 1)); printf 'ok %s (%ss)\n' "$name" "$((SECONDS - start))"
    fi
  else
    rc=$?
    if is_known "$name"; then
      xfail=$((xfail + 1)); printf 'ok %s xfail — pins a known bug (%s)\n' "$name" "$KNOWN_D/$name"
    else
      failed=$((failed + 1)); printf 'not ok %s (rc=%s) — output:\n' "$name" "$rc"
      sed 's/^/    /' "$out"
    fi
  fi
  (( VERBOSE )) && sed 's/^/    /' "$out"
done
(( LIST )) && exit 0

echo "collected=$collected passed=$passed failed=$failed xfail=$xfail xpass=$xpass"
if (( failed > 0 || xpass > 0 )); then
  echo "artifacts: $ART"
  exit 1
fi
rm -rf "$ART"
exit 0
