# general_improve_loop

A self-improvement harness for any software project: a nightly relay of
headless AI agents that test your product like a user, sweep it like QA,
fix well-reproduced bugs as PRs, adversarially verify and merge them, and
report to you each morning — while a dumb mechanical shell guarantees they
can never exceed the authority you configured.

Extracted 2026-07-02 from a production deployment (the Zaster/zall-agent
harness), where in its first day it took CI from never-green to green,
shipped a verified auto-deploy, and found/fixed/merged four issues through
the full find→fix→verify pipeline.

## The relay (default schedule; every stage optional)

```
03:33 orchestrator   gates → per-focus subagents (safety, deploy+telemetry,
                     analysis, hygiene) → triage → issues → morning digest
04:33 e2e-user       a FRESH agent meets your product like a real user;
                     journey judged against your rubric; defects filed
05:03 fixer          dispatcher: ≤3 eligible bugs, ONE FRESH AGENT PER ISSUE
                     (isolated worktrees) → one PR each, repro-first
05:33 e2e-tester     (weekly) QA sweep: every command/endpoint × contract
06:03 pr-verifier    dispatcher: ONE FRESH AGENT PER PR — reproduce on main,
                     prove the PR kills it, suites, scope, CI → merge/reject
```

Humans steer through GitHub (one-tap issue labels, decision issues with
pre-written options, web-editable knobs file) and a morning digest whose
funnel table proves every open item has a named next actor.

## Design laws (learned the hard way; see docs/DESIGN.md)

1. **Mechanical floors over prompt text** — locks, breaker, timeout, no-go
   revert, self-accept guard, queue lint live in bash the agent can't
   renegotiate mid-run.
2. **1 agent = 1 issue** — every fix and every verification gets a fresh
   context; dispatchers select and report, they never do the work.
3. **Verification is a separate agent with zero loyalty** — default REJECT.
4. **Bugs only enter the auto lane reproduced** — `Repro:` or it waits for
   a human; unaccepted bugs cool 24 h before any agent may touch them.
5. **Every open issue is in exactly one state with a named next actor** —
   orphans are a defect the digest must surface (the no-rot invariant).
6. **The harness improves at human cadence** — a fixed 10-item audit
   checklist, re-run monthly; deletion of a mechanism is a success.

## Quickstart

```bash
git clone <this repo>
cd general_improve_loop
./install.sh /path/to/your/project     # scaffolds ops/, labels, config
$EDITOR /path/to/your/project/ops/loop.config.sh   # fill in your facts
./bin/install-scheduler.sh /path/to/your/project/ops/loop.config.sh
```

Requirements: `git`, `gh` (authenticated), `jq`, an agent CLI (default:
`claude`), macOS (launchd) or Linux (cron). Full walkthrough:
`docs/INTEGRATION.md`. Day-2 operations: `docs/OPERATIONS.md`. Developing
the engine itself additionally needs `shellcheck` (part of its gates).

## Self-hosting

The engine dogfoods itself: this repo is its own target project. Loops edit
it through the PR lane but execute from a separately promoted live checkout,
so a change only runs after fixer → adversarial verifier → CI → promote →
verify-live (with mechanical rollback). `bash tests/run.sh` is the floor
test suite; `bin/scorecard.sh` prints the loop-health numbers. Details:
`docs/SELF-HOSTING.md`.

## Layout

```
bin/         the mechanical shell (wrapper, preflight, notify, scheduler)
             + scorecard.sh (loop-health metrics for any adopter)
roles/       one folder per ROLE (owner, manager, orchestrator, developer,
             tester, reviewer): CHARTER.md = mission+authority, <loop>.md =
             that loop's exact prompt, subagents/ = per-issue/PR/focus prompts
contracts/   the shared rules every agent obeys (queue state machine,
             issue format, write policy, safety floors, digest format)
config/      loop.config.example.sh — every project-specific fact
templates/   files dropped into the target project (DIRECTION, labels, …)
tests/       hermetic floor tests (zero-dep runner) + prompt-lint —
             the engine's own GATES
selfhost/    promotion gate for self-hosting (promote / verify-live /
             rollback / drift · fixture generator · e2e rubric)
docs/        DESIGN (architecture), INTEGRATION, OPERATIONS,
             AUDIT-CHECKLIST, SELF-HOSTING
```
