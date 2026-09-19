#!/bin/bash
# launchd entrypoint — opens Terminal for mic + hotkey permissions on macOS.
# backtalk must NOT run headless: it inherits the terminal's Microphone and
# Input Monitoring permissions (see TROUBLESHOOTING.md).
set -euo pipefail
LOG_DIR="/Users/balamurugan/Projects/.logs"
mkdir -p "$LOG_DIR"
# If a Cursor-hosted copy is running, it has no talk key — replace it.
if pgrep -f 'backtalk[.]main' >/dev/null 2>&1; then
  host_ok=false
  for pid in $(pgrep -f 'backtalk[.]main'); do
    p=$pid
    for _ in 1 2 3 4 5 6 7 8; do
      comm=$(ps -p "$p" -o comm= 2>/dev/null || true)
      if [[ "$comm" == *Terminal* ]]; then host_ok=true; break 2; fi
      if [[ "$comm" == *Cursor* ]]; then break; fi
      p=$(ps -p "$p" -o ppid= 2>/dev/null | tr -d ' ')
      [[ -z "$p" || "$p" -le 1 ]] && break
    done
  done
  if $host_ok; then
    echo "$(date -Iseconds) backtalk already running in Terminal" >> "$LOG_DIR/backtalk-launchd.log"
    exit 0
  fi
  echo "$(date -Iseconds) killing Cursor-hosted backtalk (no PTT)" >> "$LOG_DIR/backtalk-launchd.log"
  pkill -f 'backtalk[.]main' 2>/dev/null || true
  sleep 2
fi
/usr/bin/open -a Terminal "/Users/balamurugan/Projects/backtalk/Jarvis Voice.command"
echo "$(date -Iseconds) opened Jarvis Voice in Terminal" >> "$LOG_DIR/backtalk-launchd.log"
