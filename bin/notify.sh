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
    # Crush double quotes in plain assignments BEFORE the format string:
    # doing it inline inside the double-quoted -e argument mis-parses on
    # modern bash (the replacement's quote pairs with the next expansion's),
    # garbling the text and letting \" escape the AppleScript string context.
    # Identical on bash 3.2 (launchd) and bash 5.
    msg_crushed=${MSG//\"/\'}
    title_crushed=${TITLE//\"/\'}
    osascript -e "display notification \"$msg_crushed\" with title \"$title_crushed\" sound name \"Submarine\"" 2>/dev/null ;;
  notify-send)
    notify-send "$TITLE" "$MSG" 2>/dev/null ;;
  webhook)
    curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
      -d "$(jq -cn --arg t "$TITLE" --arg m "$MSG" '{text: ($t + ": " + $m)}')" \
      "$NOTIFY_WEBHOOK_URL" >/dev/null 2>&1 ;;
  none|*) : ;;
esac
exit 0
