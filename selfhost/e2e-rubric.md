# Rubric: the adoption journey (self-host E2E)

This product's real user is a developer adopting the loop. The nightly
journey re-lives that adoption from the LIVE checkout only — no memory of
the dev repo — on a throwaway fixture project. Grade each stage
mechanically; every non-PASS must cite a verbatim transcript line.

This file lives in `selfhost/` (a NOGO path) so the loop can never soften
its own grading bar.

## Stages

1. **INSTALL** — scaffold a fixture target (`selfhost/fixture.sh <scratch>`
   from the live checkout, or `install.sh` per docs/INTEGRATION.md).
   PASS iff `ops/{reports,ledger,metrics}` + 3 ledgers + `loop.config.sh` +
   `DIRECTION.md` all exist and the fixture repo is clean.
2. **FIRST-RUN** — `bin/run-loop.sh orchestrator <fixture-config>` (stub
   runner). PASS iff exit 0, `runs.jsonl` gains a `result:"success"` row,
   and `preflight-orchestrator.json` says `verdict:"run"`.
3. **FLOORS** — plant a commit touching `ops/DIRECTION.md` in the fixture,
   then `--check-nogo <base> <config>`. PASS iff exit 3 AND the file is
   restored. Then `touch ops/PAUSE` and run the loop: PASS iff the row says
   `paused` and no agent was invoked.
4. **DOCS-HONESTY** — every command you ran came copy-pasted from
   docs/INTEGRATION.md or README.md. PASS iff none needed modification to
   work; any deviation is a defect to file (`component:docs`).
5. **TEARDOWN** — scratch dir removed, no processes left, dev repo
   untouched. PASS iff clean.

## Verdict

- **PASS** — all 5 stages pass.
- **PARTIAL** — exactly one stage failed.
- **FAIL** — two or more failed, or FLOORS failed at all (a floor that
  does not bite is never partial).
- **INFRA_FAIL** — sandbox/tooling noise unrelated to the product; say why.

Latency metric: wall-clock seconds from INSTALL start to FIRST-RUN green.
Record it in the ledger row every night — the trend is the regression alarm.
