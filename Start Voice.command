#!/bin/bash
# Double-click to install (first time) and start the voice line.
# Opens in Terminal.app — mic + push-to-talk permissions come from the host app.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")"
./setup.sh --yes --quick || { echo ""; echo "Setup failed. See messages above."; read -r -p "Press Enter to close…" _; exit 1; }
exec ./run.sh
