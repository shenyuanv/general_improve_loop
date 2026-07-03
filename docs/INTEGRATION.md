# Integration guide — adopt the loop in an afternoon

## Prerequisites

`git`, `jq`, `gh` authenticated against your repo, and an agent CLI that
accepts a prompt and works autonomously (default `claude`; set `RUNNER_BIN`
for others). macOS (launchd) or Linux (cron).

## Step 1 — scaffold

```bash
cd /path/to/general_improve_loop   # wherever you cloned this repo
./install.sh /path/to/your/project
```

Creates `ops/` (reports, ledgers, metrics), copies `ops/loop.config.sh` and
`ops/DIRECTION.md`, appends gitignore/gitattributes snippets. Nothing runs yet.

## Step 2 — fill in the adapter (`ops/loop.config.sh`)

The whole integration is this one file. Minimum viable:

| Setting | What to put there |
|---|---|
| `GH_REPO`, `PROJECT_DIR`, `PROJECT_NAME` | identity |
| `GATES` | your full test/lint commands — the same ones a careful human runs before merging |
| `NOGO_PATHS` | what the loops must never touch: secrets-adjacent code, installers, release scripts, the harness's own rails |

Optional stages activate by filling their variables:

- **Deploy**: `DEPLOY_CMD` / `DEPLOY_VERIFY_CMD` / `DEPLOY_ROLLBACK_CMD`
  (code-only!) / `DEPLOY_DRIFT_CMD`. Leave empty ⇒ the operator subagent
  reports drift as a Needs-you item at most.
- **E2E user journey**: `E2E_ENV_DESC` (where a fresh agent runs, how to
  reach it, the exact reset scope incl. any previously installed product
  binary), `E2E_JOURNEY_DESC` (the journey + success criteria),
  `E2E_RUBRIC_PATH` (a grading rubric in your repo). Leave empty ⇒ the
  e2e-user loop exits SKIPPED.
- **Telemetry**: `TELEMETRY_DESC` — where prod metrics/logs live and the
  read-only way in.

## Step 3 — direction + labels

Edit `ops/DIRECTION.md` (your Focus priorities and knobs — start with
`deploy: ack`, `push: local-only`) and create the queue labels:

```bash
bash templates/labels.sh your-org/your-repo cli server docs infra
```

## Step 4 — supervised first runs (do NOT schedule yet)

```bash
bash bin/run-loop.sh orchestrator /path/to/project/ops/loop.config.sh
```

Read the digest it writes (`ops/reports/<today>.md`). Then exercise the
floors on purpose — they must all bite before you trust the nights:

```bash
CFG=/path/to/project/ops/loop.config.sh
# no-go floor: commit a scratch edit to a NOGO path, then
bash bin/run-loop.sh --check-nogo <pre-sha> $CFG        # expect revert, exit 3
# self-accept guard: label any issue 'accepted', then
bash bin/run-loop.sh --check-self-accept <iso-2-min-ago> $CFG   # expect strip
# queue lint:
bash bin/run-loop.sh --check-queue-lint <iso-today> $CFG
# kill switch: touch ops/PAUSE && bash bin/run-loop.sh orchestrator $CFG  # exits paused
```

Run the fixer pipeline once with training wheels: file (or curate) one tiny
real bug with `Repro:`/`Verify:`, label it `accepted`, run
`bash bin/run-loop.sh fixer $CFG`, watch the PR, then
`bash bin/run-loop.sh pr-verifier $CFG` and watch the merge close the issue.

## Step 5 — schedule

```bash
bash bin/install-scheduler.sh $CFG        # launchd or cron per OS
```

Watch digests for ~5 mornings with conservative knobs. Flip `deploy: auto`
only after you've seen one verify-then-rollback work (stage a deliberate
bad deploy). Then raise autonomy at your own pace — every flip is one
DIRECTION.md edit, and `touch ops/PAUSE` is always one command away.

## What good looks like after week one

- Every morning: one digest, 15-second GREEN skim, funnel table with every
  open issue owned by someone.
- Bugs you accept (or ignore for 24 h after a digest mention) come back as
  merged PRs with fail-before/pass-after tests.
- The audit (docs/AUDIT-CHECKLIST.md) run at month one scores ≥8/10 present
  — or tells you exactly which mechanism to fix or delete.
