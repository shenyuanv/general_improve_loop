#!/usr/bin/env bash
# tests/prompt-lint.sh [root] — static cross-reference checker for the
# load-bearing markdown. The prompts, contracts, config, wrapper, and label
# templates name each other by literal path/variable/label; this gate fails
# the moment a rename breaks a reference some agent will follow at 3 AM.
#
# Violations print as `<file>: <class>: <token>` and fail the run.
# Orphan knobs (assigned in the example config, referenced nowhere) are
# WARN-only: advisory, not a broken reference.
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || { echo "cannot cd $ROOT" >&2; exit 2; }

fails=0
viol() { printf '%s: %s: %s\n' "$1" "$2" "$3"; fails=$((fails + 1)); }
warn() { printf 'warn: %s: %s: %s\n' "$1" "$2" "$3"; }

PROMPTS=(roles/*/*.md roles/*/subagents/*.md)   # CHARTERs included: they carry refs too
CONTRACTS=(contracts/*.md)
REF_SOURCES=("${PROMPTS[@]}" "${CONTRACTS[@]}" bin/*.sh install.sh docs/*.md README.md CLAUDE.md)

# ── 1. contract refs resolve (incl. brace forms); every contract is used ──
expand_braces() { # contracts/{a,b}.md → one path per line
  local t="$1" pre body list post part
  if [[ "$t" != *"{"* ]]; then printf '%s\n' "$t"; return; fi
  pre="${t%%\{*}"; body="${t#*\{}"; list="${body%%\}*}"; post="${body#*\}}"
  IFS=',' read -ra parts <<<"$list"
  for part in "${parts[@]}"; do printf '%s%s%s\n' "$pre" "$part" "$post"; done
}
for f in "${REF_SOURCES[@]}"; do
  [[ -f "$f" ]] || continue
  while IFS= read -r tok; do
    while IFS= read -r p; do
      [[ -f "$p" ]] || viol "$f" "missing-contract" "$p"
    done < <(expand_braces "$tok")
  done < <(grep -ohE 'contracts/[A-Za-z0-9_{},-]+\.md' "$f" 2>/dev/null | sort -u)
done
for c in contracts/*.md; do
  base="$(basename "$c")"
  hit=0
  for f in "${PROMPTS[@]}" bin/*.sh install.sh docs/*.md README.md CLAUDE.md; do
    [[ -f "$f" && "$f" != "$c" ]] || continue
    grep -q "$base" "$f" && { hit=1; break; }
  done
  (( hit )) || viol "$c" "unreferenced-contract" "$base"
done

# ── 2. subagent refs resolve; every subagent file has a dispatcher ref ────
for f in roles/*/*.md; do
  [[ -f "$f" ]] || continue
  while IFS= read -r r; do
    [[ -f "$r" ]] || viol "$f" "missing-subagent" "$r"
  done < <(grep -ohE 'roles/[a-z-]+/subagents/[a-z0-9-]+\.md' "$f" 2>/dev/null | sort -u)
done
# the orchestrator names its four focus subagents in prose, not by path
for s in guardian operator gardener analyst; do
  [[ -f "roles/orchestrator/subagents/$s.md" ]] || viol "roles/orchestrator/orchestrator.md" "missing-subagent" "$s.md"
done
# inverse: every subagent is referenced by a sibling LOOP prompt (not just a charter)
for sf in roles/*/subagents/*.md; do
  [[ -f "$sf" ]] || continue
  role_dir="$(dirname "$(dirname "$sf")")"
  base="$(basename "$sf" .md)"
  hit=0
  for lp in "$role_dir"/*.md; do
    [[ "$(basename "$lp")" == "CHARTER.md" ]] && continue
    grep -q "$base" "$lp" && { hit=1; break; }
  done
  (( hit )) || viol "$sf" "unreferenced-subagent" "$base"
done

# ── 3. SCHEDULE ↔ roles/*/<loop>.md both directions ──────────────────────────
while IFS= read -r l; do
  pf=(roles/*/"$l".md)
  [[ -f "${pf[0]}" ]] || viol "config/loop.config.example.sh" "schedule-loop-missing" "$l"
done < <(grep -oE '^[[:space:]]*"[a-z0-9-]+\|' config/loop.config.example.sh | tr -d ' "|')
for lp in roles/*/*.md; do
  [[ -f "$lp" ]] || continue
  l="$(basename "$lp" .md)"
  [[ "$l" == "CHARTER" ]] && continue
  grep -qE "^[[:space:]]*\"$l\|" config/loop.config.example.sh || viol "$lp" "loop-not-scheduled" "$l"
done

# ── 4. config vars named in prompts/contracts exist in the example config ─
VAR_PATTERN='GATES|NOGO_PATHS|COOLING_HOURS|MAX_FIXES_PER_NIGHT|MAX_VERIFIES_PER_NIGHT|DEPLOY_[A-Z_]+|E2E_[A-Z_]+|TELEMETRY_DESC|GH_REPO|GH_AUTH_USER|DIGEST_RETENTION_DAYS|STATE_DIR|LOOP_TIMEOUT_S|RUNNER_[A-Z_]+|NOTIFY_[A-Z_]+|SCHEDULE|PROJECT_DIR|PROJECT_NAME|PROJECT_PREFLIGHT_HOOK'
assigned="$(grep -E '^[A-Z_][A-Z0-9_]*=' config/loop.config.example.sh | cut -d= -f1)"
allowed="$assigned
LOOP_TIMEOUT_S"
for f in "${PROMPTS[@]}" "${CONTRACTS[@]}"; do
  [[ -f "$f" ]] || continue
  while IFS= read -r v; do
    grep -qx "$v" <<<"$allowed" || viol "$f" "unknown-config-var" "$v"
  done < <(grep -ohE "\b($VAR_PATTERN)\b" "$f" 2>/dev/null | sort -u)
done
while IFS= read -r v; do
  grep -rqw "$v" bin roles contracts docs install.sh 2>/dev/null || warn "config/loop.config.example.sh" "orphan-knob" "$v"
done <<<"$assigned"

# ── 5. ILOOP_* tokens ⊆ what the wrapper actually exports ─────────────────
iloop_allowed="$(grep -ohE 'ILOOP_[A-Z_]+' bin/run-loop.sh config/loop.config.example.sh | sort -u)"
for f in "${PROMPTS[@]}" "${CONTRACTS[@]}" docs/*.md; do
  [[ -f "$f" ]] || continue
  while IFS= read -r v; do
    grep -qx "$v" <<<"$iloop_allowed" || viol "$f" "unknown-iloop-var" "$v"
  done < <(grep -ohE 'ILOOP_[A-Z_]+' "$f" 2>/dev/null | sort -u)
done

# ── 6. label vocabulary: prompts/contracts ⊆ templates/labels.sh canon ────
canon="$(grep -oE '^mk "[^"]+"' templates/labels.sh | sed 's/^mk "//; s/"$//')"
label_ok() {
  grep -qxF "$1" <<<"$canon" && return 0
  case "$1" in
    action:\*|component:\*|"component:<area>") return 0 ;;   # documented wildcards
    component:[a-z]*) return 0 ;;                             # projects define their own set
  esac
  return 1
}
for f in "${PROMPTS[@]}" "${CONTRACTS[@]}"; do
  [[ -f "$f" ]] || continue
  while IFS= read -r t; do
    label_ok "$t" || viol "$f" "unknown-label" "$t"
  done < <(grep -ohE '`[^`]+`' "$f" 2>/dev/null | tr -d '`' | grep -E '^(loop-filed|accepted|rejected|bug|loop-pr|changes-requested|🙋 needs-your-decision|action:[a-z*]+|component:[a-z*<>-]+)$' | sort -u)
done
# the wrapper's own hardcoded label literals must not drift out of the vocabulary
for lit in loop-filed accepted action: component: bug; do
  grep -q "$lit" bin/run-loop.sh || viol "bin/run-loop.sh" "wrapper-label-drift" "$lit"
done

# ── 7. marker-file spellings: ops/<UPPER> must be a known marker ──────────
for f in "${PROMPTS[@]}" "${CONTRACTS[@]}" docs/*.md bin/*.sh README.md; do
  [[ -f "$f" ]] || continue
  while IFS= read -r t; do
    [[ "$t" == *.* ]] && continue
    case "${t#ops/}" in PAUSE|DEMOTED|BLOCKED) ;; *) viol "$f" "unknown-marker" "$t" ;; esac
  done < <(grep -ohE 'ops/[A-Z_]+(\.[A-Za-z]+)?' "$f" 2>/dev/null | sort -u)
done

# ── 8. adopter-facing docs use placeholders, not the maintainer's clone ───
# (SELF-HOSTING.md deliberately documents the maintainer's own deployment,
#  and install.sh's sed consumes the example config's literal — both exempt.)
for f in docs/INTEGRATION.md README.md; do
  [[ -f "$f" ]] || continue
  while IFS= read -r t; do
    viol "$f" "maintainer-path" "$t"
  done < <(grep -ohE '[~A-Za-z0-9_/.$-]*sourcecode/[A-Za-z0-9_.-]+' "$f" 2>/dev/null | sort -u)
done

# ── 9. subagent Return shapes match what the dispatchers parse ────────────
for k in "issue:" "outcome:" "pr_url" "evidence"; do
  grep -q "$k" roles/developer/subagents/fix-one-issue.md || viol "roles/developer/subagents/fix-one-issue.md" "return-shape" "$k"
done
for k in "pr-opened" "repro-failed" "abandoned"; do
  grep -q "$k" roles/developer/fixer.md || viol "roles/developer/fixer.md" "return-shape" "$k"
done
for k in "issue:" "outcome:" "pr_url" "evidence"; do
  grep -q "$k" roles/developer/subagents/develop-one-issue.md || viol "roles/developer/subagents/develop-one-issue.md" "return-shape" "$k"
done
for k in "pr:" "verdict:" "evidence"; do
  grep -q "$k" roles/reviewer/subagents/verify-one-pr.md || viol "roles/reviewer/subagents/verify-one-pr.md" "return-shape" "$k"
done
for k in "PASS" "FAIL" "CI_PENDING"; do
  grep -q "$k" roles/reviewer/pr-verifier.md || viol "roles/reviewer/pr-verifier.md" "return-shape" "$k"
done

# ── 10. loop names unique across roles (the parallel-collision lesson) ────
while IFS= read -r d; do
  [[ -n "$d" ]] && viol "roles/" "duplicate-loop" "$d"
done < <(for lp in roles/*/*.md; do b="$(basename "$lp" .md)"; [[ "$b" == "CHARTER" ]] || echo "$b"; done | sort | uniq -d)

# ── 11. every role has a CHARTER; every role but owner has a loop prompt ──
for d in roles/*/; do
  role="$(basename "$d")"
  [[ -f "${d}CHARTER.md" ]] || viol "roles/$role" "missing-charter" "CHARTER.md"
  if [[ "$role" != "owner" ]]; then
    lc=0
    for lp in "${d}"*.md; do
      [[ -f "$lp" && "$(basename "$lp")" != "CHARTER.md" ]] && lc=$((lc + 1))
    done
    (( lc >= 1 )) || viol "roles/$role" "role-without-loop" "$role"
  fi
done

echo "prompt-lint: $fails violation(s)"
(( fails > 0 )) && exit 1
exit 0
