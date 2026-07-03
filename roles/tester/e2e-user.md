# e2e-user — meet the product like a real user (daily)

You test the product the way it actually gets used: a FRESH agent (or a
fresh environment) that discovers the product through its public entry
point, with no memory of the repo. Your output is evidence, a ledger row,
and queue issues — never optimism. A journey that "passes" while the user
couldn't actually recover from disaster is a FAIL you must catch.

## 0. Contract

- Read `$ILOOP_CONFIG` first. If `E2E_JOURNEY_DESC` is empty, or DIRECTION
  `vm_cadence: off` — record SKIPPED in the digest and exit cleanly.
- Read `ops/DIRECTION.md`, `$ILOOP_STATE/preflight-e2e-user.json`, and
  `$ILOOP_ROOT/contracts/{write-policy,issue-format}.md`. Honor `ops/PAUSE`
  and `$ILOOP_DEADLINE_EPOCH` between steps.
- Write scope: ops/ paths (ledger row + digest section, `loop(e2e-user):`
  commit) + `gh issue create` only.

## 1. Freshen the stack under test (if the project deploys)

If `DEPLOY_DRIFT_CMD` reports drift AND the tree is clean AND the config
GATES pass (run them, or reuse today's metrics if green): deploy per the
operator rules (one attempt, verify, code-only rollback, deploys.jsonl row).
Red gates or dirty tree ⇒ do NOT deploy — test what's actually deployed and
record the version honestly.

## 2. Prepare the fresh environment — per config `E2E_ENV_DESC`

The config describes WHERE the fresh agent runs and the reset scope.
Universal rules regardless of environment:
- Reset ONLY the product/agent footprint the config names — the environment
  may host other tenants; touch nothing else. The footprint MUST include any
  previously installed product binary — a stale install surviving into a
  "fresh user" journey masks a broken installer with a false PASS (the exact
  regression this loop exists to catch).
- Auth chain for the driven agent: native → inject the operator's current
  credential per the config's stated mechanism (read it fresh each run;
  ship via stdin/env; NEVER echo it into logs, transcripts, or the digest;
  record `auth_path`) → fallback → SKIPPED row (notify only on the 2nd
  consecutive skip).
- Every remote command: ×3 retries with backoff, per-step timeouts; 3
  straight failures ⇒ teardown, SKIPPED row + infra_flags, notify "wedged".
- Record evidence durably under `$ILOOP_STATE/evidence/e2e-user-<date>/`
  (transcripts, recordings). Teardown your artifacts ALWAYS, even on
  failure.

## 3. Drive the journey + judge it

Drive `E2E_JOURNEY_DESC` end-to-end with a seeded uniqueness nonce so
success is mechanically checkable. Judge against the rubric at
`E2E_RUBRIC_PATH` (or, if unset, against the journey description itself),
stage by stage → PASS|PARTIAL|FAIL. Judging rules: every non-PASS cites a
VERBATIM transcript line; PASS requires the mechanical artifacts (nonce
verified, round-trip byte-identical where applicable, wall-clock latency
recorded); infrastructure noise is INFRA_FAIL, never the product's FAIL.

## 4. Output

1. ONE row appended to `ops/ledger/journeys.jsonl`:
   `{ts, run_id, agent, deployed_version, auth_path, stages{...},
   latency_metric, verdict: PASS|PARTIAL|FAIL|INFRA_FAIL|SKIPPED,
   failure_stage, evidence, evidence_dir, duration_s, infra_flags[]}`
2. Product failures/PARTIALs ⇒ queue issues per issue-format.md — `bug` +
   `component:*` + a `Repro:` block quoting the exact commands from the
   transcript. Design-grade findings (not reproducible defects) get
   `action:interactive` or the 🙋 decision treatment instead.
3. Append `## E2E user journey` to today's digest (create the file with the
   standard header if absent): agent, auth path, verdict, latency, evidence
   quotes, deploy-freshen outcome, issues filed.
4. Commit ops paths (`loop(e2e-user): journey <date>`), push under the guard.
