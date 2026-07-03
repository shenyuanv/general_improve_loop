#!/usr/bin/env bash
# templates/labels.sh <owner/repo> [component1 component2 ...]
# Creates the queue-contract labels. Default components: cli server docs infra.
set -euo pipefail
R="${1:?usage: labels.sh <owner/repo> [components...]}"; shift || true
COMPONENTS=("${@:-cli server docs infra}")
[[ $# -eq 0 ]] && COMPONENTS=(cli server docs infra)

mk() { gh label create "$1" -R "$R" --color "$2" --description "$3" 2>/dev/null || \
      gh label edit "$1" -R "$R" --color "$2" --description "$3" >/dev/null; echo "  $1"; }

echo "labels on $R:"
mk "loop-filed"             "5319e7" "Filed by a loop (grooming may edit these only)"
mk "accepted"               "0e8a16" "Human-approved: authorizes exactly the action:* executor"
mk "rejected"               "d93f0b" "Human-declined"
mk "action:loop"            "1d76db" "Auto-fixable once accepted or cooled (needs bug+Repro+Verify)"
mk "action:operator"        "fbca04" "Human runs the commands in the body"
mk "action:interactive"     "0b6157" "Paste the body's stated ask into an agent session"
mk "action:develop"         "5319e7" "Design-grade work: enters the developer lane only when accepted AND develop_pipeline: on"
mk "bug"                    "b60205" "Defect; enters the fix pipeline only with a runnable Repro"
mk "🙋 needs-your-decision" "b60205" "Owner call: read Options in the body, act or reply Option X"
mk "loop-pr"                "b60205" "PR opened by the fixer; pr-verifier reviews it"
mk "changes-requested"      "d93f0b" "Verifier rejected the PR; evidence in its comment"
for c in "${COMPONENTS[@]}"; do mk "component:$c" "0052cc" "Component: $c"; done
