#!/bin/bash
# Double-click to start the voice line (runs full install on first launch).
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")"
if [ ! -f .backtalk-ready ]; then
  exec "./Install Backtalk.command"
fi
./setup.sh --yes --quick || { echo ""; echo "Setup failed. See messages above."; read -r -p "Press Enter to close…" _; exit 1; }
exec ./run.sh
