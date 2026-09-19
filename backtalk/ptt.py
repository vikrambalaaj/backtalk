# backtalk: talk to your Claude Code agent out loud.
# Copyright (C) 2026 Jared Rhodenizer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Hold-to-talk — a global key listener.

HOLD the key -> mic opens. RELEASE -> mic closes and the utterance is
processed. The button IS the voice-activity detector, which is why this
mode is speaker-safe with no headphones: the mic simply isn't open while
the assistant talks, unless you press the key — and pressing while it
talks interrupts it.

THE KEY-REPEAT TRAP (the bug that kills every naive build): the OS fires
on_press events CONTINUOUSLY while a key is held. Without the held-state
filter below, every repeat reads as a fresh press and keeps cancelling
the reply before it can speak.

AND THE HALF THAT TRAP HIDES: some keyboards send auto-repeat as full
DOWN/UP PAIRS rather than the repeated DOWN-only stream. Filtering the
presses and trusting every release then breaks the OTHER way -- a single
hold is chopped into dozens of ~50ms recordings, each too short to
transcribe, and the whole thing is SILENT. No exception, no log line,
nothing to search for; it simply reads as "the microphone does not work".
Measured in the field on a Logitech MX Mechanical through a Bolt
receiver: one 2.6-second hold produced 186 key events and about fifty
recordings. So a release is never trusted on sight -- see is_held().

macOS needs Input Monitoring permission for the hosting terminal
(System Settings -> Privacy & Security -> Input Monitoring). Windows
works out of the box; some Linux desktops need the user in the `input`
group or an X11 session.
"""
import os
import sys
import threading
import time

from pynput import keyboard


def _hosted_under_cursor() -> bool:
    """Cursor's integrated terminal cannot receive global key events."""
    if os.environ.get("BACKTALK_ALLOW_CURSOR") == "1":
        return False
    if "Cursor" in (os.environ.get("TERM_PROGRAM") or ""):
        return True
    try:
        import subprocess
        pid = os.getpid()
        for _ in range(10):
            r = subprocess.run(["ps", "-p", str(pid), "-o", "ppid=,comm="],
                               capture_output=True, text=True, timeout=2)
            if r.returncode != 0:
                break
            parts = (r.stdout or "").strip().split(None, 1)
            if len(parts) < 2:
                break
            ppid, name = parts[0], parts[1]
            if "Cursor" in name:
                return True
            if "Terminal.app" in name or name == "Terminal":
                return False
            pid = int(ppid)
    except Exception:
        pass
    return False


def _cgevent_tap_ok() -> bool:
    """macOS: can this process install a session key tap?"""
    try:
        from Quartz import (CGEventTapCreate, kCGSessionEventTap,
                            kCGHeadInsertEventTap,
                            kCGEventTapOptionListenOnly,
                            CGEventMaskBit, kCGEventKeyDown)
        tap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
                               kCGEventTapOptionListenOnly,
                               CGEventMaskBit(kCGEventKeyDown),
                               lambda *a: None, None)
        return tap is not None
    except Exception:
        return False


def input_monitoring_ok() -> bool:
    """True when this process can receive global key events (macOS).

    pynput's listener starts even without permission, but never fires —
    which reads as a broken talk key with no error. Cursor's terminal
    is a special case: CGEventTap can succeed while pynput still cannot.

    The CGEventTap probe is authoritative: pynput's startup probe can
    false-negative on Terminal.app even when Input Monitoring is granted
    (listener.running stays False while stderr says 'not trusted')."""
    if sys.platform != "darwin":
        return True
    if _hosted_under_cursor():
        return False
    if _cgevent_tap_ok():
        return True
    import io
    from contextlib import redirect_stderr
    buf = io.StringIO()
    listener = keyboard.Listener(on_press=lambda k: None)
    with redirect_stderr(buf):
        listener.start()
        time.sleep(0.35)
        err = buf.getvalue()
        ok = listener.running and "not trusted" not in err.lower()
        listener.stop()
    return ok


def hosting_terminal_name() -> str:
    """Best-effort name of the app hosting this voice line."""
    if sys.platform != "darwin":
        return "your terminal"
    term = os.environ.get("TERM_PROGRAM")
    if term:
        # System Settings lists "Terminal", not "Apple Terminal".
        if term.lower() in ("apple terminal", "terminal"):
            return "Terminal"
        return term.replace("_", " ")
    try:
        import subprocess
        pid = os.getpid()
        for _ in range(8):
            r = subprocess.run(["ps", "-p", str(pid), "-o", "ppid=,comm="],
                               capture_output=True, text=True, timeout=2)
            if r.returncode != 0:
                break
            parts = (r.stdout or "").strip().split(None, 1)
            if len(parts) < 2:
                break
            ppid, name = parts[0], parts[1]
            if "Terminal.app" in name or name == "Terminal":
                return "Terminal"
            if "Cursor" in name:
                return "Cursor"
            if "iTerm" in name:
                return "iTerm"
            pid = int(ppid)
    except Exception:
        pass
    return "your terminal"


def resolve_key(name: str):
    """'home' / 'f13' / 'right_alt' / any single character -> pynput key."""
    name = (name or "home").strip().lower()
    if len(name) == 1:
        return keyboard.KeyCode.from_char(name)
    # Friendly names -> pynput's names. pynput calls the right option key
    # alt_r, not right_alt; the docs speak human, this map translates.
    # (Field-caught: right_alt silently fell back to home, which Mac
    # laptops cannot press, so the voice looked healthy and never fired.)
    aliases = {
        "right_alt": "alt_r", "left_alt": "alt_l",
        "right_option": "alt_r", "left_option": "alt_l",
        "right_ctrl": "ctrl_r", "left_ctrl": "ctrl_l",
        "right_cmd": "cmd_r", "left_cmd": "cmd_l",
        "right_shift": "shift_r", "left_shift": "shift_l",
    }
    name = aliases.get(name, name)
    try:
        return getattr(keyboard.Key, name)
    except AttributeError:
        print(f"[ptt] unknown key {name!r} — falling back to 'home'",
              flush=True)
        return keyboard.Key.home


class PTTListener:
    # How long a release must stand unchallenged before it is believed.
    # Comfortably longer than any keyboard's auto-repeat period (measured
    # at ~50ms on the hardware that exposed this; Windows' fastest setting
    # is ~30ms) and short enough that letting go still feels instant.
    RELEASE_GRACE = 0.12

    def __init__(self, key="home"):
        self._key = resolve_key(key) if isinstance(key, str) else key
        self._held = False
        self._release_t = None          # a release awaiting confirmation
        self._press_evt = threading.Event()
        self._listener = keyboard.Listener(on_press=self._on_press,
                                           on_release=self._on_release)
        self._listener.daemon = True
        self._listener.start()
        time.sleep(0.15)   # listener.running settles async on macOS

    @property
    def ok(self) -> bool:
        """False when the global key hook never started (PTT will hang)."""
        return bool(self._listener.running)

    def _on_press(self, k):
        if k != self._key:
            return
        # A press cancels any pending release: that release was auto-repeat,
        # not a human letting go.
        self._release_t = None
        if not self._held:                      # filter key-repeat
            self._held = True
            self._press_evt.set()

    def _on_release(self, k):
        if k == self._key:
            # PROVISIONAL. Believed only if no press follows; see _settle().
            self._release_t = time.monotonic()

    def _settle(self):
        """Commit a release that has stood unchallenged for the grace window."""
        r = self._release_t
        if self._held and r is not None and \
                time.monotonic() - r >= self.RELEASE_GRACE:
            self._held = False
            self._release_t = None

    def wait_press(self):
        """Block until the key goes DOWN (one event per physical press)."""
        # Settled on a loop, not once. A release landing after the last
        # is_held() poll leaves _held provisionally True, and a single
        # settle-then-wait would then block forever: the next press is
        # filtered as key-repeat, so nothing ever sets the event again.
        while True:
            self._settle()
            if self._press_evt.wait(timeout=self.RELEASE_GRACE):
                self._press_evt.clear()
                return

    def is_held(self) -> bool:
        self._settle()
        return self._held
