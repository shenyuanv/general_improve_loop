#!/usr/bin/env bash
# T30 — install.sh: scaffolds completely, is idempotent, and never
# overwrites an existing config or DIRECTION.
source "$(dirname "$0")/../lib.sh"
t_setup

tgt="$T_SB/scratch"
mkdir -p "$tgt"
t_env git -C "$tgt" init -q
echo "hello" >"$tgt/README.md"
t_env git -C "$tgt" add -A
t_env git -C "$tgt" commit -qm "seed"

# first run scaffolds
bash "$T_REPO/install.sh" "$tgt" >"$T_CAP/install1.out"
for p in ops/reports/weekly ops/ledger ops/metrics; do t_assert_exists "$tgt/$p"; done
for l in journeys deploys tester; do t_assert_exists "$tgt/ops/ledger/$l.jsonl"; done
t_assert_exists "$tgt/ops/DIRECTION.md"
t_assert_contains "$tgt/ops/loop.config.sh" "ILOOP_ROOT=\"$T_REPO\""
t_assert_contains "$tgt/ops/loop.config.sh" "PROJECT_DIR=\"$tgt\""
t_assert_contains "$tgt/.gitignore" "improve-loop"
t_assert_absent "$tgt/.gitattributes"          # only appended when pre-existing

# second run keeps human edits
echo "# SENTINEL-CONFIG" >>"$tgt/ops/loop.config.sh"
echo "# SENTINEL-DIRECTION" >>"$tgt/ops/DIRECTION.md"
bash "$T_REPO/install.sh" "$tgt" >"$T_CAP/install2.out"
t_assert_contains "$T_CAP/install2.out" "kept existing"
t_assert_contains "$tgt/ops/loop.config.sh" "SENTINEL-CONFIG"
t_assert_contains "$tgt/ops/DIRECTION.md" "SENTINEL-DIRECTION"
t_assert_eq "$(grep -c "improve-loop" "$tgt/.gitignore")" "1" "gitignore appended once"

# .gitattributes: appended when present, exactly once across reruns
echo "*.png binary" >"$tgt/.gitattributes"
bash "$T_REPO/install.sh" "$tgt" >/dev/null
bash "$T_REPO/install.sh" "$tgt" >/dev/null
t_assert_eq "$(grep -c "^/ops export-ignore" "$tgt/.gitattributes")" "1" "gitattributes appended once"
t_assert_contains "$tgt/.gitattributes" "*.png binary"

# refuses a non-repo
mkdir -p "$T_SB/notrepo"
set +e
bash "$T_REPO/install.sh" "$T_SB/notrepo" >/dev/null 2>"$T_CAP/install-err.out"
T_RC=$?
set -e
t_assert_rc 1
t_assert_contains "$T_CAP/install-err.out" "not a git repo"
