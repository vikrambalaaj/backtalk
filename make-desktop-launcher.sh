#!/bin/bash
# Desktop shortcuts: voice, face, and full stack.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO="$(pwd)"

NAME="Voice"
if [ -f backtalk.json ]; then
  NAME="$(.venv/bin/python -c "import json; print(json.load(open('backtalk.json')).get('name','Voice'))" 2>/dev/null || echo Voice)"
fi

VIS=""
if [ -f .visualizer-path ]; then
  VIS="$(cat .visualizer-path)"
elif [ -x "../ai-visualizer/run.sh" ]; then
  VIS="$(cd ../ai-visualizer && pwd)"
fi

write_launcher() {
  local dest="$1"
  local body="$2"
  cat > "$dest" <<EOF
#!/bin/bash
export PATH="\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"
$body
EOF
  chmod +x "$dest"
  xattr -d com.apple.quarantine "$dest" 2>/dev/null || true
  echo "Desktop launcher: $dest"
}

write_launcher "$HOME/Desktop/${NAME} Voice.command" "cd \"$REPO\"
exec ./run.sh"

if [ -n "$VIS" ] && [ -x "$VIS/run.sh" ]; then
  write_launcher "$HOME/Desktop/${NAME} Face.command" "cd \"$REPO\"
exec ./start-visualizer.sh"
  write_launcher "$HOME/Desktop/${NAME} Stack.command" "cd \"$REPO\"
exec ./start-stack.sh"
fi
