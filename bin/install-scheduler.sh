#!/usr/bin/env bash
# bin/install-scheduler.sh <config> [--uninstall]
# Installs the SCHEDULE from loop.config.sh as launchd agents (macOS) or
# crontab entries (Linux). Idempotent; re-run after editing SCHEDULE.
# Loops whose agents/<loop>/AGENT.md is missing are skipped loudly.
set -euo pipefail
CONFIG="${1:?usage: install-scheduler.sh <config> [--uninstall]}"
MODE="${2:-install}"
# shellcheck source=/dev/null
source "$CONFIG"
RUNNER="$ILOOP_ROOT/bin/run-loop.sh"
OS=$(uname)

if [[ "$OS" == "Darwin" ]]; then
  LA="$HOME/Library/LaunchAgents"; GUI="gui/$(id -u)"; mkdir -p "$LA" "$STATE_DIR/logs"
  if [[ "$MODE" == "--uninstall" ]]; then
    for f in "$LA/com.improve-loop.$PROJECT_NAME."*.plist; do
      [[ -e "$f" ]] || continue
      launchctl bootout "$GUI" "$f" 2>/dev/null || true; rm -f "$f"; echo "removed $(basename "$f")"
    done; exit 0
  fi
  for job in "${SCHEDULE[@]}"; do
    IFS='|' read -r loop hour min wday timeout <<<"$job"
    if [[ ! -f "$ILOOP_ROOT/agents/$loop/AGENT.md" ]]; then echo "SKIP $loop — no agents/$loop/AGENT.md"; continue; fi
    label="com.improve-loop.$PROJECT_NAME.$loop"; plist="$LA/$label.plist"; wday_xml=""
    [[ -n "$wday" ]] && wday_xml="<key>Weekday</key><integer>$wday</integer>"
    cat >"$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$RUNNER</string><string>$loop</string><string>$CONFIG</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>$hour</integer><key>Minute</key><integer>$min</integer>$wday_xml</dict>
  <key>EnvironmentVariables</key><dict><key>LOOP_TIMEOUT_S</key><string>$timeout</string></dict>
  <key>WorkingDirectory</key><string>$PROJECT_DIR</string>
  <key>StandardOutPath</key><string>$STATE_DIR/logs/launchd-$loop.log</string>
  <key>StandardErrorPath</key><string>$STATE_DIR/logs/launchd-$loop.log</string>
  <key>RunAtLoad</key><false/>
  <key>ProcessType</key><string>Interactive</string>
</dict>
</plist>
PLIST
    launchctl bootout "$GUI" "$plist" 2>/dev/null || true
    launchctl bootstrap "$GUI" "$plist"
    printf 'installed %-40s %02d:%02d %s (timeout %ss)\n' "$label" "$hour" "$min" "${wday:+wday=$wday}" "$timeout"
  done
else # Linux: crontab entries between managed markers
  TAG="# improve-loop:$PROJECT_NAME"
  CUR=$(crontab -l 2>/dev/null | grep -v "$TAG" || true)
  if [[ "$MODE" == "--uninstall" ]]; then printf '%s\n' "$CUR" | crontab -; echo "removed $PROJECT_NAME entries"; exit 0; fi
  NEW="$CUR"
  for job in "${SCHEDULE[@]}"; do
    IFS='|' read -r loop hour min wday timeout <<<"$job"
    if [[ ! -f "$ILOOP_ROOT/agents/$loop/AGENT.md" ]]; then echo "SKIP $loop — no agents/$loop/AGENT.md"; continue; fi
    dow="${wday:-*}"
    NEW+=$'\n'"$min $hour * * $dow LOOP_TIMEOUT_S=$timeout /bin/bash $RUNNER $loop $CONFIG $TAG"
    printf 'installed cron %-14s %02d:%02d dow=%s\n' "$loop" "$hour" "$min" "$dow"
  done
  printf '%s\n' "$NEW" | crontab -
fi
echo
echo "Pause all loops:  touch $PROJECT_DIR/ops/PAUSE   (delete to resume)"
echo "Manual run:       bash $RUNNER <loop> $CONFIG"
