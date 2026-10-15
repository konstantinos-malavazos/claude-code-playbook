"""A stand-in for `serena start-mcp-server`, so the RC8 installer cases run offline.

It takes the same arguments serena_route.py passes to Serena. Started without --serve
it re-launches itself as a child that does the serving and waits on it, the way uvx
launches the real server: a stop that kills only the recorded PID leaves the child
running, and only a process listing finds it.

It lists every tool of profiles.json's all_tools that the context file does not
exclude, which is what Serena does with a context's excluded_tools.

  FAKE_SERENA_LOG          append one line per start and per tools/call
  FAKE_SERENA_EXTRA_TOOLS  comma-separated tool names listed beyond the profile
  FAKE_SERENA_JSON         reply with application/json instead of an event stream
"""
import argparse
import json
import os
import subprocess
import sys
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LIFETIME = 600


def log(line):
    path = os.environ.get("FAKE_SERENA_LOG")
    if path:
        with open(path, "ab") as f:
            f.write((line + "\n").encode("utf-8"))


def parse(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--marker", default="")
    ap.add_argument("--serve", action="store_true")
    ap.add_argument("command", nargs="?")
    ap.add_argument("--transport")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--context", required=True)
    ap.add_argument("--project", required=True)
    return ap.parse_known_args(argv)[0]


def excluded_tools(context_file):
    out, inside = [], False
    with open(context_file, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\r\n")
            if line.startswith("excluded_tools:"):
                inside = True
                continue
            if inside:
                if line.startswith("  - "):
                    out.append(line[4:].strip())
                elif line.strip():
                    inside = False
    return out


def tool_list(context_file):
    with open(os.path.join(os.path.dirname(context_file), "profiles.json"), encoding="utf-8") as f:
        every = json.load(f)["all_tools"]
    gone = set(excluded_tools(context_file))
    extra = [t for t in os.environ.get("FAKE_SERENA_EXTRA_TOOLS", "").split(",") if t]
    return [t for t in every if t not in gone] + extra


def serve(args):
    tools = tool_list(args.context)
    session = uuid.uuid4().hex
    as_json = bool(os.environ.get("FAKE_SERENA_JSON"))

    def call(params):
        name, a = params.get("name"), params.get("arguments") or {}
        log("%d call %s %s" % (args.port, name, json.dumps(a, sort_keys=True)))
        if name not in tools:
            return {"content": [{"type": "text", "text": "unknown tool " + str(name)}], "isError": True}
        target = os.path.join(args.project, a.get("relative_path", "."))
        if name == "get_symbols_overview":
            with open(target, encoding="utf-8") as f:
                text = '{"Function": ["stub"]}' if f.read().strip() else "{}"
        elif name == "list_dir":
            text = json.dumps({"files": sorted(os.listdir(target))})
        else:
            text = "{}"
        return {"content": [{"type": "text", "text": text}], "isError": False}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            pass

        def reply(self, code, body=b"", ctype=None, sid=None):
            self.send_response(code)
            if ctype:
                self.send_header("Content-Type", ctype)
            if sid:
                self.send_header("Mcp-Session-Id", sid)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_DELETE(self):
            self.reply(200)

        def do_POST(self):
            if self.path != "/mcp":
                return self.reply(404)
            msg = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
            if "id" not in msg:
                return self.reply(202)
            method, sid = msg.get("method"), None
            if method == "initialize":
                sid = session
                result = {"protocolVersion": msg["params"].get("protocolVersion"),
                          "capabilities": {"tools": {}},
                          "serverInfo": {"name": "fake-serena", "version": "0"}}
            elif self.headers.get("Mcp-Session-Id") != session:
                return self.reply(400, b"missing or unknown Mcp-Session-Id", "text/plain")
            elif method == "tools/list":
                result = {"tools": [{"name": t, "inputSchema": {"type": "object"}} for t in tools]}
            elif method == "tools/call":
                result = call(msg.get("params") or {})
            else:
                result = None
            out = {"jsonrpc": "2.0", "id": msg["id"]}
            if result is None:
                out["error"] = {"code": -32601, "message": "no method " + str(method)}
            else:
                out["result"] = result
            data = json.dumps(out)
            if as_json:
                self.reply(200, data.encode("utf-8"), "application/json", sid)
            else:
                self.reply(200, ("event: message\ndata: %s\n\n" % data).encode("utf-8"), "text/event-stream", sid)

    threading.Timer(LIFETIME, os._exit, args=(0,)).start()
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


def main():
    args = parse(sys.argv[1:])
    if args.serve:
        serve(args)
        return 0
    log("%d serve %s" % (args.port, os.path.basename(args.context)))
    child = subprocess.Popen([sys.executable, os.path.abspath(__file__), "--serve"] + sys.argv[1:])
    return child.wait()


if __name__ == "__main__":
    sys.exit(main())
