#!/bin/bash
# Start ai-visualizer detached (survives voice terminal close). Idempotent.
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck source=stack-common.sh
source ./stack-common.sh
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

CHECK_ONLY=0
OPEN_BROWSER=1
for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=1 ;;
    --no-open) OPEN_BROWSER=0 ;;
  esac
done

VIS="$(stack_visualizer_dir)"
if [ -z "$VIS" ] || [ ! -x "$VIS/run.sh" ]; then
  echo "[stack] ai-visualizer not installed — run ./install-visualizer.sh" >&2
  exit 1
fi

PORT="$(stack_visualizer_port "$VIS")"
URL="$(stack_visualizer_url "$VIS")"
LOG="$(stack_log_dir)/visualizer.log"

if stack_wait_visualizer "$PORT" 3; then
  echo "[stack] visualizer already running on port $PORT"
  if [ "$CHECK_ONLY" = 1 ]; then exit 0; fi
  [ "$OPEN_BROWSER" = 1 ] && /usr/bin/open "$URL" 2>/dev/null || true
  exit 0
fi

if [ "$CHECK_ONLY" = 1 ]; then
  echo "[stack] visualizer not running on port $PORT" >&2
  exit 1
fi

echo "[stack] starting visualizer (detached) → $URL"
nohup bash -c "cd '$VIS' && exec ./run.sh --no-open" >>"$LOG" 2>&1 &
echo $! > "$(stack_log_dir)/visualizer.pid"

if stack_wait_visualizer "$PORT" 40; then
  echo "[stack] visualizer ready"
  [ "$OPEN_BROWSER" = 1 ] && /usr/bin/open "$URL" 2>/dev/null || true
  exit 0
fi

echo "[stack] visualizer failed to become ready — see $LOG" >&2
exit 1
