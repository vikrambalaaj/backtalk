#!/bin/bash
# Idempotent first-run setup — safe to call before every launch.
# Used by Start Voice.command so double-click install + run works.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

REPO="$(pwd)"
YES=0
QUICK=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --quick) QUICK=1 ;;
  esac
done
[ "${BACKTALK_YES:-}" = "1" ] && YES=1

echo "== backtalk setup =="

# macOS: downloaded launchers often carry quarantine; clear on our scripts.
if [[ "$(uname -s)" == "Darwin" ]]; then
  for f in "Start Voice.command" "Jarvis Voice.command" setup.sh install.sh run.sh; do
    [ -f "$f" ] && xattr -d com.apple.quarantine "$f" 2>/dev/null || true
  done
fi

if [ ! -f backtalk.json ]; then
  cp backtalk.json.example backtalk.json
  echo "-- created backtalk.json from the example (edit agent_dir + name for your agent)"
fi

if ! command -v claude >/dev/null 2>&1; then
  echo ""
  echo "!! Claude Code is not installed or not on PATH."
  echo "   Install it first: https://claude.com/claude-code"
  echo "   Then double-click Start Voice.command again."
  echo ""
  if [ "$QUICK" = 0 ]; then
    read -r -p "Continue anyway? [y/N] " a
    [ "$a" = "y" ] || [ "$a" = "Y" ] || exit 1
  else
    exit 1
  fi
fi

need_install=0
if [ ! -d .venv ] || [ ! -x .venv/bin/python ]; then
  need_install=1
fi

if [ "$need_install" = 1 ]; then
  echo "-- first install (downloads ~2GB once: packages + speech models)"
  if [ "$YES" = 1 ]; then
    ./install.sh --yes
  else
    ./install.sh
  fi
else
  echo "-- environment: already present"
  uv sync -q --inexact 2>/dev/null || true
  if [ "$QUICK" = 0 ] && [ "$1" != "--no-models" ]; then
    .venv/bin/python - <<'PY' 2>/dev/null || true
import warnings; warnings.filterwarnings("ignore")
from backtalk.ears import warm as warm_ears
from backtalk.mouth import warm as warm_mouth
warm_ears(); warm_mouth()
PY
  fi
fi

echo "== setup complete =="
echo "Repo: $REPO"
