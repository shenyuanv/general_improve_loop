# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A project-agnostic self-improvement harness: a nightly relay of headless AI agents (orchestrator → e2e-user → fixer → e2e-tester → pr-verifier) that finds, fixes, verifies, and merges issues in a **target** project, wrapped in a mechanical bash shell enforcing safety floors the agents cannot renegotiate. This repo is the reusable engine — it is installed against other projects — and it is **self-hosted**: the repo is its own target project (see `docs/SELF-HOSTING.md`). The codebase is bash + markdown, and the markdown is mostly executable (see below); no build system or package manifest.

## Commands

- **Test suite (the GATES)**: `bash tests/run.sh` — hermetic floor tests, zero dependencies. Filter by substring: `bash tests/run.sh t07 breaker`; list: `--list`; verbose: `-v`. A single test also runs directly: `bash tests/t/t01-nogo-revert-single.sh`.
- **Known-failures contract**: a marker file `tests/known-failures.d/<test-name>` pins an OPEN bug — pinned tests report `xfail`; if one passes it's `XPASS` and the suite FAILS. A PR fixing a pinned bug must also `git rm` its marker (mechanical fail-before/pass-after; one file per pin keeps concurrent flips conflict-free).
- Cross-reference lint: `bash tests/prompt-lint.sh` (markdown is load-bearing; this catches broken contract/subagent/config-var/label references)
- Shell lint: `shellcheck --severity=warning bin/*.sh install.sh templates/labels.sh selfhost/*.sh tests/*.sh`
- Run one loop supervised: `bash bin/run-loop.sh <loop> <config>` where `<loop>` ∈ orchestrator | e2e-user | fixer | e2e-tester | pr-verifier
- Drill the floors against a real config (docs/INTEGRATION.md step 4): `bash bin/run-loop.sh --check-nogo <base-sha> <config>` / `--check-self-accept <since-iso>` / `--check-queue-lint <since-iso>` — exit 3 on (handled) violations, 0 clean
- Scaffold a target: `./install.sh /path/to/project` (idempotent, never overwrites config/DIRECTION); a sandboxed fixture target: `bash selfhost/fixture.sh <dest> [--bare-remote]`
- Scorecard: `bash bin/scorecard.sh <config>` → `ops/metrics/scorecard-YYYY-Www.json` + markdown table
- Self-host promotion: `bash selfhost/{drift,promote,verify-live,rollback}.sh` (runbook in docs/SELF-HOSTING.md)
- Schedule/unschedule: `bash bin/install-scheduler.sh <config> [--uninstall]` (launchd on macOS, crontab on Linux)
- Create queue labels: `bash templates/labels.sh <owner/repo> [components...]`

## Architecture

**Engine/adapter split — the core invariant.** Everything in this repo is generic. Every project-specific fact lives in the target project's `ops/loop.config.sh`. Never hardcode a project fact into `bin/`, `agents/`, or `contracts/`; add a variable to `config/loop.config.example.sh` instead.

**Markdown is load-bearing.** `agents/<loop>/AGENT.md` is piped verbatim as the agent's prompt (`run-loop.sh`: `$RUNNER_BIN -p "$(cat AGENT.md)"`). Dispatcher prompts paste `agents/*/subagents/*.md` into fresh subagents, and all prompts tell agents to read `contracts/*.md` at runtime via `$ILOOP_ROOT`. So renaming/moving these files, or renaming a config variable (`GATES`, `NOGO_PATHS`, `COOLING_HOURS`, `DEPLOY_*`, `E2E_*`, …), breaks prompts that reference them by literal path/name — grep across bin/, agents/, contracts/, config/, and docs/ before renaming anything. The `Return (exact shape)` blocks in subagent prompts are interfaces parsed by their dispatchers, and `SCHEDULE` loop names must match `agents/<loop>/` directories.

**Two safety layers that must stay in sync.** Mechanical floors live in `bin/run-loop.sh` — singleton lock, `ops/PAUSE` kill switch, 3-strikes breaker, hard timeout, preflight, and post-run: no-go revert, self-accept guard, queue lint, diff accounting, digest guarantee, `> NOTIFY:` fan-out, retention caps. Behavioral rules live in `contracts/` and the agent prompts. Several rules exist in both layers: the bash queue lint mirrors `contracts/issue-format.md`, the self-accept guard mirrors `contracts/write-policy.md`'s human-only labels, the NOTIFY fan-out mirrors `contracts/digest-format.md`. When changing a contract, check whether a floor in `run-loop.sh` implements the same rule, and vice versa. Design law #1: anything money- or safety-shaped belongs in bash, not only in prompt text.

**The env interface.** `run-loop.sh` exports `ILOOP_ROOT`, `ILOOP_CONFIG`, `ILOOP_RUN_ID`, `ILOOP_STATE`, `ILOOP_DEADLINE_EPOCH`; prompts reference these names literally. Cost accounting parses the runner's stream-json result line (claude CLI format — `"type":"result"` with `total_cost_usd`); other runners degrade to cost 0.

**Dispatcher pattern.** Orchestrator, fixer, and pr-verifier never do the work themselves: they select units of work, spawn one fresh subagent per unit (issue / PR / focus area — prompts in `subagents/`) in isolated worktrees, then collect results and perform all git/GitHub writes per the lane table in `contracts/write-policy.md`. Subagents only propose; the verify-one-pr subagent writes nothing at all.

**State lives in two places.** Harness state outside the target repo in `$STATE_DIR` (`~/.improve-loop/<project>`: logs, locks, `runs.jsonl`, breaker flags, evidence). Loop output inside the target repo under `ops/` (daily digests, ledgers, metrics, the human-owned `DIRECTION.md`, and the marker files `PAUSE` / `DEMOTED` / `BLOCKED`).

**Label vocabulary is a contract.** `templates/labels.sh`, `contracts/queue-state-machine.md`, the bash queue lint, and the agent prompts all encode the same labels (`loop-filed`, `accepted`, `action:*`, `component:*`, `bug`, `loop-pr`, `🙋 needs-your-decision`, `changes-requested`) — change them everywhere or nowhere.

**Tests are hermetic via HOME redirection.** `tests/lib.sh` runs the REAL `run-loop.sh` with `HOME` pointed into a mktemp sandbox; stub binaries (gh, fake-agent, osascript, df, …) sit in `<sandbox>/home/.local/bin` and win resolution because `run-loop.sh`'s own PATH re-export puts `$HOME/.local/bin` first. **That ordering is load-bearing**: reordering the PATH line in `run-loop.sh`/`preflight.sh` breaks the whole suite's stubbing. Tests never touch the network — gh/curl/agent are stubs, fixture remotes are local bare repos.

**Self-hosting rails.** When this repo is its own target, the loop may edit `bin/`, `agents/`, `contracts/`, `docs/`, `templates/`, `tests/` via PRs, but never `selfhost/` (the promotion gate + e2e rubric), `ops/DIRECTION.md`, `ops/loop.config.sh`, or `.github/` — and it executes from a promoted live checkout, not this tree (`docs/SELF-HOSTING.md`).

## Shell conventions

- `run-loop.sh` deliberately uses `set -uo pipefail` **without** `-e`: every failure is handled explicitly so a mid-run error cannot skip the post-run floors. Keep it that way.
- `notify.sh` must never fail its caller; `preflight.sh` always exits 0 and communicates via its JSON `verdict` (abort only for: git broken, disk <5 GB, agent auth dead, gh unable to reach `GH_REPO` — everything else is a soft flag agents map to skipped stages).
- Portability is macOS + Linux: mkdir-based locks (macOS has no flock), `gtimeout || timeout`, `df -g` vs `df -BG`, launchd vs cron.

## Design laws

`docs/DESIGN.md` is the normative intent that audits diff against — keep it, README.md, and actual behavior consistent when changing any of them. The laws that shape most edits: mechanical floors over prompt text; 1 agent = 1 issue (fresh context per unit of work); verification is a separate agent whose default is REJECT; bugs enter the auto lane only with a runnable `Repro:` (plus 24 h cooling when unaccepted); every open issue is in exactly one state with a named next actor (`contracts/queue-state-machine.md`); the harness never edits its own rails and improves only at human cadence — `docs/AUDIT-CHECKLIST.md` is a fixed 10-item spec, do not add criteria to it.
