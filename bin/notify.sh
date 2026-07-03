#!/usr/bin/env bash
# bin/notify.sh <config> <title> <message> — cross-platform, best-effort.
# Never fails the caller: a missing GUI session must not break a loop run.
CONFIG="${1:?config}"; TITLE="${2:-improve-loop}"; MSG="${3:-}"
# shellcheck source=/dev/null
source "$CONFIG" 2>/dev/null

method="${NOTIFY_METHOD:-auto}"
if [[ "$method" == "auto" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then method=osascript
  elif command -v notify-send >/dev/null; then method=notify-send
  elif [[ -n "${NOTIFY_WEBHOOK_URL:-}" ]]; then method=webhook
  else method=none; fi
fi

case "$method" in
  osascript)
    # Crush double quotes to single quotes in plain assignments BEFORE the
    # format string: an inline ${VAR//\"/'} mis-pairs its quote with the
    # next expansion's on modern bash (garbled output), and a stray \" can
    # terminate the AppleScript string context (injection surface).
    sq="'"
    msg_safe="${MSG//\"/$sq}"; title_safe="${TITLE//\"/$sq}"
    osascript -e "display notification \"$msg_safe\" with title \"$title_safe\" sound name \"Submarine\"" 2>/dev/null ;;
  notify-send)
    notify-send "$TITLE" "$MSG" 2>/dev/null ;;
  webhook)
    curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
      -d "$(jq -cn --arg t "$TITLE" --arg m "$MSG" '{text: ($t + ": " + $m)}')" \
      "$NOTIFY_WEBHOOK_URL" >/dev/null 2>&1 ;;
  none|*) : ;;
esac
exit 0
