# Direction

**Human-owned.** Every loop reads this file before acting and must never
edit it (the wrapper's no-go floor reverts any loop commit that touches
it). Change knobs here to steer; changes take effect next run. Edit it from
any browser — the loops pull before acting.

## Focus

Priorities, in order. This is the convergence bar — each is falsifiable,
and the analyst measures the trend nightly:

1. **The floors must bite, always.** Rolling 14 days: 0 no-go reverts,
   0 self-accept strips, 0 breaker trips, `--check-*` drills exit 3/0
   correctly (verify-live proves it after every promotion).
2. **The relay runs reliably.** ≥95 % of loop runs end `success`
   (runs.jsonl); every morning has a digest whose claims reconcile with
   the wrapper's diff accounting; 0 orphan issues in the funnel table.
3. **The pipeline converges.** Pinned bugs in `tests/known-failures.txt`
   trend to 0 while `collected=` (test count) trends UP — finding fewer
   defects with more tests is convergence, with fewer tests is blindness.
   Every merged fix flips its known-failures line (fail-before/pass-after).
4. **Cost stays flat.** Per-loop cost ≤2× its own 7-run median
   (runs.jsonl); a cheaper night that achieves the same bar is a finding
   worth proposing.
5. Repo/doc hygiene: docs never lie about commands (the nightly adoption
   journey punishes drift); LOC/deps ratchet holds (deps stay 0).

## Knobs

```yaml
deploy: ack                 # ack | auto — promotion to the live checkout
                            #   needs my approval until I've watched one
                            #   staged bad deploy get caught + rolled back
push: push                  # dedicated repo; loops push loop-prefixed work
fix_pipeline: on            # reproduced bugs flow issue → PR → verify+merge
vm_cadence: daily           # the adoption journey runs nightly (stub agent, ~free)
notify_on: [failure, deploy, rollback, incident, pending-ack, new-user, decision-needed]
```

## No-go paths (loops may NEVER modify these — mirrored in
## ops/loop.config.sh NOGO_PATHS, which is what the wrapper enforces)

- ops/DIRECTION.md, ops/loop.config.sh — the steering
- selfhost/ — the promotion gate and the journey rubric (the loop must
  not soften its own verifier or grading bar)
- .github/ — CI is part of the merge gate
- .gitattributes, .gitignore

## Standing orders (freeform — the loops read these verbatim)

- Prefer reverting a loop change over fixing it forward.
- When in doubt, do less and write it up.
- The engine you execute is the LIVE checkout; the repo you improve is
  this one. Never run loops from the working tree you are editing.
- A fix PR for a pinned bug MUST flip its known-failures entry in the same
  PR (today the line in tests/known-failures.txt; the marker file under
  tests/known-failures.d/ once that lands) — the suite fails on XPASS
  otherwise, and the verifier treats a leftover pin as an incomplete fix.
- Feature work never enters the automated lane; file it
  `action:interactive` and wait for me.
- Any manual owner intervention a cycle needed MUST exit the run as one of:
  a mechanical floor, a lint/test, or a documented operator duty — never
  tribal knowledge. If you observe me intervening by hand, file the issue
  that mechanizes it.
