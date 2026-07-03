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
| Notification "self-accept guard: stripped …" | a mid-run `accepted` label was removed — the run's own transcript showed the loop adding it | check the run log; if the strip was wrong, re-apply the label |
| Notification "FYI: #N gained 'accepted' …" | a mid-run `accepted` label was KEPT — no loop evidence in the transcript, assumed owner | remove the label if that wasn't you; otherwise nothing |
| Loop PR rejected twice | see the verifier's comments | fix the issue spec, or close the PR |
| Push guard skipping | you have unpushed commits | push your work; loops resume pushing |

## Watching the numbers

- `$STATE_DIR/runs.jsonl` — one row per run: result, cost, commits, ±lines,
  nogo_reverts. `jq` it for trends; the orchestrator's cost-watch alerts at
  >2× a loop's own median.
- `ops/metrics/*.json` — telemetry + the LOC/deps/tests ratchet.
- `ops/ledger/*.jsonl` — journeys, deploys, tester sweeps.
- Digest claims vs runs.jsonl diff accounting = your tamper check.

## Runner quota (429s are weather, not breakage)

Subscription runners share your own usage windows (5-hour and 7-day). A run
killed by quota is recorded honestly and nothing advances — the nightly
cadence self-heals by simply running tomorrow. Do NOT rm breakers or retry
in a tight loop. To resume sooner: probe cheaply
(`claude -p "Reply with exactly: OK"`), and rerun the missed loop only
after the probe answers OK. The reset timestamps are in the run's log
(`rate_limit_info.resetsAt`).

## Sprint mode (supervised convergence runs)

Running the relay back-to-back (as in bootstrap) is the exception, not the
design. If you do: batch-`accepted` the issues you want fixed (acceptance
bypasses cooling — that authorization is the point of the label), expect to
hit quota windows and wait them out per the section above, promote + run
`selfhost/verify-live.sh` between cycles, and revert any knob you raised
(caps, cadence) when the sprint ends. Every manual step you perform during
a sprint must exit as a floor, a lint, or a documented duty (see DIRECTION
standing orders).

## CI as a floor and a finder

**CI health ownership (no dedicated CI role — by design):** the *guardian*
watches every workflow conclusion nightly (red with no matching
`component:ci` issue = the filer itself broke, TOP finding); failures in
repo code (gates/floor drill/install smoke) self-file as `action:loop` and
the *developer* fixes them like any bug; failures in workflow/runner
plumbing self-file as `action:operator` because `.github/` is the *owner's*
rails — no loop may touch merge-gate or watchdog definitions (a loop that
can edit its own CI can green-wash itself). The *tester* deliberately does
NOT own CI: its charter is finding product defects, and the drill
workflows are its instruments, not its service to operate.

Branch protection requires the `test` check on main: loop merges without
`--admin` are SERVER-refused while CI is red or pending (the verifier is
forbidden `--admin` by write-policy; you, the owner, may
`gh pr merge --admin` as the documented escape hatch when CI itself is the
thing that's broken). Two scheduled workflows drill a clean machine —
`nightly-drills` (ubuntu, daily 02:17) and `weekly-macos` (Sun, system
bash 3.2 parity) — and FILE a well-formed `component:ci` issue on failure
(deduped by title marker). Silence from them means a clean machine agrees
with yours.

## The loop's GitHub identity

Pin it: `GH_AUTH_USER` in loop.config.sh makes every run resolve that
user's token up front, so an interactive `gh auth switch` on the same
machine can never flip a live run (the cycle-2 incident). Drill after
changing it: switch your shell to another account, run
`bin/run-loop.sh --check-queue-lint <iso> <config>` — it must still see
the queue — then switch back.

## Monthly

Re-run the audit (docs/AUDIT-CHECKLIST.md) and diff the scorecard + metrics
baseline against last month's. Delete mechanisms that can't justify
themselves — that's the system working, not failing.
