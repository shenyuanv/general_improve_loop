# Design

A self-improvement harness is a relay of narrowly-scoped agents wrapped in
a mechanical shell, converging on a human-owned spec. This document is the
intent future audits diff against.

## The flow

```
                 ┌──────────── OWNER — anytime, phone or browser ───────────┐
                 │ GitHub: accept/reject labels · 🙋 decisions w/ options   │
                 │ file reports · watch loop PRs · read digests             │
                 │ ops/DIRECTION.md = knobs & focus · ops/PAUSE = stop      │
                 └───────▲──────────────────────────────┬───────────────────┘
                  pushes │                              │ pulls owner edits
                         │                              ▼
════ THE NIGHTLY RELAY — every loop inside the same bash shell ════════════
     (lock · PAUSE · breaker · timeout · preflight · no-go revert ·
      self-accept guard · queue lint · diff accounting · runs.jsonl)

 03:33 ORCHESTRATOR   gates → subagents: guardian(safety) ∥ operator
                      (deploy+telemetry+queue funnel) ∥ gardener(hygiene+
                      ratchet) → analyst(trends) → triage → issues → digest
 04:33 E2E-USER       fresh agent meets the product via its public entry   ─┐
                      point; judged vs rubric; defects filed w/ Repro       │FIND
 05:33 E2E-TESTER     (weekly) hermetic QA sweep: every command/endpoint    ─┘
                      × contract + error paths
 05:03 FIXER          dispatcher → ONE FRESH AGENT PER ISSUE (worktrees,   ─┐
                      ≤3 ∥): repro-first → minimal fix + fail-before/       │FIX
                      pass-after test → own branch → own PR                 ─┘
 06:03 PR-VERIFIER    dispatcher → ONE FRESH AGENT PER PR: bug real on     ─┐
                      base? PR kills it? gates? scope? CI green? →          │VERIFY
                      dispatcher merges (Fixes #n closes) or rejects        ─┘
        merged fixes deploy on the next cycle; the next journey re-tests
        them in the wild ─────────────────────────────── the loop closes
 ~07:00 OWNER reads one digest: Status → Needs-you → done in 15 seconds
 Sat 08:33 MANAGER  strategy at proposal level: convergence verdict vs the
                    DIRECTION bar, ≤2 🙋 amendment proposals, ≤1 design
                    brief — proposals only; the owner stays the authorizer
```

Prompts live one folder per role — `roles/{owner,manager,orchestrator,
developer,tester,reviewer}/` with a CHARTER.md each; loop names are the
stable identifiers. The developer also carries a knob-gated design lane
(`develop_pipeline`, accepted `action:develop` briefs with Design/Budget/
Verify, budget-capped, same adversarial verifier).

## Design laws (each learned from a real failure)

1. **Mechanical floors over prompt text.** Everything money- or
   safety-shaped lives in `bin/run-loop.sh`, before and after the agent —
   which cannot renegotiate bash mid-run. Prompt rules are the first line
   of defense; the floors are the last. (contracts/safety-floors.md)
2. **1 agent = 1 issue.** Dispatchers select/collect/report; fresh
   subagents do the work in isolated worktrees. A confused session can
   taint one unit of work, never a whole night.
3. **Verification is a separate agent whose default is REJECT.** It
   re-reproduces the bug on the base branch, proves the PR kills it, and
   is the no-go floor for merges (merges bypass the wrapper's revert).
4. **Reproduction gates the auto lane.** No `Repro:`, no pipeline. A fixer
   that can't reproduce returns "repro failed" — a good outcome. Unaccepted
   bugs cool 24 h so the owner always gets one digest+notification look
   before code changes.
5. **The queue cannot rot.** Every open issue maps to exactly one state
   with a named next actor (contracts/queue-state-machine.md), enforced
   twice: the wrapper lints filings the night they're born; the digest
   funnel table re-proves the whole queue every morning.
6. **Owner decisions are issues with pre-written options.** Blocked-on-you
   findings arrive as `🙋` issues: context, why-you, 2–4 options each with
   "choose this when…" and its enacting action. Open = remind daily;
   closed-with-reply = stand down until the stated premise observably
   breaks (then re-raise as a NEW issue referencing the old).
7. **Everything leaves a number.** runs.jsonl (cost, ±lines — the tamper
   check), ledgers, metrics with a LOC/deps/tests ratchet. Claims without
   numbers don't survive the next audit.
8. **The harness improves at human cadence.** docs/AUDIT-CHECKLIST.md is a
   fixed 10-item spec re-run ~monthly; concluding "delete a mechanism" is
   a success. The harness never edits its own rails (they're NOGO_PATHS).

## Trade-offs accepted

- **Single identity**: loops run as the owner; GitHub permissions add no
  mechanical safety. Compensation: attributed timelines (self-accept guard),
  evidence-heavy digests, and the wrapper floors. A second machine identity
  + branch protection is the upgrade path when a team adopts this.
- **Prompt-level behavioral rules** can be ignored by a bad model run; the
  floors guarantee blast-radius, not perfection. Everything critical is
  also verifiable after the fact (diff accounting, ledgers).
- **Cost scales with autonomy** (multi-agent nights cost several dollars);
  the cost-watch trend and per-loop breakers are the spend governors, plus
  whatever budget caps your runner CLI supports.
