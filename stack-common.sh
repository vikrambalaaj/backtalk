#!/bin/bash
# Shared helpers for backtalk + ai-visualizer stack launchers.
stack_backtalk_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

stack_visualizer_dir() {
  local bt
  bt="$(stack_backtalk_dir)"
  if [ -f "$bt/.visualizer-path" ]; then
    cat "$bt/.visualizer-path"
  elif [ -x "$bt/../ai-visualizer/run.sh" ]; then
    cd "$bt/../ai-visualizer" && pwd
  else
    echo ""
  fi
}

stack_visualizer_port() {
  local vis="${1:-$(stack_visualizer_dir)}"
  local cfg="$vis/ai-visualizer.json"
  if [ -f "$cfg" ]; then
    python3 -c "import json; print(int(json.load(open('$cfg')).get('port', 8790)))" 2>/dev/null || echo 8790
  else
    echo 8790
  fi
}

stack_visualizer_url() {
  local vis="${1:-$(stack_visualizer_dir)}"
  local port
  port="$(stack_visualizer_port "$vis")"
  local face="board"
  if [ -f "$vis/ai-visualizer.json" ]; then
    face="$(python3 -c "import json; print(json.load(open('$vis/ai-visualizer.json')).get('face','board'))" 2>/dev/null || echo board)"
  fi
  if [ -f "$vis/faces/$face/index.html" ]; then
    echo "http://127.0.0.1:${port}/faces/${face}/"
  else
    echo "http://127.0.0.1:${port}/"
  fi
}

stack_wait_visualizer() {
  local port="${1:-8790}"
  local tries="${2:-30}"
  local i=0
  while [ "$i" -lt "$tries" ]; do
    if curl -sf -m 2 "http://127.0.0.1:${port}/state" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.5
    i=$((i + 1))
  done
  return 1
}

stack_log_dir() {
  local d="${BACKTALK_LOG_DIR:-$HOME/.local/share/backtalk/logs}"
  mkdir -p "$d"
  echo "$d"
}
