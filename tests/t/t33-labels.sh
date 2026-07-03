#!/usr/bin/env bash
# T33 — templates/labels.sh: the full queue vocabulary is created (or
# repaired via the edit fallback), default and custom component sets honored.
source "$(dirname "$0")/../lib.sh"
t_setup

labels() { t_env "$@" bash "$T_REPO/templates/labels.sh" stub-owner/stub-repo "${EXTRA[@]:-}"; }

# default component set
EXTRA=()
t_env bash "$T_REPO/templates/labels.sh" stub-owner/stub-repo >/dev/null
for l in loop-filed accepted rejected action:loop action:operator action:interactive action:develop bug loop-pr changes-requested; do
  t_assert_contains "$T_CAP/gh-mutations.log" "label create $l"
done
t_assert_contains "$T_CAP/gh-mutations.log" "label create 🙋 needs-your-decision"
for c in cli server docs infra; do
  t_assert_contains "$T_CAP/gh-mutations.log" "label create component:$c"
done
t_assert_eq "$(grep -c "label create" "$T_CAP/gh-mutations.log")" "15"

# custom components
: >"$T_CAP/gh-mutations.log"
t_env bash "$T_REPO/templates/labels.sh" stub-owner/stub-repo engine agents >/dev/null
t_assert_contains "$T_CAP/gh-mutations.log" "label create component:engine"
t_assert_contains "$T_CAP/gh-mutations.log" "label create component:agents"
t_assert_not_contains "$T_CAP/gh-mutations.log" "label create component:cli"
t_assert_eq "$(grep -c "label create" "$T_CAP/gh-mutations.log")" "13"

# create failure falls through to edit (label already exists)
: >"$T_CAP/gh-mutations.log"
t_env T_GH_LABEL_CREATE_RC=1 bash "$T_REPO/templates/labels.sh" stub-owner/stub-repo >/dev/null
t_assert_eq "$(grep -c "label create" "$T_CAP/gh-mutations.log")" "15"
t_assert_eq "$(grep -c "label edit" "$T_CAP/gh-mutations.log")" "15"
