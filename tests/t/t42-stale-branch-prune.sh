#!/usr/bin/env bash
# T42 — stale loop-branch prune: a local loop/fix-GH<n> branch whose PR is
# MERGED or CLOSED is deleted post-run, so the fixer's "branch exists ⇒
# ineligible" rule cannot block a re-fix forever (issue #15). Branches with
# an OPEN PR or no PR, and non-loop-prefixed branches, are untouched.
source "$(dirname "$0")/../lib.sh"
t_setup

# Seed local branches in the fixture project.
t_git branch loop/fix-GH2      # PR CLOSED  → pruned
t_git branch loop/fix-GH3      # PR MERGED  → pruned
t_git branch loop/fix-GH7      # PR OPEN    → kept
t_git branch loop/fix-GH9      # no PR      → kept
t_git branch loop/fix-GH11-wip # not exactly loop/fix-GH<n> → kept
t_git branch human/feature     # human branch → kept, never even looked up

# Canned `gh pr list --head <branch> --json state` fixtures (/ → __).
mkdir -p "$T_GH/prs"
echo '[{"state":"CLOSED"}]' >"$T_GH/prs/loop__fix-GH2.json"
echo '[{"state":"MERGED"}]' >"$T_GH/prs/loop__fix-GH3.json"
echo '[{"state":"OPEN"}]'   >"$T_GH/prs/loop__fix-GH7.json"

t_run_loop orchestrator
t_assert_rc 0

BRANCHES=$(t_git for-each-ref --format='%(refname:short)' refs/heads/)
t_assert_not_contains "$BRANCHES" "loop/fix-GH2"
t_assert_not_contains "$BRANCHES" "loop/fix-GH3"
t_assert_contains "$BRANCHES" "loop/fix-GH7"
t_assert_contains "$BRANCHES" "loop/fix-GH9"
t_assert_contains "$BRANCHES" "loop/fix-GH11-wip"
t_assert_contains "$BRANCHES" "human/feature"

RUNLOG=$(t_runlog orchestrator)
t_assert_contains "$RUNLOG" "stale-branch prune: deleted loop/fix-GH2 (PR CLOSED)"
t_assert_contains "$RUNLOG" "stale-branch prune: deleted loop/fix-GH3 (PR MERGED)"
t_assert_not_contains "$RUNLOG" "stale-branch prune: deleted loop/fix-GH7"
t_assert_not_contains "$RUNLOG" "stale-branch prune: deleted loop/fix-GH9"
