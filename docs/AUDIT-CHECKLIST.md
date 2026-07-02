# The harness audit — a fixed 10-item checklist

This checklist is the complete spec of the audit — do not add criteria to
it. Run it ~monthly (or after any autonomy change) in a fresh agent session:
Phase 1 is read-only scoring; Phase 2 proposes ≤5 changes; the human
approves before anything lands. An audit that concludes "delete a
mechanism" is a success. Keep every audit's output in
`ops/HARNESS_AUDIT.md` (append; diff against the previous run).

For each item record: status (present / partial / missing), evidence
(file:line), the concrete failure it prevents, and the smallest possible fix.

1. **Spec anchoring** — is there a human-owned spec the loop converges
   toward (DIRECTION Focus + accepted issues)? Can the agent add to it?
   (It must not be able to.)
2. **Scope gate** — does the executor only pick up labeled/authorized
   tasks? Are feature-type tasks gated behind explicit human approval,
   while bug/flake/refactor/perf/docs tasks are auto-eligible (with
   cooling)?
3. **Verify contract** — does every auto-fixable task carry a
   machine-checkable `Verify:`? Are tasks without one rejected?
4. **Separate evaluator** — is verification done in a fresh context that
   (a) re-reads acceptance criteria, (b) checks the diff for out-of-scope
   changes, (c) checks for weakened/deleted tests?
5. **Termination logic** — per-run timeout, breaker with a documented
   reset, escalation to needs-human?
6. **Parsimony enforcement** — per-PR diff cap; measured ratchet on net
   LOC, dependency count, test count (fail on regression)?
7. **Entropy control** — scheduled retention/rollup for the harness's own
   outputs (digests, ledgers, logs, run history)?
8. **Memory hygiene** — are queues/ledgers append-or-groom (never
   rewrite)? Size caps? Pruning cadence?
9. **Permission floor** — is safety enforced by mechanisms the agent
   cannot edit mid-run (wrapper floors; branch protection where
   available), rather than by prompt text alone? Are the floors' test
   modes (`--check-nogo`, `--check-self-accept`, `--check-queue-lint`)
   still passing when exercised?
10. **Observability** — per-run one-line record (outcome, cost, diff
    size), persisted transcripts, and digest claims that reconcile with
    the mechanical accounting?

## Metrics baseline (capture CURRENT values — never guess)

net LOC (product / tests) · dependency count · test count · open
loop-labeled issues by state · last N runs' outcomes and costs ·
merge/reject counts in the PR lane · notification precision (alerts that
were real / total). "Not yet measurable" is a valid entry; a number you
made up is not.

## Phase 2 rules

Propose AT MOST 5 changes, ranked by (failure severity prevented) ×
(implementation smallness). For each: the checklist # it closes, exact
files, estimated diff size, the metric that will show it worked, and the
verify command for the change itself. More gaps than 5 ⇒ list the rest as
deferred. STOP and present before implementing.
