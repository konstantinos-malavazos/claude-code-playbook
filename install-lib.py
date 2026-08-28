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
        rel = os.path.relpath(src, templates)
        if rel in NEVER_INSTALL:
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
        if unit["kind"] not in ("command", "skill"):
            continue
        body = _unit_text(unit["src"])
        needs = set()

        for ref in set(re.findall(r"(?<![\w./-])@([a-z][a-z0-9-]+)", body)):
            if ref in agents:
                needs.add("agent:" + ref)
        # The lookbehind is load-bearing: without it a relative doc link like
        # `../../commands/resume-ticket` reads as a /resume-ticket invocation and
        # invents an edge that drags an unrelated command into the selection.
        for ref in set(re.findall(r"(?<![\w./-])/([a-z][a-z0-9-]+)", body)):
            if ref in commands and ref != unit["id"].split(":", 1)[1]:
                needs.add("command:" + ref)
        for ref in set(re.findall(r"`([a-z][a-z0-9-]+)`", body)):
            if ref in skills and ref != unit["id"].split(":", 1)[1]:
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
# Serena route detection
# ---------------------------------------------------------------------------

def serena_detect(home, cwd):
    """Work out which Serena route this machine is on, and show the evidence.

    A wrong prefix fails SILENTLY: an unresolvable name in a `tools:` list is stripped
    at launch and the agent runs on without its code tools. So this reports what it
    found rather than deciding quietly, and install.sh lets the user override.
    """
    evidence = []
    route = None

    global_json = os.path.join(home, ".claude.json")
    try:
        data = load_json(global_json)
    except json.JSONDecodeError:
        data = {}
        evidence.append({"where": global_json, "found": "unparseable JSON — ignored"})
    if isinstance(data, dict):
        if "serena" in (data.get("mcpServers") or {}):
            evidence.append({"where": global_json, "found": "mcpServers.serena"})
            route = "B"

    proj = os.path.join(cwd, ".mcp.json")
    try:
        pdata = load_json(proj)
    except json.JSONDecodeError:
        pdata = {}
    if isinstance(pdata, dict) and "serena" in (pdata.get("mcpServers") or {}):
        evidence.append({"where": proj, "found": "mcpServers.serena"})
        route = "B"

    # Route A leaves plugin state under ~/.claude/plugins.
    plugdir = os.path.join(home, ".claude", "plugins")
    if os.path.isdir(plugdir):
        for dirpath, dirnames, filenames in os.walk(plugdir):
            if any("serena" in n for n in dirnames + filenames):
                evidence.append({"where": dirpath, "found": "serena plugin files"})
                route = "A"
                break

    return {"route": route, "evidence": evidence}


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

    Four actions, and only two of them write:
      * install        — nothing there yet
      * upgrade        — there, and still byte-identical to what we last wrote
      * current        — there, ours, and already the version we ship
      * skip-edited    — there, but changed since we wrote it. Left alone. Reported.

    'skip-edited' is decision 8 and half of decision 7 in one line: an upgrade that
    clobbers an edited file is the same bug as a bad uninstall.
    """
    recorded = manifest.get("units") or {}
    rows = []
    for uid in selected:
        unit = units.get(uid)
        if not unit:
            continue
        dest = unit["dest"]
        current = hash_path(dest)
        rec = recorded.get(uid)
        if current is None:
            action = "install"
        elif rec is None:
            # On disk but not ours — a hand-copied file from the manual path.
            # Adopting it silently would let a later remove delete the user's work.
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
        elif unit and unit["source_hash"] != rec.get("source_hash"):
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
    """
    rows = []
    for uid, rec in sorted((manifest.get("units") or {}).items()):
        dest = rec.get("dest")
        current = hash_path(dest) if dest else None
        if current is None:
            action = "gone"
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
