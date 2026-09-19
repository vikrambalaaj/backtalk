#!/bin/bash
# ONE-CLICK macOS install: deps, models, Desktop shortcut, then start voice.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")"
if [ ! -f .backtalk-ready ]; then
  ./install-mac.sh || { echo ""; echo "Install failed — see messages above."; read -r -p "Press Enter to close…" _; exit 1; }
else
  ./setup.sh --yes --quick 2>/dev/null || ./setup.sh --yes
fi
exec ./run.sh
