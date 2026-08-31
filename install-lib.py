#!/usr/bin/env python3
"""
install-lib.py — the correctness half of the playbook installer.

`install.sh` owns the UX (stage progress, prompts, confirmation gates). This file
owns everything where being wrong is silent: discovering what is installable,
hashing what we wrote, merging shared JSON without clobbering, and proving a hook
is actually wired.

One invariant runs through the whole file, and it is the reason merge, upgrade and
remove all behave the way they do:

    THE INSTALLER NEVER OVERWRITES OR DELETES SOMETHING THE USER CHANGED.

Every subcommand prints JSON to stdout. Human-readable reporting is install.sh's job.
"""

import hashlib
import json
import os
import re
import sys

# Windows Python opens stdout in TEXT mode, so every "\n" written below leaves the
# process as "\r\n". install.sh reads the TSV this file prints with `read -r`, which
# splits on "\n" and leaves the "\r" on the last field — the destination path. Under
# Git Bash that installs every unit under a name ending in CR: the harness never loads
# it, the placeholder fill and the Serena rewrite cannot open it, and the manifest
# hashes a path that no longer exists — which leaves update, list and remove all
# convinced nothing was ever installed. Force LF and the whole class goes away.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(newline="\n")

# ---------------------------------------------------------------------------
# What is never installed into ~/.claude/
# ---------------------------------------------------------------------------
# These are templates that /adapt-to-stack generates PER LAYER, PER REPO into that
# repo's own .claude/. Their frontmatter carries a <layer> placeholder in `name:`,
# which registers an undispatchable agent if it ever lands in ~/.claude/agents/.
#
# Written with "/" separators and compared through _unit_rel, which normalises the
# separator first. Under Git Bash this file runs on a WINDOWS python, where
# os.path.relpath returns "skills\\engineering-standards" — a raw comparison misses
# every entry here, all three become ordinary units, and skill:adapt-to-stack picks
# up a skill:engineering-standards edge that drags one of them into `recommended`.
# The install then fails its own placeholder gate on a unit nobody chose. (#99)
NEVER_INSTALL = {
    "agents/layer-specialist.md",
    "agents/slice-layer-specialist.md",
    "skills/engineering-standards",
}

# README.md is documentation for the template set, not an installable unit. It also
# contains illustrative `model: <strong-model-id>` lines that would trip the
# placeholder gate if copied.
SKIP_NAMES = {"README.md"}

# test-hooks.sh is run from the clone against the templates. It is not a hook and is
# never wired into settings.json — see docs/shared/03-setup.md step 7.
SKIP_HOOKS = {"test-hooks.sh"}

# The frontmatter keys the harness resolves. A placeholder left in any of these fails
# silently or on first dispatch; anywhere else in the file it is prose and stays.
BLOCKING_KEYS = ("name", "model", "tools")
BLOCKING_RE = re.compile(r"^(name|model|tools):.*?(<[a-z][a-z-]*>)", re.MULTILINE)
TOKEN_RE = re.compile(r"<[a-z][a-z-]*>")


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def out(obj):
    json.dump(obj, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


def read(path):
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_tree(path):
    """Hash a directory as the sorted sequence of (relpath, content-hash).

    A skill is one unit — SKILL.md and template.sh together — so it gets one hash.
    Renaming or dropping a file inside it changes the hash, which is what makes the
    'has the user edited this?' check work for multi-file units.
    """
    h = hashlib.sha256()
    for rel in sorted(_walk_rel(path)):
        h.update(rel.encode("utf-8"))
        h.update(sha256_file(os.path.join(path, rel)).encode("utf-8"))
    return h.hexdigest()


def _walk_rel(root):
    for dirpath, _dirnames, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            yield os.path.relpath(full, root)


def _unit_rel(src, templates):
    """The templates-relative path of a unit, in the one form NEVER_INSTALL uses.

    Both separators are folded to "/" rather than just os.sep: a posix python handed
    a backslash path would otherwise miss the entries too.
    """
    return os.path.relpath(src, templates).replace(os.sep, "/").replace("\\", "/")


def hash_path(path):
    if os.path.isdir(path):
        return sha256_tree(path)
    if os.path.isfile(path):
        return sha256_file(path)
    return None


def load_json(path, default=None):
    """Read a JSON file, tolerating absence and emptiness but not corruption.

    A corrupt shared file is raised, never silently replaced — settings.json is the
    user's, and overwriting one we failed to parse is the clobber this file exists
    to prevent.
    """
    if not os.path.exists(path):
        return {} if default is None else default
    raw = read(path).strip()
    if not raw:
        return {} if default is None else default
    return json.loads(raw)


def save_json(path, data):
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    tmp = path + ".playbook-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
        fh.write("\n")
    os.replace(tmp, path)


# ---------------------------------------------------------------------------
# discover — walk templates/, never a hardcoded unit list
# ---------------------------------------------------------------------------

def discover(templates, claude_home):
    """Build the installable unit set by walking the template tree.

    Adding a new skill or agent to the repo must not require editing this file, so
    nothing here names a unit. The only hardcoded knowledge is NEVER_INSTALL (units
    that are generated per-repo) and the destination each KIND maps to.
    """
    units = {}

    def add(uid, kind, src, dest, **extra):
        if _unit_rel(src, templates) in NEVER_INSTALL:
            return
        unit = {
            "id": uid,
            "kind": kind,
            "src": src,
            "dest": dest,
            "needs": [],
            "source_hash": hash_path(src),
            "installed_hash": hash_path(dest),
        }
        unit.update(extra)
        units[uid] = unit

    # agents ---------------------------------------------------------------
    adir = os.path.join(templates, "agents")
    for fn in sorted(os.listdir(adir)) if os.path.isdir(adir) else []:
        if not fn.endswith(".md") or fn in SKIP_NAMES:
            continue
        name = fn[:-3]
        add("agent:" + name, "agent",
            os.path.join(adir, fn),
            os.path.join(claude_home, "agents", fn))

    # skills — the whole directory is one unit, so `wizard` is two files or none --
    sdir = os.path.join(templates, "skills")
    for dn in sorted(os.listdir(sdir)) if os.path.isdir(sdir) else []:
        full = os.path.join(sdir, dn)
        if not os.path.isdir(full):
            continue
        add("skill:" + dn, "skill", full,
            os.path.join(claude_home, "skills", dn))

    # commands -------------------------------------------------------------
    cdir = os.path.join(templates, "commands")
    for fn in sorted(os.listdir(cdir)) if os.path.isdir(cdir) else []:
        if not fn.endswith(".md") or fn in SKIP_NAMES:
            continue
        name = fn[:-3]
        add("command:" + name, "command",
            os.path.join(cdir, fn),
            os.path.join(claude_home, "commands", fn))

    # hooks ----------------------------------------------------------------
    hdir = os.path.join(templates, "hooks")
    for fn in sorted(os.listdir(hdir)) if os.path.isdir(hdir) else []:
        if not fn.endswith(".sh") or fn in SKIP_HOOKS:
            continue
        name = fn[:-3]
        add("hook:" + name, "hook",
            os.path.join(hdir, fn),
            os.path.join(claude_home, "hooks", fn),
            executable=True)

    # the allowlist the blocking hooks read; installed with comments, zero entries
    sample = os.path.join(hdir, "repo-allowlist.sample")
    if os.path.exists(sample):
        add("support:repo-allowlist", "allowlist", sample,
            os.path.join(claude_home, "repo-allowlist"))

    # trackers — exactly one, at a fixed path ------------------------------
    tdir = os.path.join(templates, "trackers")
    for fn in sorted(os.listdir(tdir)) if os.path.isdir(tdir) else []:
        if not fn.endswith(".md") or fn in SKIP_NAMES:
            continue
        name = fn[:-3]
        add("tracker:" + name, "tracker",
            os.path.join(tdir, fn),
            os.path.join(claude_home, "tracker.md"),
            exclusive="tracker")

    # views — shipped empty, filled by a skill, opened by a human ----------
    vdir = os.path.join(templates, "views")
    for fn in sorted(os.listdir(vdir)) if os.path.isdir(vdir) else []:
        if not fn.endswith(".html"):
            continue
        add("view:" + fn[:-5], "view",
            os.path.join(vdir, fn),
            os.path.join(claude_home, fn))

    # global CLAUDE.md ------------------------------------------------------
    # Only the global layer has a machine-level destination. repo.CLAUDE.md and
    # workspace.CLAUDE.md are per-repo/per-workspace: the installer does not know
    # which repo you mean, so it reports them instead of guessing a path.
    gmd = os.path.join(templates, "claude-md", "global.CLAUDE.md")
    if os.path.exists(gmd):
        add("claude-md:global", "claude-md", gmd,
            os.path.join(claude_home, "CLAUDE.md"))

    _link_dependencies(units, templates)
    return units


def _link_dependencies(units, templates):
    """Discover command→agent, command→command and →skill edges from the bodies.

    An agent gets skill edges only. See the comments in the loop for why the other
    two kinds stop at a command.

    Every edge is grepped out of the template text, so a new unit never needs a line
    here. Each discovered reference is INTERSECTED with what actually exists on disk
    before it becomes a dependency — a command may legitimately name an agent this
    repo does not ship, and demanding a file for it would make that command
    permanently uninstallable.
    """
    agents = {u["id"].split(":", 1)[1] for u in units.values() if u["kind"] == "agent"}
    skills = {u["id"].split(":", 1)[1] for u in units.values() if u["kind"] == "skill"}
    commands = {u["id"].split(":", 1)[1] for u in units.values() if u["kind"] == "command"}

    for unit in units.values():
        if unit["kind"] not in ("command", "skill", "agent"):
            continue
        body = _unit_text(unit["src"])
        me = unit["id"].split(":", 1)[1]
        needs = set()

        # @agent and /command edges are a COMMAND's business. An agent that names
        # another agent, or the command that dispatches it, is describing where it
        # sits in a flow — it is not declaring a file it cannot work without. Reading
        # those out of an agent would drag half the pipeline into a selection of one.
        if unit["kind"] != "agent":
            for ref in set(re.findall(r"(?<![\w./-])@([a-z][a-z0-9-]+)", body)):
                if ref in agents:
                    needs.add("agent:" + ref)
            # The lookbehind is load-bearing: without it a relative doc link like
            # `../../commands/resume-ticket` reads as a /resume-ticket invocation and
            # invents an edge that drags an unrelated command into the selection.
            for ref in set(re.findall(r"(?<![\w./-])/([a-z][a-z0-9-]+)", body)):
                if ref in commands and ref != me:
                    needs.add("command:" + ref)

        # Skills are everyone's business, agents included. "Load the `dispatch-weight`
        # skill and classify each fix" is an instruction that fails SILENTLY when the
        # skill is not installed: the load finds nothing and the agent carries on with
        # the step undone. Thirteen agents said that and declared nothing, so a
        # selection of agents without their commands installed instructions that could
        # not be followed. (#97)
        for ref in set(re.findall(r"`([a-z][a-z0-9-]+)`", body)):
            if ref in skills and ref != me:
                needs.add("skill:" + ref)

        unit["needs"] = sorted(needs)

    # The blocking hooks answer both their questions from the allowlist; without it
    # they read a missing file. Installing one pulls it in.
    for unit in units.values():
        if unit["kind"] == "hook" and "repo-allowlist" in _unit_text(unit["src"]):
            unit["needs"] = sorted(set(unit["needs"]) | {"support:repo-allowlist"})


def _unit_text(src):
    if os.path.isdir(src):
        parts = []
        for rel in sorted(_walk_rel(src)):
            try:
                parts.append(read(os.path.join(src, rel)))
            except (UnicodeDecodeError, OSError):
                continue
        return "\n".join(parts)
    try:
        return read(src)
    except (UnicodeDecodeError, OSError):
        return ""


def resolve_deps(units, selected):
    """Close the selection over its dependency edges.

    Returns (full_set, pulled_in) so install.sh can show the user exactly what their
    tick dragged along — decision 5 says auto-tick, but visibly.
    """
    full = set(selected)
    pulled = set()
    frontier = list(selected)
    while frontier:
        uid = frontier.pop()
        for need in units.get(uid, {}).get("needs", []):
            if need not in full:
                full.add(need)
                pulled.add(need)
                frontier.append(need)
    return sorted(full), sorted(pulled)


# ---------------------------------------------------------------------------
# placeholders
# ---------------------------------------------------------------------------

def scan_placeholders(paths):
    """Return the distinct blocking tokens across the given files.

    Blocking means: present in a `name:`, `model:` or `tools:` line. The same token
    in a description or a body is prose that is meant to survive, which is why the
    acceptance grep in 03-setup.md reads only those three keys.
    """
    found = {}
    for path in paths:
        files = [os.path.join(path, r) for r in _walk_rel(path)] if os.path.isdir(path) else [path]
        for f in files:
            if not f.endswith(".md"):
                continue
            try:
                text = read(f)
            except (UnicodeDecodeError, OSError):
                continue
            for line in text.splitlines():
                if line.split(":", 1)[0] not in BLOCKING_KEYS:
                    continue
                for tok in TOKEN_RE.findall(line):
                    found.setdefault(tok, []).append(f)
    return {k: sorted(set(v)) for k, v in found.items()}


def apply_placeholders(paths, values, delete):
    """Fill or delete blocking tokens, in the three frontmatter keys only.

    Deleting a token from a `tools:` list must take its comma with it, or the list is
    left with a dangling separator. Filling and deleting are both restricted to the
    blocking keys so prose placeholders survive untouched.
    """
    changed = []
    for path in paths:
        files = [os.path.join(path, r) for r in _walk_rel(path)] if os.path.isdir(path) else [path]
        for f in files:
            if not f.endswith(".md"):
                continue
            try:
                text = read(f)
            except (UnicodeDecodeError, OSError):
                continue
            lines = text.splitlines(keepends=True)
            dirty = False
            for i, line in enumerate(lines):
                key = line.split(":", 1)[0]
                if key not in BLOCKING_KEYS:
                    continue
                new = line
                for tok, val in values.items():
                    if tok in new:
                        new = new.replace(tok, val)
                for tok in delete:
                    if tok in new:
                        # take the token and exactly one adjacent separator
                        new = re.sub(r",\s*" + re.escape(tok), "", new)
                        new = re.sub(re.escape(tok) + r"\s*,\s*", "", new)
                        new = new.replace(tok, "")
                if new != line:
                    lines[i] = new
                    dirty = True
            if dirty:
                with open(f, "w", encoding="utf-8") as fh:
                    fh.write("".join(lines))
                changed.append(f)
    return changed


# ---------------------------------------------------------------------------
# MCP server detection
# ---------------------------------------------------------------------------
# One scanner, three locations, every server. Detection used to be asymmetric:
# serena_detect read ~/.claude.json, the project .mcp.json AND ~/.claude/plugins,
# while install.sh's server_registered read ~/.claude.json alone — so a memory or
# tracker server registered in project scope was invisible and took the DELETE
# branch. Two readers of the same fact drifted apart, which is the bug. Everything
# that asks "is this server here?" now asks the same function.

# The mcpServers key a memory server registers under. Forgetful is the one this
# playbook documents and fills in for; the rest are here so a machine that runs a
# different memory server is detected rather than silently treated as bare.
MEMORY_SERVER_KEYS = ("forgetful", "memory", "mem0", "basic-memory", "openmemory")

# Tracker MCPs, by registered key. `tracker` used to be the ONLY key looked for,
# but the repo's own templates/mcp/project.mcp.json.snippet names the server
# `gitlab` — follow the shipped snippet and the tracker token was deleted from
# every agent that has one.
TRACKER_SERVER_KEYS = ("tracker", "gitlab", "jira", "atlassian", "linear", "youtrack")

# Forgetful's wrapper trio. Every operation dispatches through
# execute_forgetful_tool(tool_name, arguments) — there are no per-operation tools,
# so this same list is the correct answer for READ and for WRITE both. See
# templates/skills/memory-schema/forgetful.SKILL.md.
FORGETFUL_TOOLS = (
    "mcp__forgetful__execute_forgetful_tool",
    "mcp__forgetful__discover_forgetful_tools",
    "mcp__forgetful__how_to_use_forgetful_tool",
)


def _connector_prefix(name):
    """The tool prefix for a claude.ai connector, DERIVED from its recorded name.

    Runs of non-alphanumeric characters collapse to a single underscore and the
    case is kept exactly as recorded. Checked against the connectors live on the
    machine this was written on:

        claude.ai Google Calendar          -> mcp__claude_ai_Google_Calendar__
        claude.ai Booking.com              -> mcp__claude_ai_Booking_com__
        claude.ai Interactive Brokers (IBKR)
                                           -> mcp__claude_ai_Interactive_Brokers_IBKR__

    Derived rather than hardcoded because the case is the server's, not ours: a
    lower-case "claude.ai forgetful" is mcp__claude_ai_forgetful__, and guessing
    the capitalisation is exactly how a tools: entry ends up unresolvable — the
    silent failure this whole gate exists to remove.
    """
    return "mcp__%s__" % re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_")


def _server_scan(home, cwd, keys, plugin_terms=(), connectors=True):
    """Look for any of `keys` under mcpServers, in the four places a server lives.

    Returns the evidence to show the user, plus which keys were found where. The
    caller decides what that means — this reports, it does not judge.
    """
    evidence, registered, plugins, connected = [], [], [], []
    home_json = os.path.join(home, ".claude.json")

    for path in (home_json, os.path.join(cwd, ".mcp.json")):
        try:
            data = load_json(path)
        except json.JSONDecodeError:
            evidence.append({"where": path, "found": "unparseable JSON — ignored"})
            continue
        if not isinstance(data, dict):
            continue
        servers = data.get("mcpServers") or {}
        if not isinstance(servers, dict):
            continue
        for key in keys:
            if key in servers:
                evidence.append({"where": path, "found": "mcpServers.%s" % key})
                if key not in registered:
                    registered.append(key)

        # A claude.ai connector is the FOURTH route, and the one that broke this:
        # it never lands under mcpServers at all, only in this list, so a machine
        # whose mcpServers is empty because the user connects everything this way
        # read as bare and the gate refused it. Only ~/.claude.json carries the
        # key — it is account state, not project state.
        if connectors and path == home_json:
            for name in data.get("claudeAiMcpEverConnected") or []:
                if not isinstance(name, str):
                    continue
                hit = next((k for k in keys if k in name.lower()), None)
                if hit is None or any(c["key"] == hit for c in connected):
                    continue
                # "ever connected" is the literal name of the key and the literal
                # truth of it: it is a history, not a live roster. Saying "found"
                # flatly would claim more than the file supports.
                evidence.append({
                    "where": path,
                    "found": "claude.ai connector %s — ever connected, "
                             "may not be active now" % name,
                })
                connected.append({"key": hit, "name": name,
                                  "prefix": _connector_prefix(name)})

    # A plugin install leaves state under ~/.claude/plugins rather than in any
    # mcpServers block, so a plugin-installed server is invisible to the scan above.
    plugdir = os.path.join(home, ".claude", "plugins")
    if plugin_terms and os.path.isdir(plugdir):
        for dirpath, dirnames, filenames in os.walk(plugdir):
            hit = next((t for t in plugin_terms
                        if any(t in n for n in dirnames + filenames)), None)
            if hit:
                evidence.append({"where": dirpath, "found": "%s plugin files" % hit})
                if hit not in plugins:
                    plugins.append(hit)
                break

    return {"evidence": evidence, "registered": registered, "plugins": plugins,
            "connectors": connected}


def serena_detect(home, cwd):
    """Work out which Serena route this machine is on, and show the evidence.

    A wrong prefix fails SILENTLY: in a `tools:` list with other working entries, an
    unresolvable name is stripped at launch and the agent runs on without its code
    tools. (Only a list where NOTHING resolves is refused, and only since v2.1.208.)
    So this reports what it found rather than deciding quietly, and install.sh lets
    the user override.
    """
    # connectors=False, deliberately, and this is the asymmetry with memory_detect
    # that #105 asks to be stated rather than left implicit. Serena is a local
    # process that has to read the working tree; a claude.ai connector is a remote
    # HTTP service that cannot. So there is no such thing as Serena-as-a-connector
    # to detect, and inventing a third route for it would mean shipping a prefix
    # nobody can ever be on. Were it accepted here it would be worse than useless:
    # route would stay None, the gate would pass on the connector evidence, and
    # the stage would then suggest B — mcp__serena__ — which is the wrong prefix,
    # silently. Memory has no equivalent objection, which is why it takes the
    # fourth route and this does not.
    scan = _server_scan(home, cwd, ("serena",), ("serena",), connectors=False)
    # Plugin evidence wins: it is route A, and it is checked last for that reason.
    route = "A" if scan["plugins"] else ("B" if scan["registered"] else None)
    return {"route": route, "evidence": scan["evidence"]}


def memory_detect(home, cwd):
    """Is a semantic-memory MCP server on this machine, and which one?

    Memory is pillar 2, and the agents that declare memory tools lose them silently
    without one, so install.sh gates on this the way it gates on Serena. `suggest` is
    the pre-filled answer the prompt offers, which is why Enter can stop meaning
    "delete the tool grant". The count is derived in tests/test-docs.sh, never here.
    """
    scan = _server_scan(home, cwd, MEMORY_SERVER_KEYS, ("forgetful",))
    found = scan["registered"] + [p for p in scan["plugins"] if p not in scan["registered"]]
    # Connectors come last on purpose. A live registration outranks a list that
    # only says the server was connected at some point, so a machine with both
    # gets the registered answer and the registered prefix.
    live = list(found)
    found += [c["key"] for c in scan["connectors"] if c["key"] not in found]
    server = found[0] if found else None

    # The prefix is half the fix and has to land with the other half. Detecting a
    # connector and then pre-filling mcp__forgetful__ would swap one silent
    # failure for another: the gate would pass and the names still would not
    # resolve. The tool SUFFIXES are the server's own and do not change with the
    # route — only the prefix does.
    conn = next((c for c in scan["connectors"] if c["key"] == server), None)
    via_connector = conn is not None and server not in live
    prefix = conn["prefix"] if via_connector else "mcp__forgetful__"
    return {
        "server": server,
        "found": found,
        "evidence": scan["evidence"],
        # Named so install.sh can warn that a history is not a live connection.
        "connector": conn["name"] if via_connector else "",
        "prefix": prefix if server == "forgetful" else "",
        # Only Forgetful ships a documented tool list in this repo. For anything
        # else the user types their own names — but the prompt still never
        # defaults to deleting them.
        "suggest": ", ".join(t.replace("mcp__forgetful__", prefix)
                             for t in FORGETFUL_TOOLS) if server == "forgetful" else "",
        # Forgetful dispatches reads and writes through ONE tool, so granting read
        # grants write. Agents that rest their scope on the split need to be told.
        "one_tool_does_both": server == "forgetful",
    }


def tracker_detect(home, cwd):
    """Is a tracker MCP registered, under any of the keys a tracker uses?"""
    scan = _server_scan(home, cwd, TRACKER_SERVER_KEYS)
    # Connectors count here too, and for a stronger reason than symmetry: several
    # trackers this repo names — GitHub, Linear, Jira — are offered as claude.ai
    # connectors, so a connector is a LIKELIER route for a tracker than for a
    # memory server. Ignoring them while still collecting their evidence was the
    # worst of both: the fourth-route blindness this branch fixed for memory, left
    # live for tracker, and the tracker blank silently deleted from every agent
    # that has one. This makes no claim about tool NAMES — unlike memory, the
    # stage asks the user to read them off /mcp — so there is no prefix to derive.
    registered = scan["registered"]
    found = registered + [c["key"] for c in scan["connectors"] if c["key"] not in registered]
    return {
        "server": found[0] if found else None,
        "found": found,
        "evidence": scan["evidence"],
    }


# ---------------------------------------------------------------------------
# Grant audit — presence, not absence
# ---------------------------------------------------------------------------
# verify_stage's original check greps for blanks that are STILL THERE. A deleted
# token is not a remaining token, so it printed "nothing left unfilled" over an
# install where the whole pipeline had lost memory access. "Nothing is unfilled"
# and "the tools are there" are different claims; this function makes the second.

# Which capability a placeholder token stands for. A file that declared the token
# is a file that is supposed to end up with that capability.
GRANT_TOKENS = {
    "<memory-read-tools>": "memory",
    "<memory-write-tools>": "memory",
    "<tracker-read-tools>": "tracker",
}


# ---------------------------------------------------------------------------
# The placeholder contract — what a recorded answer MEANS
# ---------------------------------------------------------------------------
# `update` is non-interactive: it replays the answers recorded at install time.
# That is right for as long as the question still means what it meant then, and
# wrong the moment the playbook changes what an answer stands for. #105 changed
# exactly that — a bare Enter at the memory prompts used to DELETE the tools and
# now fills them in — so every install predating it carries a recorded "delete"
# that was never a decision, and replays it onto every file, forever.
#
# Bump PLACEHOLDER_CONTRACT when the MEANING of an existing answer changes.
# Do NOT bump it because a token was added or removed. A token set cannot express
# this at all: #105 added no token and removed none, so anything derived from the
# template tree is stable across the exact change this exists to catch.
#
# CONTRACT_SUSPECT names, per bump, the recorded answers that bump invalidated.
# The gate is "a recorded delete that a bump invalidated" — never "the recorded
# number is lower than the current one". A bare version compare would also
# condemn a <tracker-read-tools> delete that was correct (the github adapter, or
# no tracker MCP registered, both delete it on purpose — install.sh:1094-1097 and
# :1106-1110), which is a permanent false stop no user could ever clear.
PLACEHOLDER_CONTRACT = 2

CONTRACT_SUSPECT = {
    # 2 — #105: Enter at the two memory prompts used to mean "remove the tools".
    #     A recorded delete for either is an accident, not an answer.
    2: ["<memory-read-tools>", "<memory-write-tools>"],
}

# What to TELL the user, per bump. Kept beside the table so that bumping the
# contract stays one edit in one file — install.sh prints whatever it is given
# here rather than carrying its own copy of the explanation.
CONTRACT_WHY = {
    2: ["Pressing Enter at that question used to REMOVE the tools. It now fills",
        "them in — so what was recorded was never a decision you made."],
}

# One bump, three places: the constant, the suspect list and the explanation. Tie
# them together here rather than trusting three edits to stay in step, because the
# drift is not survivable. A suspect key ABOVE the constant arms a stop for an
# answer nobody has been asked about yet — and re-running the installer records the
# current contract, which is still below that key, so the stop it arms can never be
# cleared. That is precisely the unclearable false stop CONTRACT_SUSPECT exists to
# prevent, reintroduced by a forgotten line.
for _bump in CONTRACT_SUSPECT:
    if _bump > PLACEHOLDER_CONTRACT:
        raise RuntimeError(
            "CONTRACT_SUSPECT names bump %d but PLACEHOLDER_CONTRACT is %d — bump the "
            "constant too, or the stop this arms can never be cleared"
            % (_bump, PLACEHOLDER_CONTRACT))
_unexplained = sorted(set(CONTRACT_WHY) - set(CONTRACT_SUSPECT))
if _unexplained:
    raise RuntimeError(
        "CONTRACT_WHY explains bump(s) %s that name no suspect answer" % _unexplained)


def _tools_line(text):
    """The `tools:` frontmatter line of an agent file, or None."""
    for line in text.splitlines():
        if line.split(":", 1)[0] == "tools":
            return line
    return None


def audit_grants(spec_path, templates_agents, installed_agents):
    """Which installed agents are missing a capability their template declared.

    Reads the template to learn what each agent is SUPPOSED to have, and the
    installed copy to see what it actually got. Serena is not a placeholder, so it
    is checked by substring; memory and tracker are checked against the answers
    actually recorded, which is the only way to tell a deliberate delete from a
    filled-in grant that happens to be named something unexpected.
    """
    try:
        spec = json.loads(read(spec_path))
    except (OSError, ValueError):
        spec = {}
    deleted = set(spec.get("delete") or [])

    rows, missing = [], {"memory": [], "tracker": [], "serena": []}
    if not os.path.isdir(templates_agents):
        return {"agents": [], "missing": missing, "checked": 0}

    for fn in sorted(os.listdir(templates_agents)):
        if not fn.endswith(".md") or fn in SKIP_NAMES:
            continue
        inst = os.path.join(installed_agents, fn)
        if not os.path.exists(inst):
            continue
        try:
            tpl_line = _tools_line(read(os.path.join(templates_agents, fn)))
            got_line = _tools_line(read(inst))
        except (OSError, UnicodeDecodeError):
            continue
        if tpl_line is None or got_line is None:
            continue

        values = spec.get("values") or {}
        name, lost = fn[:-3], []
        for tok, kind in sorted(GRANT_TOKENS.items()):
            if tok not in tpl_line or kind in lost:
                continue
            if tok in deleted:
                lost.append(kind)          # deleted on purpose — still a loss
                continue
            # Filled, but did the fill survive into the installed file? Compare on
            # the first name in the answer; a whole list is too brittle to match.
            first = (values.get(tok) or "").split(",")[0].strip()
            if not first or first not in got_line:
                lost.append(kind)
        if "serena" in tpl_line and "serena" not in got_line:
            lost.append("serena")

        if lost:
            rows.append({"agent": name, "missing": sorted(lost)})
            for kind in lost:
                missing[kind].append(name)

    return {"agents": rows, "missing": missing,
            "checked": len([f for f in os.listdir(templates_agents)
                            if f.endswith(".md") and f not in SKIP_NAMES])}


def contract_check(manifest_path):
    """Recorded answers that this installer's contract has since invalidated.

    Reads the stamp the answers were recorded under. Absent means the install
    predates stamping altogether, i.e. 0, which makes every bump apply to it.

    Only a recorded DELETE can go stale. A filled-in value is still that user's
    own answer whatever the default later became; a delete under rules where the
    delete was the accident is not an answer at all.
    """
    try:
        manifest = json.loads(read(manifest_path))
    except (OSError, ValueError):
        manifest = {}
    ph = ((manifest.get("config") or {}).get("placeholders")) or {}

    recorded = ph.get("contract")
    if not isinstance(recorded, int) or isinstance(recorded, bool):
        recorded = 0
    deleted = set(ph.get("delete") or [])

    suspect, why = set(), []
    for bump in sorted(CONTRACT_SUSPECT):
        if bump > recorded:
            hit = set(CONTRACT_SUSPECT[bump]) & deleted
            if hit:
                suspect |= hit
                why.extend(CONTRACT_WHY.get(bump) or [])

    stale = sorted(suspect)
    return {
        "recorded": recorded,
        "current": PLACEHOLDER_CONTRACT,
        "stale": stale,
        "answers": {tok: "deleted" for tok in stale},
        "why": why,
    }


def rewrite_serena(paths, prefix_to):
    """Rewrite the Serena tool prefix across installed files."""
    changed = []
    for path in paths:
        files = [os.path.join(path, r) for r in _walk_rel(path)] if os.path.isdir(path) else [path]
        for f in files:
            try:
                text = read(f)
            except (UnicodeDecodeError, OSError):
                continue
            if "mcp__serena__" not in text:
                continue
            with open(f, "w", encoding="utf-8") as fh:
                fh.write(text.replace("mcp__serena__", prefix_to))
            changed.append(f)
    return changed


# ---------------------------------------------------------------------------
# shared JSON: additive merge, and the exact reverse of it
# ---------------------------------------------------------------------------

def merge_json(target, additions):
    """Merge `additions` into the JSON at `target`, additively and never destructively.

    Three outcomes per key, and only the first one writes:
      * key absent            -> added, and recorded so remove can take it back out
      * key present, equal    -> already there, nothing to do, nothing recorded
      * key present, differs  -> the user's value is LEFT ALONE and reported as a
                                 conflict with the edit they would have to make

    Hook arrays merge entry-by-entry on the same rule: a matcher block that is already
    there is extended with the individual hook commands it is missing, never replaced.
    """
    original = load_json(target)
    if not isinstance(original, dict):
        raise SystemExit("refusing to merge into %s: top level is not an object" % target)

    added = []       # json-pointer-ish paths this run created
    conflicts = []

    def walk(dst, src, path):
        for key, val in src.items():
            here = path + [key]
            if key not in dst:
                dst[key] = val
                added.append(here)
            elif isinstance(dst[key], dict) and isinstance(val, dict):
                walk(dst[key], val, here)
            elif isinstance(dst[key], list) and isinstance(val, list):
                _merge_list(dst[key], val, here, added)
            elif dst[key] != val:
                conflicts.append({
                    "path": "/".join(str(p) for p in here),
                    "yours": dst[key],
                    "ours": val,
                })

    def _merge_list(dst, src, path, added):
        for item in src:
            match = _find_matcher(dst, item)
            if match is None:
                dst.append(item)
                added.append(path + [_ident(item)])
                continue
            # same matcher: add only the individual hook commands that are missing
            if isinstance(item, dict) and isinstance(item.get("hooks"), list):
                existing = match.setdefault("hooks", [])
                have = {json.dumps(h, sort_keys=True) for h in existing}
                for h in item["hooks"]:
                    if json.dumps(h, sort_keys=True) not in have:
                        existing.append(h)
                        # The literal "hooks" step matters: the command lives at
                        # block["hooks"][i], and a path that jumps straight from the
                        # matcher to the command lands on the block dict at removal
                        # time and silently takes nothing back out.
                        added.append(path + [_ident(item), "hooks", _ident(h)])

    walk(original, additions, [])
    save_json(target, original)
    return {"added": added, "conflicts": conflicts, "target": target}


def _ident(item):
    """A stable identity for a list entry, used to record and later remove it."""
    if isinstance(item, dict):
        if "matcher" in item:
            return "matcher=" + str(item["matcher"])
        if "command" in item:
            return "command=" + str(item["command"])
    return json.dumps(item, sort_keys=True)


def _find_matcher(lst, item):
    if not isinstance(item, dict):
        return None
    want = item.get("matcher")
    for cand in lst:
        if isinstance(cand, dict) and cand.get("matcher") == want:
            return cand
    return None


def unmerge_json(target, record):
    """Undo exactly the additions in `record`, and nothing else.

    Anything the user added later, or changed, stays. A key we created but whose value
    no longer matches what we wrote is left in place and reported — that is a user edit
    wearing our key name, and decision 7 says we keep it.
    """
    data = load_json(target)
    removed, kept = [], []

    for path in sorted(record.get("added", []), key=len, reverse=True):
        node = data
        parents = []
        ok = True
        for part in path[:-1]:
            nxt = _descend(node, part)
            if nxt is None:
                ok = False
                break
            parents.append((node, part))
            node = nxt
        if not ok:
            continue
        leaf = path[-1]
        if isinstance(node, dict):
            if leaf in node:
                del node[leaf]
                removed.append("/".join(str(p) for p in path))
        elif isinstance(node, list):
            for i, cand in enumerate(node):
                if _ident(cand) == leaf:
                    del node[i]
                    removed.append("/".join(str(p) for p in path))
                    break

    _prune_empty(data)
    save_json(target, data)
    return {"removed": removed, "kept": kept, "target": target}


def _descend(node, part):
    if isinstance(node, dict):
        return node.get(part)
    if isinstance(node, list):
        for cand in node:
            if _ident(cand) == part:
                return cand
    return None


def _prune_empty(node):
    """Drop containers we emptied, so an uninstall does not leave `"hooks": {}` behind.

    A matcher block whose last hook we just removed is also junk: it matches tool calls
    and then runs nothing. It goes too — but only when we emptied it, never when the
    user still has a hook of their own in there.
    """
    if isinstance(node, dict):
        for key in list(node.keys()):
            _prune_empty(node[key])
            if node[key] in ({}, []):
                del node[key]
    elif isinstance(node, list):
        for item in list(node):
            _prune_empty(item)
            if item in ({}, []):
                node.remove(item)
            elif isinstance(item, dict) and "matcher" in item and not item.get("hooks"):
                node.remove(item)


def hook_wiring(snippet_path, installed_hooks):
    """Build the settings.json hook block, LIMITED to hooks actually being installed.

    Wiring the full snippet would reference hooks that are not on disk. Claude Code
    then runs a missing file on every matching tool call, and the blocking hooks fail
    closed — so an over-wired settings.json does not misfire quietly, it jams.
    """
    snippet = load_json(snippet_path)
    wanted = {"~/.claude/hooks/%s.sh" % h for h in installed_hooks}
    result = {"hooks": {}}
    for event, blocks in (snippet.get("hooks") or {}).items():
        keep_blocks = []
        for block in blocks:
            keep = [h for h in block.get("hooks", []) if h.get("command") in wanted]
            if keep:
                nb = {k: v for k, v in block.items() if k != "hooks"}
                nb["hooks"] = keep
                keep_blocks.append(nb)
        if keep_blocks:
            result["hooks"][event] = keep_blocks
    return result


def verify_wiring(settings_path, installed_hooks):
    """Re-read settings.json and report which hooks are genuinely referenced.

    Installing a hook is not wiring a hook. The installer may only call a hook ACTIVE
    after this returns it as wired — test-hooks.sh never sees settings.json and so
    proves nothing about wiring.
    """
    try:
        data = load_json(settings_path)
    except json.JSONDecodeError:
        return {"wired": [], "unwired": sorted(installed_hooks),
                "error": "settings.json is not valid JSON"}
    seen = set()
    for _event, blocks in (data.get("hooks") or {}).items():
        for block in blocks or []:
            for h in block.get("hooks", []) or []:
                cmd = h.get("command", "")
                m = re.search(r"([A-Za-z0-9_-]+)\.sh$", cmd)
                if m:
                    seen.add(m.group(1))
    wired = sorted(h for h in installed_hooks if h in seen)
    return {"wired": wired,
            "unwired": sorted(h for h in installed_hooks if h not in seen)}


# ---------------------------------------------------------------------------
# manifest
# ---------------------------------------------------------------------------

def manifest_classify(manifest, units):
    """Sort every recorded unit into one of three states.

    This three-way split is what decisions 7 and 8 both stand on:
      * pristine — on disk, hash matches what we wrote: safe to upgrade, safe to remove
      * edited   — on disk, hash differs: the user changed it. Never touched again.
      * missing  — gone: nothing to do
    """
    state = {"pristine": [], "edited": [], "missing": []}
    for uid, rec in (manifest.get("units") or {}).items():
        dest = rec.get("dest")
        current = hash_path(dest) if dest else None
        if current is None:
            state["missing"].append(uid)
        elif current == rec.get("hash"):
            state["pristine"].append(uid)
        else:
            state["edited"].append(uid)
    for key in state:
        state[key].sort()
    return state


def plan_install(units, manifest, selected):
    """Decide, per selected unit, what an install run may actually do to it.

    Six actions, and only two of them write:
      * install        — nothing there yet
      * upgrade        — there, and still byte-identical to what we last wrote
      * current        — there, ours, and already the version we ship
      * skip-edited    — there, but changed since we wrote it. Left alone. Reported.
      * skip-foreign   — there, and no record of us putting it there. Left alone.
      * orphan         — recorded, but this clone no longer ships it. Reported only.

    'skip-edited' is decision 8 and half of decision 7 in one line: an upgrade that
    clobbers an edited file is the same bug as a bad uninstall.
    """
    recorded = manifest.get("units") or {}
    rows = []
    for uid in selected:
        unit = units.get(uid)
        rec = recorded.get(uid)
        if not unit:
            # Recorded once, and this clone no longer ships a template for it: a
            # rename or a removal. `continue` dropped it from the plan entirely,
            # so nothing reported it and write_manifest carried the dead record
            # forward on every run, forever. Report it; deleting the installed
            # file without asking is out of scope.
            if rec is not None:
                # "-" and not "": install.sh reads these rows with `read -r` under
                # IFS=$'\t', and TAB is IFS WHITESPACE, so a run of tabs collapses
                # into ONE delimiter. An empty src column therefore does not arrive
                # as an empty field — it vanishes, and every column after it shifts
                # left, which silently emptied the destination path this row exists
                # to report. Never emit an empty column into a TSV read this way.
                rows.append(("orphan", uid, rec.get("kind", "?"), "-",
                             rec.get("dest", "")))
            continue
        dest = unit["dest"]
        current = hash_path(dest)
        if current is None:
            action = "install"
        elif rec is None:
            # On disk but not ours — a hand-copied file from the manual path.
            # Never adopted HERE: install.sh offers adoption on the confirm stage and
            # records it as "adopted": True in the manifest, which permanently exempts
            # the unit from removal. Adopting silently would instead let a later remove
            # delete work this script never wrote.
            action = "skip-foreign"
        elif current != rec.get("hash"):
            action = "skip-edited"
        elif rec.get("source_hash") == unit["source_hash"]:
            action = "current"
        else:
            action = "upgrade"
        rows.append((action, uid, unit["kind"], unit["src"], dest))
    return rows


def plan_state(manifest, units):
    """The `list` view: what an update would do, without doing it.

    Adds two things plan_remove cannot know, because they need the current
    templates: whether a unit is OUTDATED (the template moved since we installed
    it), and which units this clone ships that are not installed at all.
    """
    rows = []
    recorded = manifest.get("units") or {}
    for uid, rec in sorted(recorded.items()):
        dest = rec.get("dest")
        current = hash_path(dest) if dest else None
        unit = units.get(uid)
        if current is None:
            state = "missing"
        elif current != rec.get("hash"):
            state = "edited"
        elif unit is None:
            # Recorded, still on disk, byte-identical to what we wrote — and this
            # clone no longer ships a template for it. A rename or a removal. The
            # `unit and ...` guard below short-circuits falsy here, so the else
            # used to call it "current", i.e. "the same version this clone ships",
            # about a unit this clone does not ship at all.
            #
            # After missing/edited on purpose: a file that is gone, or that the
            # user has since changed, is better described by those.
            state = "orphaned"
        elif unit["source_hash"] != rec.get("source_hash"):
            state = "outdated"
        else:
            state = "current"
        rows.append((state, uid, rec.get("kind", "?")))
    for uid in sorted(units):
        if uid not in recorded:
            rows.append(("available", uid, units[uid]["kind"]))
    return rows


def plan_remove(manifest):
    """Decide, per recorded unit, what a remove run may actually delete.

    Only a file still matching the hash we recorded is ours to delete. Anything else
    is either gone already or has the user's changes in it, and stays.

    'keep-adopted' is the fourth answer, and it does not consult the hash at all. An
    adopted unit was on disk BEFORE this script ever ran — the user consented to it
    being managed, which buys updates, not the right to delete it. Matching hashes
    only prove we last wrote what is there now, never that we put it there first.
    """
    rows = []
    for uid, rec in sorted((manifest.get("units") or {}).items()):
        dest = rec.get("dest")
        current = hash_path(dest) if dest else None
        if current is None:
            action = "gone"
        elif rec.get("adopted"):
            action = "keep-adopted"
        elif current == rec.get("hash"):
            action = "remove"
        else:
            action = "keep-edited"
        rows.append((action, uid, rec.get("kind", "?"), dest or ""))
    return rows


def tsv(rows):
    for row in rows:
        sys.stdout.write("\t".join(str(c) for c in row) + "\n")


# ---------------------------------------------------------------------------
# entry point
# ---------------------------------------------------------------------------

def main(argv):
    if len(argv) < 2:
        raise SystemExit("usage: install-lib.py <subcommand> [args]")
    cmd = argv[1]
    a = argv[2:]

    if cmd == "discover":
        out(discover(a[0], a[1]))
    elif cmd == "resolve-deps":
        units = json.loads(read(a[0]))
        full, pulled = resolve_deps(units, json.loads(a[1]))
        out({"selected": full, "pulled_in": pulled})
    elif cmd == "hash":
        out({"path": a[0], "hash": hash_path(a[0])})
    elif cmd == "scan-placeholders":
        out(scan_placeholders(a))
    elif cmd == "apply-placeholders":
        spec = json.loads(read(a[0]))
        out({"changed": apply_placeholders(spec["paths"], spec["values"], spec["delete"])})
    elif cmd == "serena-detect":
        out(serena_detect(a[0], a[1]))
    elif cmd == "memory-detect":
        out(memory_detect(a[0], a[1]))
    elif cmd == "tracker-detect":
        out(tracker_detect(a[0], a[1]))
    elif cmd == "audit-grants":
        out(audit_grants(a[0], a[1], a[2]))
    elif cmd == "contract-check":
        out(contract_check(a[0]))
    elif cmd == "contract-version":
        out(PLACEHOLDER_CONTRACT)
    elif cmd == "serena-rewrite":
        out({"changed": rewrite_serena(json.loads(read(a[0])), a[1])})
    elif cmd == "merge-json":
        out(merge_json(a[0], json.loads(read(a[1]))))
    elif cmd == "unmerge-json":
        out(unmerge_json(a[0], json.loads(read(a[1]))))
    elif cmd == "hook-wiring":
        out(hook_wiring(a[0], a[1:]))
    elif cmd == "verify-wiring":
        out(verify_wiring(a[0], a[1:]))
    elif cmd == "plan-install":
        units = json.loads(read(a[0]))
        manifest = load_json(a[1])
        selected = [l.strip() for l in read(a[2]).splitlines() if l.strip()]
        tsv(plan_install(units, manifest, selected))
    elif cmd == "plan-state":
        tsv(plan_state(load_json(a[0]), json.loads(read(a[1]))))
    elif cmd == "plan-remove":
        tsv(plan_remove(load_json(a[0])))
    elif cmd == "units-tsv":
        units = json.loads(read(a[0]))
        tsv(sorted(
            (u["kind"], u["id"].split(":", 1)[1], u["id"], len(u["needs"]))
            for u in units.values()))
    elif cmd == "manifest-classify":
        out(manifest_classify(load_json(a[0]), None))
    elif cmd == "json-get":
        out(load_json(a[0]))
    elif cmd == "json-put":
        save_json(a[0], json.loads(read(a[1])))
        out({"written": a[0]})
    else:
        raise SystemExit("unknown subcommand: %s" % cmd)


if __name__ == "__main__":
    main(sys.argv)
