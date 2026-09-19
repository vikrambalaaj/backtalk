#!/bin/bash
# Open the backtalk control panel (pause / resume / model buttons).
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")"
PORT="$(.venv/bin/python -c "import json; print(json.load(open('backtalk.json')).get('control_port',8792))" 2>/dev/null || echo 8792)"
open "http://127.0.0.1:${PORT}/"
