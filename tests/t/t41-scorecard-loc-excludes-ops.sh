#!/usr/bin/env bash
# T41 — scorecard ratchet: loc_product excludes the loop's own tracked
# ops/** artifacts (digests, metrics, ledgers grow nightly and inflated
# the ratchet ~130 LOC/day), while loc_tests still counts tests/ and a
# real product change still moves the number (#16).
source "$(dirname "$0")/../lib.sh"
t_setup

# Give the fixture product a tests/ tree so loc_tests has signal.
mkdir -p "$T_PROJ/tests"
printf '%s\n' '#!/usr/bin/env bash' 'echo smoke' 'exit 0' >"$T_PROJ/tests/smoke.sh"
t_git add tests/smoke.sh
t_git commit -qm "fixture: add a test file"

scorecard() { # runs the real scorecard; echoes the written json path
  t_env bash "$T_REPO/bin/scorecard.sh" "$T_CFG" >"$T_CAP/scorecard.out" 2>&1 \
    || t_fail "scorecard.sh failed: $(tail -5 "$T_CAP/scorecard.out")"
  ls "$T_PROJ"/ops/metrics/scorecard-*.json | head -1
}
ratchet() { jq -r ".ratchet.$2" "$1"; }

CARD="$(scorecard)"
LOC1="$(ratchet "$CARD" loc_product)"
TESTS1="$(ratchet "$CARD" loc_tests)"
[[ "$TESTS1" -gt 0 ]] || t_fail "loc_tests=$TESTS1, want >0 (tests/ must still count)"

# A night that only adds loop output: tracked digest + metrics artifacts.
mkdir -p "$T_PROJ/ops/reports" "$T_PROJ/ops/metrics"
for i in $(seq 1 100); do echo "digest line $i"; done >"$T_PROJ/ops/reports/2026-01-01.md"
echo '{"seeded": true}' >"$T_PROJ/ops/metrics/2026-01-01.json"
t_git add ops/reports/2026-01-01.md ops/metrics/2026-01-01.json
t_git commit -qm "loop: daily digest + metrics"

CARD="$(scorecard)"
LOC2="$(ratchet "$CARD" loc_product)"
TESTS2="$(ratchet "$CARD" loc_tests)"
t_assert_eq "$LOC2" "$LOC1" "loc_product must not count tracked ops/** artifacts"
t_assert_eq "$TESTS2" "$TESTS1" "loc_tests unaffected by ops/** growth"

# Guard against over-exclusion: product code still moves the ratchet.
echo 'echo more product' >>"$T_PROJ/src/app.sh"
t_git add src/app.sh
t_git commit -qm "fixture: product grows"
CARD="$(scorecard)"
LOC3="$(ratchet "$CARD" loc_product)"
[[ "$LOC3" -gt "$LOC2" ]] || t_fail "loc_product=$LOC3 after product change, want > $LOC2"
