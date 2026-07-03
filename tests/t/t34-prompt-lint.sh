#!/usr/bin/env bash
# T34 — prompt-lint: clean on the real tree; one violation per planted
# break class in a mutated copy.
source "$(dirname "$0")/../lib.sh"
t_setup

# (a) the real tree must be clean (orphan-knob warns don't fail)
set +e
bash "$T_REPO/tests/prompt-lint.sh" "$T_REPO" >"$T_CAP/lint-real.out" 2>&1
T_RC=$?
set -e
t_assert_rc 0
t_assert_contains "$T_CAP/lint-real.out" "prompt-lint: 0 violation(s)"

# (b) plant one break per class in a copy of the scanned tree
tree="$T_SB/tree"
mkdir -p "$tree"
for d in roles contracts config templates bin docs install.sh README.md CLAUDE.md; do
  cp -R "$T_REPO/$d" "$tree/"
done

echo "also read contracts/no-such-thing.md nightly" >>"$tree/roles/orchestrator/orchestrator.md"
echo "honor DEPLOY_MAGIC_CMD before deploying" >>"$tree/roles/developer/fixer.md"
echo 'respect $ILOOP_BOGUS between stages' >>"$tree/roles/tester/e2e-user.md"
echo "spawn roles/developer/subagents/nope.md per issue" >>"$tree/roles/developer/fixer.md"
echo '  "ghost|9|9||60"' >>"$tree/config/loop.config.example.sh"
printf 'grooming may add the `action:ghost` label\n' >>"$tree/contracts/issue-format.md"
echo "honor ops/PASUE before acting" >>"$tree/roles/tester/e2e-tester.md"

echo "duplicate loop probe" >"$tree/roles/tester/fixer.md"       # class 10: dup loop name
rm "$tree/roles/reviewer/CHARTER.md"                              # class 11: missing charter
printf '# ── Floor: canary drill — undocumented on purpose ──\n' >>"$tree/bin/run-loop.sh"   # class 12
printf 'accepted\nloop-filed\nloop-pr\n' >"$tree/bin/fake-encoder.sh"                       # class 13

set +e
bash "$T_REPO/tests/prompt-lint.sh" "$tree" >"$T_CAP/lint-planted.out" 2>&1
T_RC=$?
set -e
t_assert_rc 1
t_assert_contains "$T_CAP/lint-planted.out" "missing-contract: contracts/no-such-thing.md"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-config-var: DEPLOY_MAGIC_CMD"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-iloop-var: ILOOP_BOGUS"
t_assert_contains "$T_CAP/lint-planted.out" "missing-subagent: roles/developer/subagents/nope.md"
t_assert_contains "$T_CAP/lint-planted.out" "schedule-loop-missing: ghost"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-label: action:ghost"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-marker: ops/PASUE"
t_assert_contains "$T_CAP/lint-planted.out" "duplicate-loop: fixer"
t_assert_contains "$T_CAP/lint-planted.out" "missing-charter: CHARTER.md"
t_assert_contains "$T_CAP/lint-planted.out" "undocumented-floor: canary drill"
t_assert_contains "$T_CAP/lint-planted.out" "unlisted-label-encoder: bin/fake-encoder.sh"
