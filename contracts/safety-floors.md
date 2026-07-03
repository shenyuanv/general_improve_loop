# Contract: safety floors (what the wrapper enforces — agents can't opt out)

Two layers. The MECHANICAL layer lives in `bin/run-loop.sh` (bash the agent
cannot renegotiate mid-run); the BEHAVIORAL layer lives in the agent prompts
and this contracts/ directory. Prompt rules are the first line of defense;
the floors are the last.

## Mechanical (per run, every loop)

| Floor | Failure it prevents |
|---|---|
| Singleton lock (mkdir, stale-pid reclaim) | overlapping runs of the same loop |
| `ops/PAUSE` kill switch | anything, instantly (`touch ops/PAUSE`; delete to resume) |
| 3-strikes breaker → flag file `$STATE_DIR/breaker-<loop>` | burning tokens nightly on a broken environment; re-arm: fix cause, `rm` the flag |
| Corrupt-tolerant history parse (`fromjson?`) | one bad runs.jsonl line silently disabling the breaker |
| Hard timeout (`LOOP_TIMEOUT_S`) + keep-awake | wedged runs; sleep mid-run |
| Preflight (abort only: git broken / disk <5 GB / agent auth dead / gh cannot reach `GH_REPO` — an account flip makes every gh floor fail open on silently-empty lists; pin `GH_AUTH_USER` to prevent it) | burning tokens when no run can produce value |
| **No-go revert floor** — post-run, any commit touching `NOGO_PATHS` is `git revert`ed (never reset — concurrent human commits survive), DEMOTED created | the agent editing its own rails, secrets-adjacent code, or anything you fenced off |
| **Self-accept guard** — an `accepted` label applied during the run window (issue-events timeline) is stripped ONLY when this run's transcript shows the loop adding it (`--add-label`/labels-API evidence); strip ⇒ DEMOTED created. No evidence ⇒ assumed owner: label KEPT + FYI notification ("remove it if that wasn't you"). The evidence grep is a heuristic — an obfuscated add evades it; that residual is covered by contracts/write-policy.md and the verifier lane. The manual drill (`--check-self-accept`) strips unconditionally: no transcript | loops authorizing their own work — without demoting an owner who labels issues while a run is in flight (single-identity setups can't attribute actors) |
| **Queue lint** — loop-filed issues created in-window missing `action:*`/`component:*`/(bug⇒Repro) are flagged the night they're born | issues rotting in states no executor will ever pick up |
| Stale loop-branch prune — post-run, a local `loop/fix-GH<n>` branch whose newest PR is MERGED/CLOSED is deleted (loop-prefixed refs only; open/unknown PR state ⇒ kept, never human branches) | a merged/closed loop PR's leftover branch making the fixer skip issue #n forever ("branch exists" = ineligible) |
| Diff accounting (commits/±lines per run into runs.jsonl) | invisible scope creep; digest claims that don't match reality |
| Digest guarantee (stub on crash) + per-run NOTIFY fan-out (only lines this run appended; max 3) | silent failures; duplicate/starved notifications across same-day runs |
| Retention caps (logs 14 d, runs.jsonl 500 rows) | unbounded state degrading future runs |

## Behavioral (prompt-enforced, audited by the floors' evidence)

Run modes from preflight flags — dirty tree ⇒ OBSERVE (no deploys/no code);
prod verify failing ⇒ INCIDENT (diagnose first, deploy nothing); DEMOTED
present ⇒ propose-only until the human clears it. Deploy: one attempt per
target per night, verify then rollback CODE FILES ONLY (never data),
BLOCKED marker pins a rolled-back commit until human clears. Boundary
checks between stages: PAUSE appeared ⇒ finish digest and stop;
`$ILOOP_DEADLINE_EPOCH − 900` passed ⇒ jump to digest.

## Escalation ladder

failure → digest note → notification (whitelist) → breaker (3 strikes) →
DEMOTED (loop-caused incident; propose-only until human deletes it) →
PAUSE (human, everything stops). Recovery paths for each are one `rm` and
documented in docs/OPERATIONS.md.
