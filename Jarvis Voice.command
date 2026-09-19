#!/bin/bash
# Legacy name — same as Start Voice.command (double-click to run).
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")"
exec "./Start Voice.command"
