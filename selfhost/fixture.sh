#!/usr/bin/env bash
# selfhost/fixture.sh <dest-dir> [--engine <path>] [--bare-remote] [--force]
#
# Generates a throwaway TARGET PROJECT wired to this engine, fully sandboxed:
#   <dest>/proj    a git repo scaffolded by the real install.sh (the product
#                  under improvement: one script, committed clean tree)
#   <dest>/state   STATE_DIR for the wrapper (logs, runs.jsonl, locks)
#   <dest>/home    a fake $HOME; stubs in home/.local/bin win PATH resolution
#                  even after run-loop.sh's PATH re-export
# Prints the generated config path on stdout. Shared by tests/lib.sh, the
# self-host E2E journey, and selfhost/verify-live.sh's floor drill.
set -euo pipefail

DEST=""; ENGINE=""; BARE_REMOTE=0; FORCE=0
while (( $# )); do
  case "$1" in
    --engine)      ENGINE="${2:?--engine needs a path}"; shift 2 ;;
    --bare-remote) BARE_REMOTE=1; shift ;;
    --force)       FORCE=1; shift ;;
    -*)            echo "unknown flag $1" >&2; exit 64 ;;
    *)             DEST="$1"; shift ;;
  esac
done
[[ -n "$DEST" ]] || { echo "usage: fixture.sh <dest-dir> [--engine <path>] [--bare-remote] [--force]" >&2; exit 64; }
ENGINE="${ENGINE:-$(cd "$(dirname "$0")/.." && pwd)}"
[[ -f "$ENGINE/install.sh" ]] || { echo "$ENGINE does not look like the engine (no install.sh)" >&2; exit 64; }

if [[ -d "$DEST" ]] && [[ -n "$(ls -A "$DEST" 2>/dev/null)" ]] && (( ! FORCE )); then
  echo "$DEST exists and is not empty (use --force)" >&2; exit 2
fi
mkdir -p "$DEST/proj" "$DEST/state" "$DEST/home/.local/bin"
DEST="$(cd "$DEST" && pwd)"
PROJ="$DEST/proj"; FHOME="$DEST/home"

# Fake-HOME git identity so nothing reads the real ~/.gitconfig
cat >"$FHOME/.gitconfig" <<'EOF'
[user]
	name = Fixture User
	email = fixture@example.invalid
[init]
	defaultBranch = main
[commit]
	gpgsign = false
[advice]
	detachedHead = false
EOF
fgit() { env HOME="$FHOME" GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 git "$@"; }

# Stub binaries: everything except uname (lies about the OS — scheduler tests
# opt into it via a separate dir) and timeout (only shimmed where absent).
for s in "$ENGINE"/tests/stubs/*; do
  b="$(basename "$s")"
  case "$b" in
    uname) continue ;;
    timeout) command -v timeout >/dev/null 2>&1 && continue ;;
  esac
  cp "$s" "$FHOME/.local/bin/$b" && chmod +x "$FHOME/.local/bin/$b"
done

# The product under improvement: minimal but real enough for a journey
fgit -C "$PROJ" init -q
mkdir -p "$PROJ/src"
cat >"$PROJ/README.md" <<'EOF'
# fixture-product
A one-command product used to exercise the improve loop hermetically.
Run: `bash src/app.sh <name>` — prints a greeting and exits 0.
EOF
cat >"$PROJ/src/app.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'hello, %s\n' "${1:?usage: app.sh <name>}"
EOF
chmod +x "$PROJ/src/app.sh"
fgit -C "$PROJ" add -A
fgit -C "$PROJ" commit -qm "fixture: initial product"

# Scaffold with the REAL installer (also exercises it), then pin every path
# into the sandbox. Later assignments win when the config is sourced.
"$ENGINE/install.sh" "$PROJ" >/dev/null
CFG="$PROJ/ops/loop.config.sh"
cat >>"$CFG" <<EOF

# ── fixture overrides (appended by selfhost/fixture.sh) ─────────────────
PROJECT_NAME="fixture"
GH_REPO="stub-owner/stub-repo"
STATE_DIR="$DEST/state"
RUNNER_BIN="$FHOME/.local/bin/fake-agent"
RUNNER_FLAGS=(--stub)
RUNNER_AUTH_PROBE='echo OK'
GATES=("true")
NOTIFY_METHOD="osascript"
EOF

fgit -C "$PROJ" add -A
fgit -C "$PROJ" commit -qm "fixture: improve-loop scaffold"

if (( BARE_REMOTE )); then
  fgit init -q --bare "$DEST/remote.git"
  fgit -C "$PROJ" remote add origin "$DEST/remote.git"
  fgit -C "$PROJ" push -qu origin main
fi

echo "$CFG"
