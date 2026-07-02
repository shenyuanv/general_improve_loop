# Operations — the owner's day-2 manual

## The morning ritual (15 seconds when green)

1. **No `ops/reports/<today>.md` at all?** Something upstream of the wrapper
   broke (machine asleep, scheduler, agent CLI auth). Check
   `$STATE_DIR/logs/` — the newest log's last lines say where it died.
2. **Status line**: 🟢 skim and move on · 🟡/🔴 read **Needs you** — every
   item tells you why it's blocked, the exact action, and what happens after.
3. Decide queue items from any browser: `accepted`/`rejected` labels;
   `🙋` issues — act on an option or reply `Option X`.

## Controls

| Want | Do |
|---|---|
| Stop everything now | `touch ops/PAUSE` (delete to resume) |
| Pause just the fix pipeline | DIRECTION.md `fix_pipeline: off` |
| Pause journeys | DIRECTION.md `vm_cadence: off` |
| Deploys need my ack again | DIRECTION.md `deploy: ack` |
| Change schedule | edit `SCHEDULE` in loop.config.sh, re-run `bin/install-scheduler.sh` |
| Uninstall | `bin/install-scheduler.sh <config> --uninstall` |

## Recovery (each is one command)

| State | Meaning | Recovery |
|---|---|---|
| `$STATE_DIR/breaker-<loop>` exists | 3 consecutive failed runs | fix the cause, `rm` the flag |
| `ops/DEMOTED` exists | a loop action caused an incident (no-go revert or self-accept strip) — all loops propose-only | read it, `rm` when satisfied |
| `ops/BLOCKED` exists | a deploy was rolled back; that commit is pinned | investigate, `rm` to unpin |
| Notification "self-accept guard stripped …" | a label applied mid-run was removed (can't attribute actors) | if that was you, re-apply the label |
| Loop PR rejected twice | see the verifier's comments | fix the issue spec, or close the PR |
| Push guard skipping | you have unpushed commits | push your work; loops resume pushing |

## Watching the numbers

- `$STATE_DIR/runs.jsonl` — one row per run: result, cost, commits, ±lines,
  nogo_reverts. `jq` it for trends; the orchestrator's cost-watch alerts at
  >2× a loop's own median.
- `ops/metrics/*.json` — telemetry + the LOC/deps/tests ratchet.
- `ops/ledger/*.jsonl` — journeys, deploys, tester sweeps.
- Digest claims vs runs.jsonl diff accounting = your tamper check.

## Monthly

Re-run the audit (docs/AUDIT-CHECKLIST.md) and diff the scorecard + metrics
baseline against last month's. Delete mechanisms that can't justify
themselves — that's the system working, not failing.
