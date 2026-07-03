#!/usr/bin/env bash
# T46 — known-failures pins are per-test marker FILES under
# tests/known-failures.d/ (issue #34): marker exists = pinned (xfail while
# failing, XPASS = suite failure once fixed), the contended single list
# file is gone, and a README in the dir is never a pin. Distinct marker
# paths make concurrent pin flips merge conflict-free by construction.
set -uo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"

# the old single-list file must be gone; the runner must read the dir
[[ ! -f "$repo/tests/known-failures.txt" ]] || { echo "contended tests/known-failures.txt still exists"; exit 1; }
grep -q 'known-failures\.d' "$repo/tests/run.sh" || { echo "tests/run.sh does not read known-failures.d"; exit 1; }

# semantics, exercised against the REAL runner in a sandbox suite
sb="$(mktemp -d "${TMPDIR:-/tmp}/iloop-t46.XXXXXX")"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/tests/t" "$sb/tests/known-failures.d"
cp "$repo/tests/run.sh" "$sb/tests/run.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$sb/tests/t/t01-pass.sh"
printf '#!/usr/bin/env bash\nexit 1\n' >"$sb/tests/t/t02-fail.sh"
echo '#34' >"$sb/tests/known-failures.d/t02-fail"
echo 'directory keeper, not a pin' >"$sb/tests/known-failures.d/README.md"

# pinned failing test → xfail, suite green; README marker inert
out="$(TMPDIR="$sb" bash "$sb/tests/run.sh" 2>&1)"; rc=$?
[[ $rc -eq 0 ]] || { echo "pinned failure must not fail the suite (rc=$rc):"; echo "$out"; exit 1; }
grep -q 'ok t02-fail xfail' <<<"$out" || { echo "no xfail for pinned test:"; echo "$out"; exit 1; }
grep -q 'collected=2 passed=1 failed=0 xfail=1 xpass=0' <<<"$out" || { echo "bad counters:"; echo "$out"; exit 1; }

# pinning a PASSING test → XPASS fails the suite
echo '#34' >"$sb/tests/known-failures.d/t01-pass"
out="$(TMPDIR="$sb" bash "$sb/tests/run.sh" 2>&1)"; rc=$?
[[ $rc -ne 0 ]] || { echo "XPASS must fail the suite:"; echo "$out"; exit 1; }
grep -q 'not ok t01-pass XPASS' <<<"$out" || { echo "no XPASS report:"; echo "$out"; exit 1; }

# the git-rm-shaped flip: markers gone → plain failure counts again
rm "$sb/tests/known-failures.d/t01-pass" "$sb/tests/known-failures.d/t02-fail"
out="$(TMPDIR="$sb" bash "$sb/tests/run.sh" 2>&1)"; rc=$?
[[ $rc -ne 0 ]] || { echo "unpinned failure must fail the suite:"; echo "$out"; exit 1; }
grep -q 'not ok t02-fail' <<<"$out" || { echo "no plain failure for unpinned test:"; echo "$out"; exit 1; }
exit 0
