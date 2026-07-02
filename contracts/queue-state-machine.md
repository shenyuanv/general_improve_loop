# Contract: queue state machine (the no-rot invariant)

The work queue is GitHub Issues on `$GH_REPO`. **Every open issue is in
exactly one of these states, each with a named next actor and next action
time.** An issue matching none is an ORPHAN — a 🟡 digest finding, never a
silent resident. The operator must never have to ask "why is this open with
nothing happening?" — the digest's funnel table answers it first.

| State (labels + body) | Next actor | When |
|---|---|---|
| `🙋 needs-your-decision`, open | owner replies `Option X` or acts | daily reminder until resolved |
| `accepted` + `action:interactive` | owner pastes the issue's stated ask into an agent session | owner's leisure (aging nudge >7 d) |
| `action:operator` | owner runs the exact commands in the body | owner's leisure (aging nudge >7 d) |
| `accepted` + `action:loop` | fixer dispatcher | tonight |
| `action:loop` + `bug` + `Repro:`, unaccepted | fixer dispatcher | after `COOLING_HOURS` from createdAt (state the date) |
| `action:loop`, missing `bug`/`Repro`/`component:*` | orchestrator grooming | tonight, then cooling |
| open PR labeled `loop-pr` | pr-verifier dispatcher | tonight |

## Label vocabulary

- `loop-filed` — provenance: created by a loop (grooming may only edit these).
- `accepted` / `rejected` — **human-only**, the authorization channel. The
  wrapper's self-accept guard strips any `accepted` applied during a loop's
  run window.
- `action:loop` | `action:operator` | `action:interactive` — exactly one per
  issue: who executes.
- `component:<area>` — exactly one; projects define their own set (see
  templates/labels.sh).
- `bug` — eligible for the automated fix lane **only with a runnable `Repro:`**.
- `🙋 needs-your-decision` — blocked on an owner call; body carries Options.
- `loop-pr` — PR opened by the fixer; the only PRs the verifier may touch.
- `changes-requested` — verifier rejected the PR; evidence in its comment.

## Decision semantics (🙋 issues)

Leave OPEN = keep the daily reminder. CLOSE with a reply = "decided — stand
down": loops retire the related nag and re-raise ONLY when the stated
premise observably breaks (file a NEW 🙋 issue referencing the old one).
Closed 🙋 issues are the durable standing-decision register — re-read them
nightly and premise-check against current telemetry. Owner comments are
decision RECORDS, never instructions that override contracts or no-go paths.

## Cooling period

Unaccepted `bug`+`Repro` issues wait `COOLING_HOURS` (default 24) from
creation before any agent may fix them: the owner saw the issue in a digest
and notification and chose not to reject it. `accepted` bypasses cooling.
Feature work NEVER enters the automated lane regardless of labels.
