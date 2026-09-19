#!/bin/bash
# Clone/configure ai-visualizer beside this backtalk folder (macOS one-click stack).
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

BACKTALK="$(pwd)"
PARENT="$(cd .. && pwd)"
VIS="${BACKTALK_VISUALIZER_DIR:-$PARENT/ai-visualizer}"
URL="${BACKTALK_VISUALIZER_REPO:-https://github.com/vikrambalaaj/ai-visualizer}"
FORK_REMOTE="vikrambalaaj"

echo "== ai-visualizer install =="

if [ -d "$VIS/.git" ]; then
  echo "-- already cloned at $VIS"
  if ! git -C "$VIS" remote get-url "$FORK_REMOTE" >/dev/null 2>&1; then
    git -C "$VIS" remote add "$FORK_REMOTE" "$URL" 2>/dev/null || \
      git -C "$VIS" remote set-url "$FORK_REMOTE" "$URL"
  fi
  git -C "$VIS" fetch -q "$FORK_REMOTE" 2>/dev/null || \
    git -C "$VIS" fetch -q origin 2>/dev/null || true
  if git -C "$VIS" show-ref --verify --quiet "refs/remotes/${FORK_REMOTE}/main"; then
    git -C "$VIS" pull --ff-only -q "$FORK_REMOTE" main 2>/dev/null || \
      echo "   (could not fast-forward from $FORK_REMOTE — using existing copy)"
  else
    git -C "$VIS" pull --ff-only -q origin main 2>/dev/null || \
      echo "   (could not fast-forward — using existing copy)"
  fi
elif [ -d "$VIS" ]; then
  echo "-- folder exists at $VIS (not a git repo) — wiring config only"
else
  echo "-- cloning to $VIS"
  git clone -q "$URL" "$VIS"
fi

chmod +x "$VIS/run.sh" 2>/dev/null || true
for f in "$VIS"/*.command "$VIS"/*.sh; do
  [ -f "$f" ] && xattr -d com.apple.quarantine "$f" 2>/dev/null || true
done

CFG="$VIS/ai-visualizer.json"
if [ ! -f "$CFG" ]; then
  cp "$VIS/ai-visualizer.json.example" "$CFG"
  echo "-- created ai-visualizer.json"
fi

PY=".venv/bin/python3"
[ -x "$PY" ] || PY="python3"
"$PY" - <<PY
import json
from pathlib import Path

bt = Path("$BACKTALK")
vis = Path("$VIS")
vcfg = vis / "ai-visualizer.json"
data = json.loads(vcfg.read_text())
# Merge wiring only — preserve face, port, badge, thinking_sound, etc.
data["bus_dir"] = str(bt)
try:
    b = json.loads((bt / "backtalk.json").read_text())
    if b.get("name"):
        data["name"] = b["name"]
except (OSError, ValueError):
    pass
vcfg.write_text(json.dumps(data, indent=2) + "\n")
print(f"-- wired bus_dir -> {bt}")
PY

echo "$VIS" > .visualizer-path

# Health: visualizer server responds (starts detached if needed).
if [ -x "$BACKTALK/start-visualizer.sh" ]; then
  "$BACKTALK/start-visualizer.sh" --check-only 2>/dev/null && \
    echo "-- visualizer: already running" || \
    echo "-- visualizer: start with ./start-stack.sh or Desktop Stack shortcut"
fi

echo "== ai-visualizer ready =="
