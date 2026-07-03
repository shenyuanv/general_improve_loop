#!/usr/bin/env bash
# loop.config.sh — the SELF-HOSTING adapter: this repo is its own target.
# Human-owned (NOGO_PATHS); loops read it via $ILOOP_CONFIG and may never
# edit it. The engine that EXECUTES is the promoted live checkout
# (ILOOP_ROOT below), never this working tree — see docs/SELF-HOSTING.md.

# ── Identity ─────────────────────────────────────────────────────────────
ILOOP_ROOT="$HOME/.improve-loop/general_improve_loop/live"  # the PROMOTED engine
PROJECT_DIR="$HOME/sourcecode/general_improve_loop"         # the repo under improvement
PROJECT_NAME="general_improve_loop"
GH_REPO="shenyuanv/general_improve_loop"
GH_AUTH_USER="shenyuanv"   # pin the loop's gh identity (decision #20): token
                           # resolved at run start; interactive `gh auth
                           # switch` can no longer flip a live run

# ── State (outside the repo) ─────────────────────────────────────────────
STATE_DIR="$HOME/.improve-loop/$PROJECT_NAME"

# ── Agent runner ─────────────────────────────────────────────────────────
RUNNER_BIN="claude"
RUNNER_FLAGS=(--dangerously-skip-permissions --output-format stream-json --verbose)
RUNNER_AUTH_PROBE='claude -p "Reply with exactly: OK"'

# ── Gates: must ALL pass before deploy/fix work ──────────────────────────
# (index 0 is also the suite fixers/verifiers rerun)
GATES=(
  "bash tests/run.sh"
  "bash tests/prompt-lint.sh"
  "shellcheck --severity=warning bin/*.sh install.sh templates/labels.sh selfhost/*.sh tests/*.sh"
)

# ── No-go paths: the rails (wrapper reverts; verifier hard-rejects) ──────
NOGO_PATHS=(
  ops/DIRECTION.md
  ops/loop.config.sh
  selfhost/
  .github/
  .gitattributes
  .gitignore
)

# ── Deploy stage: promote verified main into the live checkout ───────────
# DEPLOY_CMD runs the full post-promotion gate itself (tests + drill in the
# live tree); DEPLOY_VERIFY_CMD is the cheap health probe (preflight-safe).
DEPLOY_CMD="bash selfhost/promote.sh $PROJECT_DIR && bash selfhost/verify-live.sh"
DEPLOY_VERIFY_CMD="bash selfhost/verify-live.sh --quick"
DEPLOY_ROLLBACK_CMD="bash selfhost/rollback.sh"
DEPLOY_DRIFT_CMD="bash selfhost/drift.sh"

# ── E2E user journey: the adoption journey, from the LIVE checkout ───────
E2E_ENV_DESC="Scratch sandbox on this machine: SCRATCH=\$(mktemp -d). Work ONLY from the live checkout \$ILOOP_ROOT (you must meet the product fresh — never from $PROJECT_DIR, whose context you are not allowed to use). Generate the fixture target project: bash \$ILOOP_ROOT/selfhost/fixture.sh \$SCRATCH --engine \$ILOOP_ROOT (prints its config path; stub agent runner keeps cost ~0; fake HOME lives inside the scratch). Reset scope = that scratch dir ONLY; always rm -rf it at the end, even on failure. No network needed; gh is stubbed inside the fixture."
E2E_JOURNEY_DESC="The adoption journey — relive a developer adopting the loop, following docs/INTEGRATION.md (live checkout's copy) verbatim: (1) scaffold the fixture target; (2) supervised first run: bash \$ILOOP_ROOT/bin/run-loop.sh orchestrator <fixture-config> with the fixture's stub runner — expect exit 0, a result:success row in the fixture's runs.jsonl, preflight verdict run; (3) floor drills: plant a commit touching the fixture's ops/DIRECTION.md then --check-nogo <base> (expect exit 3 + revert), and touch ops/PAUSE then run the loop (expect a paused row); (4) note every command that needed modification vs the docs (docs lie = defect); (5) teardown. Success per the rubric."
E2E_RUBRIC_PATH="selfhost/e2e-rubric.md"

# ── Telemetry: this project's prod IS the loop ───────────────────────────
TELEMETRY_DESC="Read-only: \$ILOOP_STATE/runs.jsonl (per-run outcome/cost/diff rows — the tamper check), \$ILOOP_STATE/promotions.jsonl (deploy history), ops/metrics/scorecard-*.json (weekly loop-health snapshot; regenerate with: bash \$ILOOP_ROOT/bin/scorecard.sh \$ILOOP_CONFIG), gh api on $GH_REPO for queue/PR/CI state. Aggregates only."

# ── Notifications ────────────────────────────────────────────────────────
NOTIFY_METHOD="auto"
NOTIFY_WEBHOOK_URL=""

# ── Schedule ─────────────────────────────────────────────────────────────
# loop|Hour|Minute|Weekday(empty=daily; 0=Sun..6=Sat)|timeout_seconds
SCHEDULE=(
  "orchestrator|3|33||6000"
  "e2e-user|4|33||5400"
  "fixer|5|3||3600"
  "e2e-tester|5|33|0|5400"
  "pr-verifier|6|3||3600"
  "manager|8|33|6|5400"
)

# ── Limits ────────────────────────────────────────────────────────────────
MAX_FIXES_PER_NIGHT=3
MAX_VERIFIES_PER_NIGHT=3
COOLING_HOURS=24
DIGEST_RETENTION_DAYS=14

# ── Optional project preflight hook ──────────────────────────────────────
PROJECT_PREFLIGHT_HOOK=""
