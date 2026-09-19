# backtalk: global hotkeys (model toggle, etc.) via pynput.
import queue
import threading

from pynput import keyboard

# macOS: fn is not always a standalone key event; register several chords.
_DEFAULT_TOGGLE_MODEL = ("<fn>+<alt>", "<alt>+<fn>", "<ctrl>+<alt>+m")
_DEFAULT_TOGGLE_PAUSE = ("<fn>+<ctrl>", "<ctrl>+<fn>")


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

    def _register(self, hotkeys: dict, cmd: str, spec: str,
                  fallbacks: tuple[str, ...] = ()):
        chords = _to_pynput(spec)
        if not chords and fallbacks:
            chords = list(fallbacks)
        for chord in chords:
            hotkeys[chord] = lambda c=cmd: self._out_q.put(c)

    def start(self):
        hotkeys: dict[str, callable] = {}
        b = self._bindings
        if b.get("toggle_model", "fn+option"):
            self._register(hotkeys, "toggle_model",
                           b.get("toggle_model", "fn+option"),
                           _DEFAULT_TOGGLE_MODEL)
        if b.get("toggle_pause", "fn+control"):
            self._register(hotkeys, "toggle_pause",
                           b.get("toggle_pause", "fn+control"),
                           _DEFAULT_TOGGLE_PAUSE)
        if b.get("pause"):
            self._register(hotkeys, "pause", b["pause"])
        if b.get("resume"):
            self._register(hotkeys, "resume", b["resume"])

        def run():
            try:
                with keyboard.GlobalHotKeys(hotkeys):
                    self._stop.wait()
            except Exception as e:
                print(f"[hotkeys] listener failed: {e}", flush=True)

        threading.Thread(target=run, daemon=True).start()

    def stop(self):
        self._stop.set()
