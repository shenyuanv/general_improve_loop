# Contract: write policy, by lane

The loops run under the operator's own identity, so permissions are enforced
by contract + the wrapper's mechanical floors, not by GitHub's permission
model. Every agent prompt embeds its lane's policy; violating it is an
incident (DEMOTED).

| Lane | Git writes | GitHub writes |
|---|---|---|
| Orchestrator + its subagents | commits to main: **ops/ paths only**, explicit `git add` paths, `loop:`-prefixed; push under the push guard | `gh issue create` + grooming edits (`gh issue edit` on **loop-filed** issues only: add `bug`/`component:*` labels or append Repro/Verify — NEVER `accepted`/`rejected`/`🙋`, never a human-filed issue, never comment/close/react) |
| E2E loops (user, tester) | ops/ paths only (ledger + report section), `loop(<name>):` prefix | `gh issue create` only |
| Fixer **dispatcher** | ops/ paths only | none |
| Fixer **fix subagent** (one per issue) | its ONE branch `loop/fix-GH<n>` in its own worktree; never main | its ONE `gh pr create` (label `loop-pr`, body `Fixes #<n>`) |
| Verifier **dispatcher** | ops/ paths only; `git pull --ff-only` after merges | on `loop-pr` PRs ONLY: `gh pr merge --squash --delete-branch` on PASS; `gh pr comment` (verbatim evidence) + `changes-requested` label on FAIL |
| Verifier **verify subagent** (one per PR) | none (worktree read/build/test only) | none |

Universal rules, every lane:

1. Never rebase, merge, stash, force-push, or amend human commits. Never
   `git add -A`. Never `git reset --hard` anything shared.
2. Push guard: push main only when EVERY unpushed commit is loop-prefixed —
   never publish the human's WIP.
3. No-go paths (DIRECTION + config `NOGO_PATHS`) are untouchable in every
   lane including branches — the verifier is the no-go floor for merges,
   the wrapper for main.
4. Issue closure happens only via `Fixes #n` in merge/commit messages.
5. Secret hygiene: never print or commit credentials, tokens, or key
   material into logs, digests, issues, or PRs; telemetry is aggregates
   only — no user emails/IPs/filenames.
6. Notifications: write `> NOTIFY: <short>` digest lines (max 3/run); the
   wrapper fans them out. Never call the OS notifier directly.
