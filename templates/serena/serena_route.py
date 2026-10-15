#!/usr/bin/env python3
"""Route C: one Serena server per repo, started on demand.

  serena_route.py up <key...> [--edit] [--timeout SECONDS]
  serena_route.py down [key...]
  serena_route.py status [--notice]
  serena_route.py validate [--map FILE]

Every subcommand also takes --home DIR (default: the folder this kit is installed in,
i.e. ~/.claude) and --map FILE (default: <home>/serena-repos.json).

A repo's read server listens on its port, its edit server on port + 10. Server state
and logs go to <home>/serena-state/, never inside the kit: the installer hashes the kit
to tell an untouched copy from an edited one.

Exit codes: 0 done; 1 a server failed, was refused, or survived a stop, or (validate)
the map has problems, one plain line each on stdout; 2 the map or the command line
stops up/down/status before they start.
"""
import argparse
import base64
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

KIT = os.path.dirname(os.path.abspath(__file__))
IS_WIN = os.name == "nt"
KEY_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
EDIT_OFFSET = 10
PROFILES = ("read", "edit")
DEFAULT_SERENA = ["uvx", "--from", "git+https://github.com/oraios/serena", "serena"]
PROTOCOL = "2025-06-18"

PRUNE = {"node_modules", "venv", "__pycache__", "dist", "build", "target", "vendor", "bin", "obj"}
SOURCE_EXT = {
    ".py", ".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx", ".java", ".kt", ".kts", ".scala",
    ".groovy", ".go", ".rs", ".c", ".h", ".cc", ".cpp", ".cxx", ".hpp", ".hh", ".cs", ".fs",
    ".vb", ".rb", ".php", ".swift", ".m", ".mm", ".lua", ".pl", ".pm", ".r", ".dart", ".ex",
    ".exs", ".erl", ".hs", ".clj", ".elm", ".jl", ".nim", ".zig", ".vue", ".svelte", ".sh",
    ".bash", ".ps1", ".psm1",
}
MAX_CANDIDATES = 3
MAX_VISITED = 5000
POLL = 0.5
EMPTY_SETTLE = 10.0
ERROR_GIVE_UP = 60.0
STILL_ACTIVE = 259


class Fail(Exception):
    pass


_say_lock = threading.Lock()


def say(text, err=False):
    # Bytes, not text: a text-mode stdout on Windows turns every \n into \r\n, and a
    # bash caller reading these lines would keep the \r on all but the last one.
    stream = sys.stderr if err else sys.stdout
    with _say_lock:
        stream.flush()
        stream.buffer.write((text + "\n").encode("utf-8"))
        stream.buffer.flush()


def fwd(path):
    return path.replace("\\", "/")


# --- the repo map ---------------------------------------------------------------

def load_map(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise Fail("there is no repo map at %s. The playbook installer writes it for you: "
                   "run the installer again and choose route C." % fwd(path))
    except (OSError, ValueError) as e:
        raise Fail("cannot read the repo map %s: %s" % (fwd(path), e))
    if not isinstance(data, dict) or not isinstance(data.get("repos"), dict) or not data["repos"]:
        raise Fail('the repo map %s has no "repos" in it. It needs at least one repo, '
                   'with a path and a port.' % fwd(path))
    return data


def map_problems(data, keys=None):
    """One plain line per problem. Paths are checked for `keys` only (None = every repo)."""
    problems = []
    owner = {}
    for key in sorted(data["repos"]):
        repo = data["repos"][key]
        if not KEY_RE.match(key):
            problems.append("repo key '%s': use only lower-case letters, digits and dashes, "
                            "starting with a letter or a digit." % key)
        if not isinstance(repo, dict):
            problems.append("repo '%s': needs a path and a port." % key)
            continue
        port = repo.get("port")
        if isinstance(port, bool) or not isinstance(port, int) or not 1024 <= port <= 65535 - EDIT_OFFSET:
            problems.append("repo '%s': port must be a whole number from 1024 to %d."
                            % (key, 65535 - EDIT_OFFSET))
        else:
            for p, role in ((port, "read"), (port + EDIT_OFFSET, "edit")):
                if p in owner:
                    problems.append("repo '%s' and repo '%s' both use port %d. Each repo uses its "
                                    "port for reading and its port + %d for editing, so give one "
                                    "of them another port." % (owner[p], key, p, EDIT_OFFSET))
                else:
                    owner[p] = key
        if keys is not None and key not in keys:
            continue
        path = repo.get("path")
        if not isinstance(path, str) or not path.strip():
            problems.append("repo '%s': has no path." % key)
        elif "<" in path:
            problems.append("repo '%s': the path is still the placeholder %s. Put the repo's "
                            "real folder there." % (key, path))
        elif not os.path.isdir(path):
            problems.append("repo '%s': %s is not a folder on this machine. Correct the path, "
                            "or remove the repo from the map." % (key, path))
    cmd = data.get("serena_cmd")
    if cmd is not None and (not isinstance(cmd, list) or not cmd
                            or not all(isinstance(c, str) and c for c in cmd)):
        problems.append('"serena_cmd" must be a list of words, like ["serena"], or be left out.')
    return problems


def serena_argv(data, port, profile, path):
    base = data.get("serena_cmd")
    if not base:
        if shutil.which("serena"):
            base = ["serena"]
        elif shutil.which("uvx"):
            base = DEFAULT_SERENA
        else:
            raise Fail("Serena is not installed: neither `serena` nor `uvx` is on PATH. "
                       "Install uv (https://docs.astral.sh/uv/), then run this again")
    exe = shutil.which(base[0]) or base[0]
    return [exe] + list(base[1:]) + [
        "start-mcp-server", "--transport", "streamable-http", "--host", "127.0.0.1",
        "--port", str(port), "--context", os.path.join(KIT, profile + ".context.yml"),
        "--project", path, "--open-web-dashboard", "False",
    ]


# --- state ----------------------------------------------------------------------

def state_dir(home):
    return os.path.join(home, "serena-state")


def state_file(home, key, profile):
    return os.path.join(state_dir(home), "%s-%s.json" % (key, profile))


def log_file(home, key, profile):
    return os.path.join(state_dir(home), "logs", "%s-%s.log" % (key, profile))


def write_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)


def read_state(path):
    try:
        with open(path, encoding="utf-8") as f:
            st = json.load(f)
        st["pid"], st["port"] = int(st["pid"]), int(st["port"])
        if not isinstance(st["key"], str) or st["profile"] not in PROFILES:
            return None
        return st
    except (OSError, ValueError, KeyError, TypeError):
        return None


def all_states(home):
    d = state_dir(home)
    try:
        names = sorted(n for n in os.listdir(d) if n.endswith(".json"))
    except OSError:
        return [], []
    good, bad = [], []
    for n in names:
        st = read_state(os.path.join(d, n))
        if st is None:
            bad.append(os.path.join(d, n))
        else:
            st["_file"] = os.path.join(d, n)
            good.append(st)
    return good, bad


# --- processes ------------------------------------------------------------------

def pid_alive(pid):
    pid = int(pid)
    if pid <= 0:
        return False
    if IS_WIN:
        # Never os.kill(pid, 0) here: on Windows it calls TerminateProcess and kills it.
        import ctypes
        from ctypes import wintypes
        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        k32.OpenProcess.restype = wintypes.HANDLE
        k32.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD)
        k32.GetExitCodeProcess.argtypes = (wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD))
        k32.CloseHandle.argtypes = (wintypes.HANDLE,)
        handle = k32.OpenProcess(0x1000, False, pid)
        if not handle:
            return ctypes.get_last_error() == 5
        code = wintypes.DWORD()
        try:
            ok = k32.GetExitCodeProcess(handle, ctypes.byref(code))
        finally:
            k32.CloseHandle(handle)
        return bool(ok) and code.value == STILL_ACTIVE
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def port_taken(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.5):
            return True
    except OSError:
        return False


def spawn(argv, log_path, cwd):
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    with open(log_path, "ab") as log:
        if sys.platform != "win32":
            return subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                    cwd=cwd, close_fds=True, start_new_session=True)
        # No console window for the server or the language servers it starts, its own
        # process group, and out of the caller's job object when the job allows it, so
        # the server outlives the shell that ran serena-up.
        flags = subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP
        try:
            return subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                    cwd=cwd, close_fds=True,
                                    creationflags=flags | subprocess.CREATE_BREAKAWAY_FROM_JOB)
        except OSError:
            return subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                    cwd=cwd, close_fds=True, creationflags=flags)


def tree_kill(pid, proc=None):
    pid = int(pid)
    if sys.platform == "win32":
        taskkill = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "taskkill.exe")
        subprocess.run([taskkill, "/T", "/F", "/PID", str(pid)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        for sig in (signal.SIGTERM, signal.SIGKILL):
            try:
                os.killpg(pid, sig)
            except ProcessLookupError:
                break
            except PermissionError:
                try:
                    os.kill(pid, sig)
                except OSError:
                    break
            end = time.monotonic() + 5
            while time.monotonic() < end:
                if proc is not None and proc.poll() is not None:
                    break
                if proc is None and not pid_alive(pid):
                    break
                time.sleep(0.1)
            else:
                continue
            break
    if proc is not None:
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass


def list_servers():
    """[(pid, command line)] of every process whose command line holds start-mcp-server."""
    if IS_WIN:
        script = ("$ErrorActionPreference = 'SilentlyContinue'; "
                  "[Console]::OutputEncoding = [Text.Encoding]::UTF8; "
                  "Get-CimInstance Win32_Process -Filter \"CommandLine LIKE '%start-mcp-server%'\" | "
                  "ForEach-Object { [string]$_.ProcessId + [char]9 + [string]$_.CommandLine }")
        exe = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"),
                           "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
        if not os.path.isfile(exe):
            exe = shutil.which("powershell.exe") or shutil.which("pwsh") or "powershell.exe"
        argv = [exe, "-NoProfile", "-NonInteractive", "-EncodedCommand",
                base64.b64encode(script.encode("utf-16-le")).decode("ascii")]
        sep = "\t"
    else:
        argv = ["ps", "-eo", "pid=,args="]
        sep = None
    try:
        res = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise Fail("cannot list running processes to check what is left (%s)" % e)
    if res.returncode != 0:
        raise Fail("cannot list running processes to check what is left (%s exited %d)"
                   % (os.path.basename(argv[0]), res.returncode))
    out = []
    for line in res.stdout.decode("utf-8", "replace").splitlines():
        parts = line.strip().split(sep, 1)
        if len(parts) == 2 and parts[0].isdigit() and "start-mcp-server" in parts[1]:
            if int(parts[0]) != os.getpid():
                out.append((int(parts[0]), parts[1].strip()))
    return out


def on_port(cmdline, port):
    return re.search(r'--port(?:=|\s+)"?%d"?(?:\s|$)' % port, cmdline) is not None


def stop(entries, ports):
    """Kill each entry's process tree, then every process a listing still shows on one of
    `ports`. Removes an entry's state file once nothing is left on its port.
    Returns the survivors as (pid, command line)."""
    for e in entries:
        tree_kill(e["pid"], e.get("_proc"))
    survivors = []
    for attempt in range(3):
        survivors = [s for s in list_servers() if any(on_port(s[1], p) for p in ports)]
        if not survivors:
            break
        for pid, _ in survivors:
            tree_kill(pid)
        time.sleep(1 + attempt)
    gone = {p for p in ports if not any(on_port(s[1], p) for s in survivors)}
    for e in entries:
        if int(e["port"]) in gone and e.get("_file"):
            try:
                os.remove(e["_file"])
            except FileNotFoundError:
                pass
    return survivors


# --- MCP over streamable HTTP ---------------------------------------------------

class McpError(Exception):
    pass


def _messages(ctype, raw):
    text = raw.decode("utf-8", "replace")
    if "text/event-stream" in ctype:
        data = []
        for line in text.splitlines() + [""]:
            if line.startswith("data:"):
                data.append(line[5:].lstrip(" "))
            elif not line.strip() and data:
                yield json.loads("\n".join(data))
                data = []
        return
    if text.strip():
        msg = json.loads(text)
        for m in (msg if isinstance(msg, list) else [msg]):
            yield m


class Mcp:
    def __init__(self, port):
        self.url = "http://127.0.0.1:%d/mcp" % port
        self.session = None
        self.version = PROTOCOL
        self.n = 0
        # No proxy: an HTTP_PROXY in the environment would otherwise take 127.0.0.1 too.
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def _post(self, msg, timeout):
        headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
            headers["MCP-Protocol-Version"] = self.version
        req = urllib.request.Request(self.url, data=json.dumps(msg).encode("utf-8"),
                                     headers=headers, method="POST")
        with self.opener.open(req, timeout=max(1.0, timeout)) as resp:
            sid = resp.headers.get("Mcp-Session-Id")
            if sid:
                self.session = sid
            return resp.headers.get("Content-Type", ""), resp.read()

    def request(self, method, params, timeout):
        self.n += 1
        ctype, raw = self._post({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params}, timeout)
        for msg in _messages(ctype, raw):
            if isinstance(msg, dict) and msg.get("id") == self.n:
                if "error" in msg:
                    err = msg["error"]
                    raise McpError(err.get("message", str(err)) if isinstance(err, dict) else str(err))
                return msg.get("result") or {}
        raise McpError("no reply to " + method)

    def initialize(self, timeout):
        result = self.request("initialize", {"protocolVersion": PROTOCOL, "capabilities": {},
                                             "clientInfo": {"name": "serena-route", "version": "1"}}, timeout)
        self.version = result.get("protocolVersion") or PROTOCOL
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"}, timeout)

    def tool_names(self, timeout):
        names, cursor = [], None
        while True:
            result = self.request("tools/list", {"cursor": cursor} if cursor else {}, timeout)
            names += [t.get("name") for t in result.get("tools", []) if isinstance(t, dict)]
            cursor = result.get("nextCursor")
            if not cursor:
                return names

    def call(self, name, arguments, timeout):
        """-> (is_error, text)"""
        result = self.request("tools/call", {"name": name, "arguments": arguments}, timeout)
        parts = [c.get("text", "") for c in result.get("content", []) if isinstance(c, dict)]
        text = "\n".join(parts)
        if not text and result.get("structuredContent") is not None:
            text = json.dumps(result["structuredContent"])
        return bool(result.get("isError")) or text.lstrip().startswith("Error"), text

    def close(self):
        if not self.session:
            return
        try:
            req = urllib.request.Request(self.url, method="DELETE",
                                         headers={"Mcp-Session-Id": self.session})
            self.opener.open(req, timeout=5).close()
        except (OSError, urllib.error.URLError, ValueError):
            pass


NET_ERRORS = (OSError, urllib.error.URLError, McpError, ValueError)


def empty(text):
    t = text.strip()
    if not t:
        return True
    try:
        return not json.loads(t)
    except ValueError:
        return False


# --- up -------------------------------------------------------------------------

def candidates(root):
    """Up to MAX_CANDIDATES non-empty source files, in sorted walk order, as posix paths."""
    found, visited = [], 0
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if not x.startswith(".") and x not in PRUNE)
        for name in sorted(files):
            visited += 1
            if visited > MAX_VISITED:
                return found
            if os.path.splitext(name)[1].lower() not in SOURCE_EXT:
                continue
            full = os.path.join(d, name)
            try:
                if os.path.getsize(full) == 0:
                    continue
            except OSError:
                continue
            found.append(os.path.relpath(full, root).replace(os.sep, "/"))
            if len(found) == MAX_CANDIDATES:
                return found
    return found


def connect(port, deadline, proc, pid):
    last = "nothing answered"
    while True:
        if proc is not None and proc.poll() is not None:
            raise Fail("the server stopped during start-up (exit code %s)" % proc.returncode)
        if proc is None and not pid_alive(pid):
            raise Fail("the server stopped")
        client = Mcp(port)
        try:
            client.initialize(min(30.0, deadline - time.monotonic()))
            return client
        except NET_ERRORS as e:
            last = str(e)
        if time.monotonic() >= deadline:
            raise Fail("no answer on port %d in time (%s)" % (port, last))
        time.sleep(POLL)


def overview(client, rel, deadline):
    """True once the file shows symbols, False once it has stayed empty; Fail on errors."""
    first_empty = first_error = None
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise Fail("warm-up ran out of time on %s" % rel)
        try:
            is_error, text = client.call("get_symbols_overview", {"relative_path": rel}, min(60.0, remaining))
        except NET_ERRORS as e:
            is_error, text = True, str(e)
        now = time.monotonic()
        if is_error:
            first_empty = None
            first_error = first_error or now
            if now - first_error >= ERROR_GIVE_UP:
                raise Fail("warm-up: get_symbols_overview on %s keeps failing: %s" % (rel, text.strip()[:300]))
        elif not empty(text):
            return True
        else:
            first_error = None
            first_empty = first_empty or now
            if now - first_empty >= EMPTY_SETTLE:
                return False
        time.sleep(POLL)


def warm_up(client, key, root, deadline):
    for rel in candidates(root):
        if overview(client, rel, deadline):
            return "warm-up ok: %s %s" % (key, rel)
    first_error = None
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise Fail("warm-up ran out of time on list_dir")
        try:
            is_error, text = client.call("list_dir", {"relative_path": ".", "recursive": False}, min(60.0, remaining))
        except NET_ERRORS as e:
            is_error, text = True, str(e)
        if not is_error:
            return "symbols not verified: %s — no source file with symbols found" % key
        first_error = first_error or time.monotonic()
        if time.monotonic() - first_error >= ERROR_GIVE_UP:
            raise Fail("warm-up: list_dir keeps failing: %s" % text.strip()[:300])
        time.sleep(POLL)


def bring_up(home, data, key, profile, timeout):
    deadline = time.monotonic() + timeout
    repo = data["repos"][key]
    path = repo["path"]
    port = repo["port"] + (EDIT_OFFSET if profile == "edit" else 0)
    tag = "%s (%s, port %d)" % (key, profile, port)
    sfile, lfile = state_file(home, key, profile), log_file(home, key, profile)
    st = read_state(sfile)
    proc = None
    if st is not None and int(st["port"]) == port and pid_alive(st["pid"]):
        pid = int(st["pid"])
        say("already running: %s, pid %d" % (tag, pid))
    else:
        if port_taken(port):
            say("failed: %s — port %d is already taken by a program serena-up did not start. Stop "
                "that program, or give '%s' another port in the repo map." % (tag, port, key), err=True)
            return False
        try:
            argv = serena_argv(data, port, profile, path)
        except Fail as e:
            say("failed: %s — %s." % (tag, e), err=True)
            return False
        proc = spawn(argv, lfile, path)
        pid = proc.pid
        write_json(sfile, {"key": key, "profile": profile, "port": port, "pid": pid, "path": path,
                           "log": fwd(lfile), "started": time.strftime("%Y-%m-%dT%H:%M:%S")})
        say("starting: %s — log %s" % (tag, fwd(lfile)))
    entry = {"pid": pid, "port": port, "_file": sfile, "_proc": proc}
    client = None
    try:
        client = connect(port, deadline, proc, pid)
        allowed = set(load_profiles()[profile])
        names = client.tool_names(max(1.0, deadline - time.monotonic()))
        extra = sorted(set(names) - allowed)
        if extra:
            client.close()
            client = None
            left = stop([entry], [port])
            say("refused: %s — this Serena offers tools the %s profile does not allow: %s. The server "
                "was stopped%s. Re-run the playbook installer to get profiles that match this Serena."
                % (tag, profile, ", ".join(extra), "" if not left else ", but it left a process behind"),
                err=True)
            return False
        missing = sorted(allowed - set(names))
        if missing:
            say("note: %s does not offer %s; an agent that needs them will stop and say so."
                % (tag, ", ".join(missing)))
        say(warm_up(client, key, path, deadline))
    except (Fail,) + NET_ERRORS as e:
        if client is not None:
            client.close()
        stop([entry], [port])
        say("failed: %s — %s. The server was stopped. Its log: %s" % (tag, e, fwd(lfile)), err=True)
        return False
    client.close()
    say("up: %s — http://127.0.0.1:%d/mcp" % (tag, port))
    return True


def load_profiles():
    with open(os.path.join(KIT, "profiles.json"), encoding="utf-8") as f:
        return json.load(f)


def cmd_up(args):
    data = load_map(args.map)
    known = sorted(data["repos"])
    unknown = [k for k in args.keys if k not in data["repos"]]
    if unknown:
        raise Fail("no repo called %s in %s. The map holds: %s."
                   % (", ".join("'%s'" % k for k in unknown), fwd(args.map), ", ".join(known)))
    problems = map_problems(data, set(args.keys))
    if problems:
        raise Fail("the repo map %s needs fixing first:\n  %s" % (fwd(args.map), "\n  ".join(problems)))
    profile = "edit" if args.edit else "read"
    keys = list(dict.fromkeys(args.keys))
    results = {}

    def run(key):
        try:
            results[key] = bring_up(args.home, data, key, profile, args.timeout)
        except Exception as e:  # one repo's surprise must not leave the others unreported
            say("failed: %s (%s) — %s" % (key, profile, e), err=True)
            results[key] = False

    threads = [threading.Thread(target=run, args=(k,)) for k in keys]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    return 0 if all(results.get(k) for k in keys) else 1


# --- down / status / validate ---------------------------------------------------

def cmd_down(args):
    states, broken = all_states(args.home)
    entries = [s for s in states if not args.keys or s["key"] in args.keys]
    ports = {int(s["port"]) for s in entries}
    try:
        data = load_map(args.map)
    except Fail:
        data = None
    if data is not None:
        for key, repo in data["repos"].items():
            if (not args.keys or key in args.keys) and isinstance(repo, dict) \
                    and isinstance(repo.get("port"), int) and not isinstance(repo.get("port"), bool):
                ports |= {repo["port"], repo["port"] + EDIT_OFFSET}
    survivors = stop(entries, sorted(ports))
    for e in entries:
        if not os.path.exists(e["_file"]):
            say("stopped: %s (%s, port %s)" % (e["key"], e["profile"], e["port"]))
    for path in broken:
        say("note: %s is not a state file this kit can read; it was left alone." % fwd(path))
    if survivors:
        for pid, cmd in survivors:
            say("still running after serena-down: pid %d: %s" % (pid, cmd), err=True)
        return 1
    if not entries:
        say("nothing to stop")
    return 0


def down_command(home):
    extra = "" if os.path.normcase(os.path.abspath(home)) == os.path.normcase(default_home()) \
        else ' --home "%s"' % fwd(home)
    kit = fwd(KIT)
    return ('bash "%s/serena-down.sh"%s   (PowerShell: powershell -NoProfile -ExecutionPolicy '
            'Bypass -File "%s/serena-down.ps1"%s)' % (kit, extra, kit, extra))


def cmd_status(args):
    states, broken = all_states(args.home)
    if not states and not broken:
        if not args.notice:
            say("no Serena servers recorded")
        return 0
    say("Serena servers left from an earlier session:" if args.notice else "Serena servers recorded:")
    for s in states:
        if pid_alive(s["pid"]):
            say("  running: %s (%s, port %s, pid %s)" % (s["key"], s["profile"], s["port"], s["pid"]))
        else:
            say("  stale:   %s (%s, port %s) — not running; only its state file is left"
                % (s["key"], s["profile"], s["port"]))
    for path in broken:
        say("  unreadable state file: %s" % fwd(path))
    say("Stop them with: " + down_command(args.home))
    return 0


def cmd_validate(args):
    data = load_map(args.map)
    problems = map_problems(data)
    for p in problems:
        say(p)
    if problems:
        return 1
    say("ok: %s holds %d repo(s)" % (fwd(args.map), len(data["repos"])))
    return 0


def default_home():
    return os.path.dirname(KIT)


def main(argv=None):
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--home", help="the Claude home holding serena-state/ (default: %(default)s)",
                        default=default_home())
    common.add_argument("--map", help="the repo map (default: <home>/serena-repos.json)")
    ap = argparse.ArgumentParser(prog="serena_route.py", description="Route C Serena servers, one per repo.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    up = sub.add_parser("up", parents=[common], help="start servers and wait until they answer")
    up.add_argument("keys", nargs="+", metavar="key")
    up.add_argument("--edit", action="store_true", help="the edit profile, on port + %d" % EDIT_OFFSET)
    up.add_argument("--timeout", type=float, default=300.0, help="seconds per server (default: %(default)s)")
    down = sub.add_parser("down", parents=[common], help="stop servers and check none is left")
    down.add_argument("keys", nargs="*", metavar="key")
    status = sub.add_parser("status", parents=[common], help="list recorded servers")
    status.add_argument("--notice", action="store_true", help="print nothing when nothing is recorded")
    sub.add_parser("validate", parents=[common], help="check the repo map")
    args = ap.parse_args(argv)
    args.home = os.path.abspath(args.home)
    if args.map is None:
        args.map = os.path.join(args.home, "serena-repos.json")
    if args.cmd != "validate" and os.path.normcase(args.home) == os.path.normcase(default_home()) \
            and os.path.isfile(os.path.join(KIT, "..", "..", "install-lib.py")):
        say("serena_route.py: this is the playbook's source copy; pass --home <your .claude folder>.", err=True)
        return 2
    handler = {"up": cmd_up, "down": cmd_down, "status": cmd_status, "validate": cmd_validate}[args.cmd]
    try:
        return handler(args)
    except Fail as e:
        say(str(e), err=(args.cmd != "validate"))
        return 2 if args.cmd != "validate" else 1


if __name__ == "__main__":
    sys.exit(main())
