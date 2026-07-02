#!/usr/bin/env bash
# install.sh <target-project-dir> — scaffold a project for the improve loop.
# Idempotent; never overwrites an existing config or DIRECTION.
set -euo pipefail
TARGET="${1:?usage: install.sh /path/to/your/project}"
ILOOP_ROOT="$(cd "$(dirname "$0")" && pwd)"
[[ -d "$TARGET/.git" ]] || { echo "$TARGET is not a git repo" >&2; exit 1; }

mkdir -p "$TARGET/ops/reports/weekly" "$TARGET/ops/ledger" "$TARGET/ops/metrics"
touch "$TARGET/ops/ledger/journeys.jsonl" "$TARGET/ops/ledger/deploys.jsonl" "$TARGET/ops/ledger/tester.jsonl"

CFG="$TARGET/ops/loop.config.sh"
if [[ ! -f "$CFG" ]]; then
  sed -e "s|\$HOME/sourcecode/general_improve_loop|$ILOOP_ROOT|" \
      -e "s|\$HOME/sourcecode/YOUR_PROJECT|$TARGET|" \
      "$ILOOP_ROOT/config/loop.config.example.sh" >"$CFG"
  echo "wrote $CFG — EDIT IT (gates, GH_REPO, no-go paths, optional stages)"
else
  echo "kept existing $CFG"
fi

[[ -f "$TARGET/ops/DIRECTION.md" ]] || { cp "$ILOOP_ROOT/templates/DIRECTION.template.md" "$TARGET/ops/DIRECTION.md"; echo "wrote ops/DIRECTION.md — edit Focus + no-go paths"; }

grep -q "improve-loop" "$TARGET/.gitignore" 2>/dev/null || cat "$ILOOP_ROOT/templates/gitignore.snippet" >>"$TARGET/.gitignore"
if [[ -f "$TARGET/.gitattributes" ]] && ! grep -q "^/ops export-ignore" "$TARGET/.gitattributes"; then
  cat "$ILOOP_ROOT/templates/gitattributes.snippet" >>"$TARGET/.gitattributes"
  echo "appended export-ignore rules to .gitattributes (matters if you 'git archive' releases)"
fi

echo
echo "Next steps:"
echo "  1. \$EDITOR $CFG                      # your project's facts"
echo "  2. \$EDITOR $TARGET/ops/DIRECTION.md   # your priorities + no-go paths"
echo "  3. bash $ILOOP_ROOT/templates/labels.sh <owner/repo>   # create queue labels"
echo "  4. bash $ILOOP_ROOT/bin/run-loop.sh orchestrator $CFG  # supervised first run"
echo "  5. bash $ILOOP_ROOT/bin/install-scheduler.sh $CFG      # go nightly"
echo
echo "Read docs/INTEGRATION.md for the full walkthrough and docs/OPERATIONS.md"
echo "for the morning ritual, breaker reset, and kill switch."
