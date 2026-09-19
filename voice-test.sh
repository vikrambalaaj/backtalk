#!/bin/bash
# Quick voice-stack diagnostic for macOS. Run from any terminal.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
PY=".venv/bin/python3"
echo "=== Voice stack diagnostic ==="
echo "Host: TERM_PROGRAM=${TERM_PROGRAM:-unset} ppid=$(ps -p $PPID -o comm= 2>/dev/null || echo '?')"
echo
echo "--- Processes ---"
pgrep -fl 'backtalk[.]main' || echo "backtalk: NOT RUNNING"
lsof -i :8790 2>/dev/null | head -3 || echo "ai-visualizer (8790): NOT LISTENING"
lsof -i :8791 2>/dev/null | head -3 || echo "backtalk lock (8791): free"
echo
echo "--- Visualizer ---"
curl -s -m 3 http://127.0.0.1:8790/state 2>/dev/null | head -c 200 || echo "curl failed"
echo
echo
echo "--- Audio output (Kokoro) ---"
$PY -c "
from backtalk.mouth import Mouth
m = Mouth()
m.say('Voice test. If you hear this sentence, audio output works.')
m.wait_done(timeout=90)
print('TTS: OK')
"
echo
echo "--- Microphone capture (2s) ---"
$PY -c "
import numpy as np, sounddevice as sd
a = sd.rec(int(16000*2), samplerate=16000, channels=1, dtype='float32')
sd.wait()
peak = float(np.max(np.abs(a)))
print(f'peak={peak:.4f}' + ('  MIC: OK' if peak > 0.001 else '  MIC: SILENT (check permission/device)'))
"
echo
echo "--- Input Monitoring (push-to-talk) ---"
$PY -c "
from backtalk.ptt import input_monitoring_ok, hosting_terminal_name, _cgevent_tap_ok
host = hosting_terminal_name()
ok = input_monitoring_ok()
tap = _cgevent_tap_ok()
print(f'host={host!r}  input_monitoring={ok}  cgevent_tap={tap}')
if not ok:
    if host == 'Cursor':
        print('PTT: BLOCKED in Cursor — double-click Start Voice.command (Terminal.app).')
    else:
        print('PTT: BLOCKED — enable Input Monitoring for', host, 'in System Settings → Privacy & Security → Input Monitoring, then restart the terminal.')
        print('Fallback: backtalk auto-switches to hands-free on launch when PTT is blocked.')
    raise SystemExit(1)
print('PTT: OK (hold your talk key in the voice window)')
"
echo
echo "=== All checks passed ==="
echo "Start voice: double-click 'Start Voice.command' (NOT from Cursor terminal)."
