#!/usr/bin/env bash
# loop.config.sh — EVERY project-specific fact lives here and only here.
# The engine (bin/) and the agent prompts (agents/) are generic; this file
# is the adapter. Copy to <your-project>/ops/loop.config.sh and edit.
# Sourced by bin/run-loop.sh; also read by agents at run time (they get its
# path in $ILOOP_CONFIG).

# ── Identity ─────────────────────────────────────────────────────────────
ILOOP_ROOT="$HOME/sourcecode/general_improve_loop"  # this engine's checkout
PROJECT_DIR="$HOME/sourcecode/YOUR_PROJECT"         # the repo under improvement
PROJECT_NAME="your-project"                         # short slug (state dir, labels)
GH_REPO="your-org/your-repo"                        # gh issue/pr target
GIT_REMOTE="origin"                                 # remote the loops push to

# ── State (outside the repo) ─────────────────────────────────────────────
STATE_DIR="$HOME/.improve-loop/$PROJECT_NAME"       # logs, locks, runs.jsonl, breaker flags

# ── Agent runner ─────────────────────────────────────────────────────────
RUNNER_BIN="claude"                                  # any CLI: prompt in, work done
RUNNER_FLAGS=(--dangerously-skip-permissions --output-format stream-json --verbose)
RUNNER_AUTH_PROBE='claude -p "Reply with exactly: OK"'  # cheap aliveness check

# ── Gates: commands that must ALL pass before deploy/fix work ────────────
# (index 0 is also the suite fixers/verifiers rerun; keep it the full one)
GATES=(
  "python -m pytest -q"
  # "npm test", "go test ./...", "make check" …
)

# ── No-go paths: the loops may NEVER modify these (wrapper reverts) ──────
NOGO_PATHS=(
  ops/DIRECTION.md
  ops/loop.config.sh
  .gitattributes
  .gitignore
  # + your crypto/auth/billing/installer paths
)

# ── Optional stage: deploy (empty DEPLOY_CMD disables the stage) ─────────
DEPLOY_CMD=""                    # e.g. "./deploy.sh prod-host"; runs from PROJECT_DIR
DEPLOY_VERIFY_CMD=""             # must exit 0 iff the deploy is healthy
DEPLOY_ROLLBACK_CMD=""           # restore CODE only — never data files
DEPLOY_DRIFT_CMD=""              # exit 0 = current, 1 = drifted (e.g. compare live version vs HEAD)

# ── Optional stage: E2E user journey (empty disables loop-e2e-user) ─────
E2E_ENV_DESC=""                  # where the fresh agent runs, how to reach it, reset scope
E2E_JOURNEY_DESC=""              # the user journey to drive + what "success" means
E2E_RUBRIC_PATH=""               # repo-relative grading rubric the judge scores against

# ── Optional: telemetry the operator subagent should harvest ────────────
TELEMETRY_DESC=""                # freeform: where prod metrics/logs live + read-only access

# ── Notifications ────────────────────────────────────────────────────────
NOTIFY_METHOD="auto"             # auto | osascript | notify-send | webhook | none
NOTIFY_WEBHOOK_URL=""            # used when NOTIFY_METHOD=webhook (POST {"text": …})

# ── Schedule (install-scheduler.sh reads this) ───────────────────────────
# loop|Hour|Minute|Weekday(empty=daily; 0=Sun..6=Sat)|timeout_seconds
# Delete lines to disable loops; e2e loops auto-skip when unconfigured.
SCHEDULE=(
  "orchestrator|3|33||6000"
  "e2e-user|4|33||5400"
  "fixer|5|3||3600"
  "e2e-tester|5|33|0|5400"
  "pr-verifier|6|3||3600"
)

# ── Limits ────────────────────────────────────────────────────────────────
MAX_FIXES_PER_NIGHT=3            # fixer dispatch width (1 agent per issue)
MAX_VERIFIES_PER_NIGHT=3         # verifier dispatch width (1 agent per PR)
COOLING_HOURS=24                 # unaccepted bugs wait this long before auto-fix
DIGEST_RETENTION_DAYS=14         # dailies roll up into weekly files after this

# ── Optional project preflight hook ──────────────────────────────────────
PROJECT_PREFLIGHT_HOOK=""        # script emitting extra JSON checks; "" = none
