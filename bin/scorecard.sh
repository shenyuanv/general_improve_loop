#!/usr/bin/env bash
# bin/scorecard.sh <config> [--days N]
#
# The loop-health scorecard: one mechanical JSON snapshot per ISO week
# (ops/metrics/scorecard-YYYY-Www.json) plus a skimmable markdown table on
# stdout. Everything is measured — runs.jsonl, the GitHub queue, the
# ledgers, the repo ratchet; nothing is estimated. Sections that need the
# network (gh) degrade to null with a note instead of failing: a scorecard
# you can't compute offline is a scorecard that stops being written.
set -uo pipefail

CONFIG="${1:?usage: scorecard.sh <config> [--days N]}"; shift
DAYS=14
while (( $# )); do
  case "$1" in
    --days) DAYS="${2:?}"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 64 ;;
  esac
done
# shellcheck source=/dev/null
source "$CONFIG" || { echo "cannot source $CONFIG" >&2; exit 1; }
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CUTOFF="$(date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "-${DAYS} days" +%Y-%m-%dT%H:%M:%SZ)"

# ── runs.jsonl: reliability, cost, floor violations ──────────────────────
RUNS_JSON="null"
if [[ -f "$STATE_DIR/runs.jsonl" ]]; then
  RUNS_JSON="$(jq -nR --arg cutoff "$CUTOFF" '
    [inputs | (fromjson? // empty) | select((.started // "") >= $cutoff)]
    # "paused" rows are intentional (ops/PAUSE drills / owner pauses), not
    # relay failures — they stay in window_runs/results but leave every
    # success-rate denominator (#22). scheduled_success_rate scores only
    # rows the scheduler launched (trigger:"scheduled"; older rows have no
    # trigger field and ad-hoc owner runs record "manual").
    | ([.[] | select(.result != "paused")]) as $graded
    | ([$graded[] | select(.trigger == "scheduled")]) as $sched
    | {
        window_runs: length,
        success_rate: (if ($graded | length) == 0 then null else
          (([$graded[] | select(.result == "success")] | length) / ($graded | length) * 100 | round) end),
        scheduled_success_rate: (if ($sched | length) == 0 then null else
          (([$sched[] | select(.result == "success")] | length) / ($sched | length) * 100 | round) end),
        results: (group_by(.result) | map({key: .[0].result, value: length}) | from_entries),
        cost_total_usd: ([.[] | .cost_usd // 0] | add // 0 | . * 100 | round / 100),
        nogo_reverts: ([.[] | .nogo_reverts // 0] | add // 0),
        timeouts: ([.[] | select(.timed_out == true)] | length),
        by_loop: (group_by(.loop) | map({
          key: .[0].loop,
          value: {
            runs: length,
            ok: ([.[] | select(.result == "success")] | length),
            cost_usd: ([.[] | .cost_usd // 0] | add // 0 | . * 100 | round / 100)
          }}) | from_entries)
      }' <"$STATE_DIR/runs.jsonl")"
fi

# ── GitHub queue funnel (graceful offline degradation) ───────────────────
FUNNEL_JSON="null"; FUNNEL_NOTE="gh unavailable or offline — funnel skipped"
if gh auth status >/dev/null 2>&1; then
  open_count() { gh issue list -R "$GH_REPO" --state open --label "$1" --json number --jq 'length' 2>/dev/null || echo null; }
  open_loop_filed="$(open_count loop-filed)"
  open_accepted="$(open_count accepted)"
  open_action_loop="$(open_count action:loop)"
  open_decisions="$(open_count "🙋 needs-your-decision")"
  open_bugs="$(open_count bug)"
  open_prs="$(gh pr list -R "$GH_REPO" --state open --label loop-pr --json number --jq 'length' 2>/dev/null || echo null)"
  merged="$(gh pr list -R "$GH_REPO" --state merged --label loop-pr --limit 100 \
      --json mergedAt,createdAt 2>/dev/null | jq --arg cutoff "$CUTOFF" '
      [.[] | select(.mergedAt >= $cutoff)]
      | {count: length,
         median_hours_to_merge: (if length == 0 then null else
           ([.[] | ((.mergedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)) / 3600]
            | sort | .[length/2 | floor] | . * 10 | round / 10) end)}' 2>/dev/null || echo null)"
  rejected_open="$(gh pr list -R "$GH_REPO" --state open --label loop-pr --json labels 2>/dev/null \
      | jq '[.[] | select([.labels[].name] | index("changes-requested"))] | length' 2>/dev/null || echo null)"
  FUNNEL_JSON="$(jq -n \
      --argjson lf "${open_loop_filed:-null}" --argjson acc "${open_accepted:-null}" \
      --argjson al "${open_action_loop:-null}" --argjson dec "${open_decisions:-null}" \
      --argjson bugs "${open_bugs:-null}" --argjson prs "${open_prs:-null}" \
      --argjson merged "${merged:-null}" --argjson rej "${rejected_open:-null}" \
      '{open: {loop_filed: $lf, accepted: $acc, action_loop: $al, decisions: $dec, bugs: $bugs, loop_prs: $prs},
        merged_window: $merged, prs_awaiting_rework: $rej}')"
  FUNNEL_NOTE=""
fi

# ── ledgers: journeys + tester ────────────────────────────────────────────
LEDGER_JSON="$(jq -nR --arg cutoff "$CUTOFF" '
  [inputs | (fromjson? // empty)] | map(select((.ts // "") >= $cutoff))
  | {journeys: {
      window_rows: length,
      verdicts: (group_by(.verdict) | map({key: (.[0].verdict // "unknown"), value: length}) | from_entries)
    }}' <"$PROJECT_DIR/ops/ledger/journeys.jsonl" 2>/dev/null || echo null)"
TESTER_JSON="$(tail -1 "$PROJECT_DIR/ops/ledger/tester.jsonl" 2>/dev/null | jq '
  {ts, items_total: (.matrix.items_total // null), items_pass: (.matrix.items_pass // null)}' 2>/dev/null || echo null)"

# ── repo ratchet: LOC, deps, tests collected ─────────────────────────────
loc_of() { # paths… (tracked files only; always prints a number)
  git -C "$PROJECT_DIR" ls-files -- "$@" 2>/dev/null \
    | (cd "$PROJECT_DIR" && xargs wc -l 2>/dev/null) | awk '{s=$1} END{print s+0}'
}
LOC_TESTS="$(loc_of 'tests/**' 'test/**' '*_test*')"; LOC_TESTS="${LOC_TESTS:-0}"
# ops/** is the loop's own nightly output (digests, metrics, ledgers) — it is
# excluded so the LOC ratchet measures product code, not loop artifacts (#16).
LOC_ALL="$(loc_of '.' ':!ops/**')"; LOC_ALL="${LOC_ALL:-0}"
LOC_PRODUCT=$(( LOC_ALL - LOC_TESTS ))
DEPS=0
[[ -f "$PROJECT_DIR/package.json" ]] && DEPS=$(( DEPS + $(jq '(.dependencies // {}) + (.devDependencies // {}) | length' "$PROJECT_DIR/package.json" 2>/dev/null || echo 0) ))
[[ -f "$PROJECT_DIR/requirements.txt" ]] && DEPS=$(( DEPS + $(grep -cvE '^\s*(#|$)' "$PROJECT_DIR/requirements.txt" 2>/dev/null || echo 0) ))
TESTS_COLLECTED=null
[[ -f "$PROJECT_DIR/tests/run.sh" ]] && TESTS_COLLECTED="$(bash "$PROJECT_DIR/tests/run.sh" --list 2>/dev/null | wc -l | tr -d '[:space:]')"

# ── markers ───────────────────────────────────────────────────────────────
flag() { [[ -e "$PROJECT_DIR/ops/$1" ]] && echo true || echo false; }

WEEK="$(date +%G-W%V)"
OUT_DIR="$PROJECT_DIR/ops/metrics"
OUT="$OUT_DIR/scorecard-$WEEK.json"
mkdir -p "$OUT_DIR"

jq -n \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg week "$WEEK" --argjson days "$DAYS" \
  --arg project "$PROJECT_NAME" --arg note "$FUNNEL_NOTE" \
  --argjson runs "$RUNS_JSON" --argjson funnel "$FUNNEL_JSON" \
  --argjson ledger "${LEDGER_JSON:-null}" --argjson tester "${TESTER_JSON:-null}" \
  --argjson loc_product "$LOC_PRODUCT" --argjson loc_tests "$LOC_TESTS" \
  --argjson deps "$DEPS" --argjson tests_collected "${TESTS_COLLECTED:-null}" \
  --argjson paused "$(flag PAUSE)" --argjson demoted "$(flag DEMOTED)" --argjson blocked "$(flag BLOCKED)" \
  '{ts: $ts, week: $week, window_days: $days, project: $project,
    runs: $runs, funnel: $funnel, funnel_note: (if $note == "" then null else $note end),
    ledger: $ledger, tester_latest: $tester,
    ratchet: {loc_product: $loc_product, loc_tests: $loc_tests, deps: $deps, tests_collected: $tests_collected},
    markers: {paused: $paused, demoted: $demoted, blocked: $blocked},
    notification_precision: null}' >"$OUT"

echo "wrote $OUT"
echo
echo "| metric | value |"
echo "|---|---|"
jq -r '
  def cell(v): if v == null then "–" else (v | tostring) end;
  "| runs (\(.window_days)d) | \(cell(.runs.window_runs)) |",
  "| run success % | \(cell(.runs.success_rate)) |",
  "| scheduled run success % | \(cell(.runs.scheduled_success_rate)) |",
  "| cost (window) | $\(cell(.runs.cost_total_usd)) |",
  "| nogo reverts | \(cell(.runs.nogo_reverts)) |",
  "| open: filed/accepted/decisions | \(cell(.funnel.open.loop_filed))/\(cell(.funnel.open.accepted))/\(cell(.funnel.open.decisions)) |",
  "| open loop PRs (awaiting rework) | \(cell(.funnel.open.loop_prs)) (\(cell(.funnel.prs_awaiting_rework))) |",
  "| merged loop PRs (window) | \(cell(.funnel.merged_window.count)) |",
  "| median hours to merge | \(cell(.funnel.merged_window.median_hours_to_merge)) |",
  "| LOC product/tests | \(cell(.ratchet.loc_product))/\(cell(.ratchet.loc_tests)) |",
  "| deps / tests collected | \(cell(.ratchet.deps)) / \(cell(.ratchet.tests_collected)) |",
  "| markers P/D/B | \(.markers.paused)/\(.markers.demoted)/\(.markers.blocked) |"
' "$OUT"
