#!/bin/bash
# Start face (detached) then voice — the recommended full stack launch.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if [ -x ./start-visualizer.sh ]; then
  ./start-visualizer.sh || echo "[stack] visualizer start failed — continuing with voice only" >&2
fi
exec ./run.sh "$@"
