#!/usr/bin/env bash
# bin/funnel.sh <config> — the mandatory queue funnel table, mechanically.
#
# Classifies every open issue and every open loop PR into exactly one row
# of contracts/queue-state-machine.md (first matching state wins, in the
# contract's own order); anything matching none is an ORPHAN 🟡. Agents
# run this and ANNOTATE its output — they never recompute the rows by
# hand: scripts do arithmetic, tokens do judgment.
#
# Output: a markdown table plus one machine-parseable summary line:
#   funnel: open_issues=N loop_prs=N orphans=N
# Exit 0 on success (orphans are a finding, not an error); 2 when gh or
# the repo is unreachable.
set -uo pipefail
CONFIG="${1:?usage: funnel.sh <config>}"
# shellcheck source=/dev/null
source "$CONFIG" || { echo "cannot source $CONFIG" >&2; exit 2; }
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
COOLING="${COOLING_HOURS:-24}"

ISSUES="$(gh issue list -R "$GH_REPO" --state open --limit 200 \
  --json number,title,labels,body,createdAt 2>/dev/null)" \
  || { echo "funnel: cannot reach $GH_REPO via gh" >&2; exit 2; }
PRS="$(gh pr list -R "$GH_REPO" --state open --label loop-pr --limit 100 \
  --json number,title,labels,createdAt 2>/dev/null || echo '[]')"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -r --arg now "$NOW" --argjson cooling "$COOLING" --argjson prs "$PRS" '
  def names: [.labels[].name];
  def has($l): names | index($l) != null;
  def comps: names | map(select(startswith("component:")));
  def age_d: (($now | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 86400 | floor;
  def nudge: if age_d > 7 then " ⚠ \(age_d)d old" else "" end;
  def repro: (.body // "") | test("(?i)##? ?Repro|Repro:");
  def cool_end: (.createdAt | fromdateiso8601) + ($cooling * 3600);
  def cooled: cool_end <= ($now | fromdateiso8601);
  def cool_ts: cool_end | todate;
  def row:                                   # queue-state-machine.md order
    if has("🙋 needs-your-decision") then
      {o: 1, s: "🙋 decision", a: "owner replies Option X or acts", w: "daily reminder\(nudge)"}
    elif has("accepted") and has("action:interactive") then
      {o: 2, s: "accepted interactive", a: "owner pastes the stated ask into a session", w: "owner leisure\(nudge)"}
    elif has("action:operator") then
      {o: 3, s: "operator task", a: "owner runs the body commands", w: "owner leisure\(nudge)"}
    elif has("accepted") and has("action:loop") then
      {o: 4, s: "accepted fix", a: "fixer dispatcher", w: "tonight"}
    elif has("action:loop") and has("bug") and repro then
      (if cooled
       then {o: 5, s: "cooled fix", a: "fixer dispatcher", w: "tonight (cooled since \(cool_ts))"}
       else {o: 5, s: "cooling", a: "fixer dispatcher", w: "after \(cool_ts)"} end)
    elif has("action:loop") then
      {o: 6, s: "malformed filing (missing \(if has("bug") | not then "bug" elif repro | not then "Repro" else "component" end))",
       a: "orchestrator grooming", w: "tonight, then cooling"}
    else
      {o: 9, s: "ORPHAN 🟡", a: "orchestrator triage", w: "tonight — no state matches"}
    end;
  ([ .[] | row + {n: .number, t: .title[0:48]} ]) as $irows
  | ([ $prs[] | {o: 7, n: .number, t: .title[0:48], s: "loop PR",
                 a: "pr-verifier dispatcher",
                 w: (if age_d > 2 then "tonight ⚠ \(age_d)d old (stuck?)" else "tonight" end)} ]) as $prows
  | (["| item | state | next actor | next action |", "|---|---|---|---|"]
     + (($irows + $prows) | sort_by(.o, .n) | map("| #\(.n) \(.t) | \(.s) | \(.a) | \(.w) |")))[]
  , ""
  , "funnel: open_issues=\($irows | length) loop_prs=\($prows | length) orphans=\([ $irows[] | select(.o == 9) ] | length)"
' <<<"$ISSUES"
