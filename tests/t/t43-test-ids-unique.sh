#!/usr/bin/env bash
# T43 — one-id-per-test convention: every tests/t/tNN-*.sh numeric prefix
# is unique, so substring filters (`bash tests/run.sh t07`) and
# tests/known-failures.txt pin lines stay unambiguous. Guards against
# parallel PRs each taking the same next free number (issue #21: PRs #18
# and #19 both added a t37-*.sh the same night).
set -uo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
dupes="$(cd "$dir" && ls t*.sh | sed -n 's/^\(t[0-9][0-9]*\)-.*\.sh$/\1/p' | sort | uniq -d)"
if [[ -n "$dupes" ]]; then
  for d in $dupes; do
    echo "duplicate test id $d:" >&2
    (cd "$dir" && ls "$d"-*.sh >&2)
  done
  exit 1
fi
