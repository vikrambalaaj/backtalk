#!/bin/bash
# Put a Desktop shortcut that always points at this install folder.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO="$(pwd)"

NAME="Voice"
if [ -f backtalk.json ]; then
  NAME="$(.venv/bin/python -c "import json; print(json.load(open('backtalk.json')).get('name','Voice'))" 2>/dev/null || echo Voice)"
fi
DEST="$HOME/Desktop/${NAME} Voice.command"

cat > "$DEST" <<EOF
#!/bin/bash
export PATH="\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"
cd "$REPO"
exec ./run.sh
EOF
chmod +x "$DEST"
xattr -d com.apple.quarantine "$DEST" 2>/dev/null || true
echo "Desktop launcher: $DEST"
echo "Double-click it to start talking (install ./setup.sh first if you have not)."
