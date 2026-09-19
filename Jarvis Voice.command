#!/bin/bash
# Double-click to start Jarvis voice on macOS.
# Keeps this window open — mic + hotkey permissions come from Terminal.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")"
exec ./run.sh
