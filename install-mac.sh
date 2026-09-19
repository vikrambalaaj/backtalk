#!/bin/bash
# macOS one-click install — Homebrew (if needed), Python env, models, Desktop icon.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "install-mac.sh is for macOS only. Use ./setup.sh instead."
  exit 1
fi

echo "== backtalk macOS install =="

# Double-clicked .command files get a bare PATH and Gatekeeper quarantine.
chmod +x *.sh *.command 2>/dev/null || true
for f in *.command *.sh; do
  [ -f "$f" ] && xattr -d com.apple.quarantine "$f" 2>/dev/null || true
done

ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  echo "-- Homebrew not found (needed for espeak-ng). Installing…"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  export PATH="$(brew --prefix)/bin:$PATH"
}

ensure_brew
./setup.sh --yes
./make-desktop-launcher.sh
touch .backtalk-ready

echo ""
echo "== install complete =="
echo "A Desktop shortcut is ready. Use it anytime to start the voice line."
echo ""
echo "One-time macOS permissions:"
echo "  • Microphone — allow when Terminal asks"
echo "  • Input Monitoring for Terminal — System Settings → Privacy & Security"
echo "    (needed for push-to-talk; without it, hands-free still works)"
echo ""
