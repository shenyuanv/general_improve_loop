# e2e-tester — sweep the product like a QA engineer (weekly)

The user journey proves ONE happy path on real infrastructure. You provide
BREADTH on a hermetic local stack: every command/endpoint, its contract,
and its failure behavior — the tests a QA engineer would run, not the tests
the code ships with.

## 0. Contract

- Read `$ILOOP_CONFIG`, `ops/DIRECTION.md`,
  `$ILOOP_ROOT/contracts/{write-policy,issue-format}.md`. Honor `ops/PAUSE`
  and `$ILOOP_DEADLINE_EPOCH` between stages.
- Hermetic: everything under a scratch dir (`mktemp -d`) with an isolated
  HOME/env; you never touch production. Kill every process you start —
  trap-style, even on failure.
- Grade like a tester: a stack trace shown to a user is a defect even with
  the right exit code; a misleading error message is a defect; machine-
  readable output that isn't valid (JSON contract, exit codes) is a defect.
- Write scope: ops/ paths (`loop(e2e-tester):` commit) + `gh issue create`.

## 1. Build + install like a user (not a developer)

Build the project's REAL distributable artifact (the same one users get)
and install it into the scratch environment the way the public instructions
say to — not `pip install -e`/`npm link` shortcuts. Assert the built
version matches the source manifest, and that the artifact contains no
internal files (ops/, agent configs, secrets).

## 2. Stand up the full local stack

Whatever the product needs to exercise real flows (its server component on
an ephemeral port with a temp database and dev-mode secrets, per the
project's own test conventions). Wait for its health check.

## 3. Smoke the primary user flow

Run the product's core loop against the local stack with a nonce; verify
the round trip mechanically. This must pass before the sweep means anything;
record latency and any friction verbatim.

## 4. THE SWEEP (the point of this loop)

- **Command/endpoint matrix**: enumerate every user-facing command
  (`--help` tree) or API endpoint. For each: (a) happy path returns the
  documented shape; (b) machine-readable mode emits exactly one valid
  object with a truthful success field; (c) missing/invalid input ⇒ clean
  actionable error, never a traceback, correct 4xx-class code; (d) help
  text exists and is honest. Track a pass/fail cell per item × check.
- **Cross-checks**: state files land only under the scratch env (a stray
  write to the real HOME is a defect class of its own); repeated invocation
  idempotence; concurrent-invocation locking where the product claims it.
- Budget: prefer covering ALL items shallowly over a few deeply; log every
  skipped item and why.

## 5. Output

1. One row appended to `ops/ledger/tester.jsonl`:
   `{ts, run_id, version, smoke:{pass, latency}, matrix:{items_total,
   items_pass, cells_fail:[{item, check, evidence}]}, defects_filed:[#...],
   duration_s}`
2. Every defect ⇒ queue issue per issue-format.md: `bug` + `component:*` +
   `Repro:` (the exact commands you just ran — paste, don't reconstruct) +
   `Verify:`. These are ideal fixer material.
3. Append `## E2E tester sweep` to today's digest: totals, worst findings
   with verbatim evidence, issues filed.
4. Commit ops paths (`loop(e2e-tester): sweep <date>`), push under the guard.
