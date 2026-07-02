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
for d in agents contracts config templates bin docs install.sh README.md CLAUDE.md; do
  cp -R "$T_REPO/$d" "$tree/"
done

echo "also read contracts/no-such-thing.md nightly" >>"$tree/agents/orchestrator/AGENT.md"
echo "honor DEPLOY_MAGIC_CMD before deploying" >>"$tree/agents/fixer/AGENT.md"
echo 'respect $ILOOP_BOGUS between stages' >>"$tree/agents/e2e-user/AGENT.md"
echo "spawn agents/fixer/subagents/nope.md per issue" >>"$tree/agents/fixer/AGENT.md"
echo '  "ghost|9|9||60"' >>"$tree/config/loop.config.example.sh"
printf 'grooming may add the `action:ghost` label\n' >>"$tree/contracts/issue-format.md"
echo "honor ops/PASUE before acting" >>"$tree/agents/e2e-tester/AGENT.md"

set +e
bash "$T_REPO/tests/prompt-lint.sh" "$tree" >"$T_CAP/lint-planted.out" 2>&1
T_RC=$?
set -e
t_assert_rc 1
t_assert_contains "$T_CAP/lint-planted.out" "missing-contract: contracts/no-such-thing.md"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-config-var: DEPLOY_MAGIC_CMD"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-iloop-var: ILOOP_BOGUS"
t_assert_contains "$T_CAP/lint-planted.out" "missing-subagent: agents/fixer/subagents/nope.md"
t_assert_contains "$T_CAP/lint-planted.out" "schedule-loop-missing: ghost"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-label: action:ghost"
t_assert_contains "$T_CAP/lint-planted.out" "unknown-marker: ops/PASUE"
