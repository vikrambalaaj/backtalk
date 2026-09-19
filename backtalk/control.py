# backtalk: browser control panel — pause/resume + model buttons.
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from backtalk import signals

_CONTROL_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>backtalk controls</title>
<style>
  :root { --green:#3ddc84; --amber:#e7c368; --dim:#5a6a72; --ink:#e8f0f2; }
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font:13px "SF Mono",Menlo,monospace; background:#020705; color:var(--ink);
         min-height:100vh; display:flex; align-items:center; justify-content:center; }
  .panel { border:1px solid #12271c; background:#04100a; border-radius:8px;
           padding:22px 24px; min-width:320px; box-shadow:0 0 32px rgba(61,220,132,.08); }
  h1 { font-size:14px; letter-spacing:.35em; color:var(--green); font-weight:normal; }
  #status { margin:14px 0 18px; font-size:11px; letter-spacing:.15em; color:var(--dim); line-height:1.8; }
  #status b { color:var(--amber); font-weight:normal; }
  .row { display:flex; gap:10px; flex-wrap:wrap; }
  button { flex:1 1 45%; min-width:130px; padding:12px 10px; cursor:pointer;
           border:1px solid #1c2f26; border-radius:5px; background:#0a1812;
           color:var(--ink); font:inherit; letter-spacing:.12em;
           transition:border-color .15s, box-shadow .15s; }
  button:hover { border-color:var(--green); box-shadow:0 0 16px rgba(61,220,132,.12); }
  button.primary { border-color:#2a4a38; color:var(--green); }
  #hint { margin-top:16px; font-size:10px; color:var(--dim); letter-spacing:.1em; line-height:1.7; }
</style>
</head>
<body>
<div class="panel">
  <h1>BACKTALK</h1>
  <div id="status">loading…</div>
  <div class="row">
    <button class="primary" data-cmd="pause">PAUSE</button>
    <button class="primary" data-cmd="resume">RESUME</button>
    <button data-cmd="fast">FAST MODEL</button>
    <button data-cmd="deep">DEEP MODEL</button>
    <button data-cmd="toggle_model">TOGGLE MODEL</button>
  </div>
  <div id="hint">Hotkey: Fn+Option toggles model (also Ctrl+Option+M).<br>
  ai-visualizer faces show the same buttons on mouse move (bottom right).</div>
</div>
<script>
async function status() {
  try {
    const r = await fetch('/api/status', {cache:'no-store'});
    const j = await r.json();
    document.getElementById('status').innerHTML =
      'state <b>' + j.state + '</b> · model <b>' + j.model + '</b>' +
      (j.paused ? ' · <b>paused</b>' : '');
  } catch (e) {
    document.getElementById('status').textContent = 'voice line not reachable';
  }
}
document.querySelectorAll('button[data-cmd]').forEach(btn => {
  btn.onclick = async () => {
    await fetch('/api/command', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body: JSON.stringify({cmd: btn.dataset.cmd})
    });
    status();
  };
});
setInterval(status, 800);
status();
</script>
</body>
</html>"""


def start_control_panel(cmd_q, port: int = 8792):
    """Serve the control UI; POST /api/command enqueues pause|resume|fast|deep|toggle_model."""

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            path = self.path.split("?")[0]
            try:
                if path in ("/", "/index.html"):
                    self._send(_CONTROL_HTML.encode(), "text/html; charset=utf-8")
                elif path == "/api/status":
                    body = json.dumps({
                        "state": signals.read_state(),
                        "model": signals.read_model_tier(),
                        "paused": signals.read_state() == "paused",
                    }).encode()
                    self._send(body, "application/json")
                else:
                    self._send(b"not found", "text/plain", 404)
            except Exception:
                pass

        def do_POST(self):
            path = self.path.split("?")[0]
            if path != "/api/command":
                self._send(b"not found", "text/plain", 404)
                return
            try:
                n = int(self.headers.get("Content-Length", 0))
                data = json.loads(self.rfile.read(n) or b"{}")
                cmd = str(data.get("cmd", "")).strip().lower()
                if cmd:
                    cmd_q.put(cmd)
                self._send(b'{"ok":true}', "application/json")
            except Exception as e:
                self._send(json.dumps({"error": str(e)}).encode(),
                           "application/json", 400)

        def _send(self, body, ctype, code=200):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    def serve():
        try:
            srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
            srv.serve_forever()
        except OSError as e:
            print(f"[control] panel not started (port {port}): {e}", flush=True)

    threading.Thread(target=serve, daemon=True).start()
