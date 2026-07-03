#!/usr/bin/env bash
# tests/lib.sh — sourced by every tests/t/*.sh.
#
# Hermeticity: each test gets a mktemp sandbox holding a fixture target
# project (built by selfhost/fixture.sh via the REAL install.sh), a fake
# HOME whose ~/.local/bin carries the stubs, and a STATE_DIR. run-loop.sh
# re-exports PATH with $HOME/.local/bin first, so redirecting HOME into the
# sandbox makes the stubs win while real git/jq resolve from the system
# tail. Nothing a test does can write outside its sandbox.
set -euo pipefail

T_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export T_REPO

t_setup() {
  T_SB="$(mktemp -d "${TMPDIR:-/tmp}/iloop-test.XXXXXX")"
  T_SB="$(cd "$T_SB" && pwd)"    # normalize (macOS TMPDIR has a trailing /)
  export T_SB
  export T_HOME="$T_SB/home" T_PROJ="$T_SB/proj" T_STATE="$T_SB/state"
  export T_BIN="$T_SB/home/.local/bin" T_CAP="$T_SB/captured" T_GH="$T_SB/gh"
  trap t_teardown EXIT
  bash "$T_REPO/selfhost/fixture.sh" "$T_SB" --engine "$T_REPO" --force >/dev/null
  export T_CFG="$T_PROJ/ops/loop.config.sh"
  mkdir -p "$T_CAP" "$T_GH/issues"
  : >"$T_CAP/notifications.log"
  : >"$T_CAP/gh-mutations.log"
  T_PIDS=()
}

t_teardown() {
  local pid
  for pid in "${T_PIDS[@]:-}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  if [[ "${T_KEEP:-0}" != 1 && -n "${T_SB:-}" && -d "${T_SB:-}" ]]; then
    rm -rf "$T_SB"
  fi
}

# ── invoking the system under test ──────────────────────────────────────
# Extra args are VAR=val pairs passed through the environment (e.g.
# LOOP_TIMEOUT_S=2, FAKE_AGENT_RC=7, DF_STUB_GB=2, T_GH_AUTH_RC=1).
t_env() {
  env HOME="$T_HOME" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 \
      PATH="$T_BIN:$PATH" T_CAP="$T_CAP" T_GH_DIR="$T_GH" "$@"
}

t_run_loop() { # <loop> [VAR=val…]
  local loop="$1"; shift
  set +e
  t_env "$@" bash "$T_REPO/bin/run-loop.sh" "$loop" "$T_CFG" >"$T_CAP/run.out" 2>&1
  T_RC=$?
  set -e
}

t_run_check() { # <--check-mode> <arg> [VAR=val…]
  local mode="$1" arg="$2"; shift 2
  set +e
  t_env "$@" bash "$T_REPO/bin/run-loop.sh" "$mode" "$arg" "$T_CFG" >"$T_CAP/check.out" 2>"$T_CAP/check.err"
  T_RC=$?
  set -e
}

t_preflight() { # <loop> [VAR=val…]
  local loop="$1"; shift
  set +e
  t_env "$@" bash "$T_REPO/bin/preflight.sh" "$loop" "$T_CFG" >"$T_CAP/preflight.json" 2>"$T_CAP/preflight.err"
  T_RC=$?
  set -e
}

# ── fixture helpers ──────────────────────────────────────────────────────
t_config_set() { # append raw config lines (last assignment wins on source)
  printf '%s\n' "$@" >>"$T_CFG"
  t_git add ops/loop.config.sh
  t_git commit -qm "test: config override"
}

t_agent_script() { # scenario for fake-agent, from stdin
  cat >"$T_SB/scenario.sh"
  export FAKE_AGENT_SCRIPT="$T_SB/scenario.sh"
}

t_git() { t_env git -C "$T_PROJ" "$@"; }

t_commit_ok() { # innocent commit; echoes sha
  echo "ok $(date +%s%N 2>/dev/null || date +%s)" >>"$T_PROJ/README.md"
  t_git add README.md
  t_git commit -qm "loop: innocent change"
  t_git rev-parse HEAD
}

t_commit_nogo() { # commit touching a NOGO path; echoes sha
  local path="${1:-ops/DIRECTION.md}"
  echo "tampered" >>"$T_PROJ/$path"
  t_git add "$path"
  t_git commit -qm "loop: tamper with $path"
  t_git rev-parse HEAD
}

t_seed_runs() { # <loop> <result>… — append minimal runs.jsonl rows
  local loop="$1"; shift
  mkdir -p "$T_STATE"
  local r
  for r in "$@"; do
    printf '{"loop":"%s","started":"2026-01-01T00:00:00Z","ended":"2026-01-01T00:10:00Z","rc":1,"timed_out":false,"cost_usd":0.01,"commits":0,"insertions":0,"deletions":0,"nogo_reverts":0,"log":"seeded","result":"%s"}\n' \
      "$loop" "$r" >>"$T_STATE/runs.jsonl"
  done
}

t_gh_issue() { # <number> <labels-csv> [body] [createdAt] — register an open issue
  local n="$1" labels="$2" body="${3:-$'## Found\nseeded\n## Repro\nbash src/app.sh x'}"
  local created="${4:-2026-01-01T00:00:00Z}"
  jq -n --arg labels "$labels" --arg body "$body" \
    '{labels: ($labels | split(",") | map(select(length>0)) | map({name:.})), body: $body}' \
    >"$T_GH/issues/$n.json"
  jq -cn --argjson n "$n" --arg labels "$labels" --arg body "$body" --arg created "$created" \
    '{number: $n, title: "issue \($n)", createdAt: $created, body: $body,
      labels: ($labels | split(",") | map(select(length>0)) | map({name:.}))}' \
    >>"$T_GH/issue-meta.jsonl"
  jq -s '.' "$T_GH/issue-meta.jsonl" >"$T_GH/issue-list.json"
}

t_gh_pr() { # <number> <labels-csv> [createdAt] — register an open PR
  local n="$1" labels="$2" created="${3:-2026-01-01T00:00:00Z}"
  jq -cn --argjson n "$n" --arg labels "$labels" --arg created "$created" \
    '{number: $n, title: "pr \($n)", createdAt: $created,
      labels: ($labels | split(",") | map(select(length>0)) | map({name:.}))}' \
    >>"$T_GH/pr-meta.jsonl"
  jq -s '.' "$T_GH/pr-meta.jsonl" >"$T_GH/pr-list.json"
}

t_gh_events() { # events.json from stdin
  cat >"$T_GH/events.json"
}

# ── readers ──────────────────────────────────────────────────────────────
t_last_row() { tail -1 "$T_STATE/runs.jsonl"; }
t_row() { t_last_row | jq -r "$1"; }
t_runlog() { ls -t "$T_STATE/logs/${1:-*}"-2*.log 2>/dev/null | head -1; }
t_digest() { echo "$T_PROJ/ops/reports/$(date +%F).md"; }
t_notifications() { cat "$T_CAP/notifications.log" 2>/dev/null || true; }
t_mutations() { cat "$T_CAP/gh-mutations.log" 2>/dev/null || true; }

t_spawn() { # background process registered for teardown; echoes pid
  "$@" >/dev/null 2>&1 &
  local pid=$!
  T_PIDS+=("$pid")
  echo "$pid"
}

# ── assertions (names kept bats-assert-compatible where sensible) ───────
t_fail() {
  printf 'ASSERT FAIL: %s\n' "$*" >&2
  if [[ -f "$T_CAP/run.out" ]]; then
    printf '%s\n' '--- run.out (tail) ---' >&2
    tail -15 "$T_CAP/run.out" >&2 || true
  fi
  exit 1
}

t_assert_rc() { [[ "${T_RC:-none}" == "$1" ]] || t_fail "rc=${T_RC:-none}, want $1"; }

t_assert_eq() { [[ "$1" == "$2" ]] || t_fail "'$1' != '$2'${3:+ ($3)}"; }

t_assert_contains() { # <file-or-string> <needle>
  if [[ -f "$1" ]]; then
    grep -qF -- "$2" "$1" || t_fail "no '$2' in file $1"
  else
    [[ "$1" == *"$2"* ]] || t_fail "no '$2' in: ${1:0:300}"
  fi
}

t_assert_not_contains() {
  if [[ -f "$1" ]]; then
    ! grep -qF -- "$2" "$1" || t_fail "unexpected '$2' in file $1"
  else
    [[ "$1" != *"$2"* ]] || t_fail "unexpected '$2' in: ${1:0:300}"
  fi
}

t_assert_exists() { [[ -e "$1" ]] || t_fail "missing: $1"; }
t_assert_absent() { [[ ! -e "$1" ]] || t_fail "should not exist: $1"; }

t_assert_line_count() { # <file> <n>
  local n
  n=$(wc -l <"$1" 2>/dev/null | tr -d '[:space:]')
  [[ "${n:-0}" == "$2" ]] || t_fail "$1 has ${n:-0} lines, want $2"
}
