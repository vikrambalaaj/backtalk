# backtalk: global hotkeys (model toggle, etc.) via pynput.
import queue
import threading

from pynput import keyboard

# macOS: fn is not always a standalone key event; register several chords.
_DEFAULT_TOGGLE = ("<fn>+<alt>", "<alt>+<fn>", "<ctrl>+<alt>+m")


def _to_pynput(spec: str) -> list[str]:
    """'fn+option' -> pynput GlobalHotKeys strings."""
    if not spec:
        return []
    parts = [p.strip() for p in spec.lower().replace("-", "+").split("+") if p.strip()]
    mapping = {
        "fn": "<fn>",
        "option": "<alt>",
        "alt": "<alt>",
        "ctrl": "<ctrl>",
        "control": "<ctrl>",
        "cmd": "<cmd>",
        "command": "<cmd>",
        "shift": "<shift>",
    }
    keys = []
    for p in parts:
        if p in mapping:
            keys.append(mapping[p])
        elif len(p) == 1:
            keys.append(p)
        elif p.startswith("f") and p[1:].isdigit():
            keys.append(f"<{p}>")
        else:
            keys.append(f"<{p}>")
    if not keys:
        return []
    return ["+".join(keys)]


class HotkeyService:
    """Background global hotkeys -> command queue (pause, toggle_model, …)."""

    def __init__(self, out_q: queue.Queue, bindings: dict[str, str] | None = None):
        self._out_q = out_q
        self._bindings = bindings or {}
        self._listener = None
        self._stop = threading.Event()

    def start(self):
        hotkeys: dict[str, callable] = {}
        toggle = self._bindings.get("toggle_model", "fn+option")
        for spec in _to_pynput(toggle):
            hotkeys[spec] = lambda: self._out_q.put("toggle_model")
        if not hotkeys:
            for spec in _DEFAULT_TOGGLE:
                hotkeys[spec] = lambda: self._out_q.put("toggle_model")
        pause = self._bindings.get("pause", "")
        for spec in _to_pynput(pause):
            hotkeys[spec] = lambda: self._out_q.put("pause")
        resume = self._bindings.get("resume", "")
        for spec in _to_pynput(resume):
            hotkeys[spec] = lambda: self._out_q.put("resume")

        def run():
            try:
                with keyboard.GlobalHotKeys(hotkeys):
                    self._stop.wait()
            except Exception as e:
                print(f"[hotkeys] listener failed: {e}", flush=True)

        threading.Thread(target=run, daemon=True).start()

    def stop(self):
        self._stop.set()
