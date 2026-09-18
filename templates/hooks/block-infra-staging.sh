#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Sorts AI-infra paths into what may enter a product repo and what may not. Exit 2 = block.
#
# The rule is about PROVENANCE, not location: would a fresh clone on a new laptop need
# this file? Paths were a good proxy until the bootstrap started legitimately producing
# files at those paths. See docs/solo/07-guardrails-when-solo.md.
#
#   never          .claude/ (the generated views, handoffs), .serena, .forgetful, MEMORY.md
#   always fine    .claude/agents/**, .claude/skills/**  — facts about THIS codebase
#   ask the file   CLAUDE.md — allowlisted per repo in ~/.claude/repo-allowlist

set -euo pipefail

block() { echo "BLOCKED by block-infra-staging: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
# Duplicated verbatim from block-dangerous-git.sh, deliberately — the full reasoning for
# all of it (why python and not jq or sed, why 127 is the same class as success, why a
# permission prompt was rejected, why a WindowsApps python3 goes to the END of the list
# and is never dropped, and why nothing is probed until we are refusing anyway) is in the
# notes there. The code below is byte-identical in all seven hooks and in test-hooks.sh; a
# divergence between the copies would be a guardrail choosing a different interpreter
# from the suite that tests it.
PY_LIST=()
PY_LAST=()
# ONE command substitution, not one per candidate. A fork costs ~30ms on Windows and this
# runs on every single hook invocation, so asking twice cost measurably more than the
# whole ordering decision it feeds. The `true` keeps the list non-fatal when neither name
# resolves; the empty-line guard is what a missing candidate looks like here.
while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    case "${_p,,}" in
        */windowsapps/*) PY_LAST+=("$_p") ;;
        *)               PY_LIST+=("$_p") ;;
    esac
done <<< "$(command -v python3 2>/dev/null; command -v python 2>/dev/null; true)"
PY_LIST+=(${PY_LAST[@]+"${PY_LAST[@]}"})

py_tried() { # the refusal's evidence: every candidate by resolved path, with a verdict
    local _c _out=""
    for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
        if "$_c" -c "pass" >/dev/null 2>&1; then
            _out="${_out}${_out:+, }${_c} (is python)"
        else
            _out="${_out}${_out:+, }${_c} (on PATH, but not a working python)"
        fi
    done
    printf 'interpreter tried: %s' "${_out:-none — no python3 or python on PATH}"
}

py_run() { # <stdin> <program> [args…] — first candidate that answers wins
    local _in="$1" _prog="$2" _c _rc=127
    shift 2
    for _c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
        _rc=0
        printf '%s' "$_in" | "$_c" -c "$_prog" "$@" 2>/dev/null || _rc=$?
        [ "$_rc" -eq 0 ] && return 0
        # 3 is the PROGRAM saying no, not the interpreter failing to be python. Handing
        # the same input to a different interpreter would get the same answer.
        [ "$_rc" -eq 3 ] && return 3
    done
    return "$_rc"
}

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the command it exists to check."

# `read -d ""` rather than $(cat). A command substitution forks a subshell and then execs
# cat, which measured 37ms on Windows — more than choosing the interpreter above and more
# than the parse itself on an ordinary payload, for reading one string off stdin. `-d ""`
# reads to EOF (a JSON payload carries no NUL), `-r` keeps backslashes literal, `IFS=`
# keeps leading and trailing whitespace, and the non-zero exit at EOF is the expected
# outcome, not a failure. The only difference from $(cat) is that a trailing newline
# survives, and no JSON reader cares. Measured faster at 4KB as well as at 60 bytes.
IFS= read -r -d '' payload || true

parse() { # <command|cwd> — prints the field; non-zero if the payload will not parse
    py_run "$payload" '
import json, sys
d = json.load(sys.stdin)
if sys.argv[1] == "cwd":
    v = d.get("cwd") or ""
else:
    ti = d.get("tool_input") or {}
    v = ti.get("command") or ti.get("script") or ""
# BINARY buffer, UTF-8, and no newline added. A text-mode write turns every \n in the
# command into CR LF on Windows, and staged_args() joins line continuations, which is
# the transform that turns a doubled CR into a wrong answer. See the note headed "BOTH
# FIELDS ARE WRITTEN THROUGH THE BINARY BUFFER" in block-dangerous-git.sh for both reasons.
sys.stdout.buffer.write(v.encode("utf-8"))
' "$1"
}

cmd="$(parse command)" || block "the payload did not parse as JSON — refusing to guess what this command stages. $(py_tried)"

# Newlines and \r become ';' so a CRLF payload behaves the same as an LF one — see
# block-dangerous-git.sh.
#
# This used to say `git add .` on any line but the first would otherwise slip past "the
# pattern below". Untrue since #112: the only pattern below that reads $norm is the
# unanchored `git` pre-filter at the hard-blocks section, which nothing slips past on the
# grounds of which line it is on. staged_args() reads "$cmd", not $norm, and converts
# newlines to separators itself. The line is kept because block-dangerous-git.sh computes
# the same $norm — but it does so with parameter expansion plus a squeeze loop rather than
# this `tr` pipeline, to drop two spawns from the hot path. The transform is equivalent;
# only the form differs, and the difference is deliberate, not drift.
norm="$(printf '%s' "$cmd" | tr '\r\n' ';;' | tr -s ' ')"

# --- The allowlist -------------------------------------------------------------
# Duplicated verbatim from block-dangerous-git.sh, deliberately — see the note there.
allowlist_says() { # <push|claude-md> — exit 0 = yes, 1 = no
    local field="$1" file="$HOME/.claude/repo-allowlist" dir remote key push own
    [ -r "$file" ] || return 1
    dir="$(parse cwd)" || block "the payload did not parse as JSON — refusing to guess which repo this is. $(py_tried)"
    [ -n "$dir" ] && [ -d "$dir" ] || dir="$PWD"
    remote="$(git -C "$dir" config --get remote.origin.url 2>/dev/null || true)"
    [ -n "$remote" ] || return 1
    while read -r key push own; do
        case "$key" in ''|\#*) continue ;; esac
        case "$remote" in *"$key"*) ;; *) continue ;; esac
        case "$field" in
            push)      [ "$push" = "yes" ] && return 0 ;;
            claude-md) [ "$own"  = "yes" ] && return 0 ;;
        esac
    done < "$file"
    return 1
}

# --- What does this command actually STAGE? ------------------------------------
# Every check below reads the ARGUMENTS of a git add/commit/stage, never the command text.
#
# The text scan this replaces refused any command in which a never-stage name APPEARED at
# all. `git commit -m "stop tracking MEMORY.md"` was blocked. So was a heredoc writing a
# note about the rule — twice while #112 was being fixed, once in the notes for #112
# itself. And because a compound command dies whole, anything chained in FRONT of the
# mention never ran either, so the failure read as if that first step was the problem.
# Anchoring the patterns to a path boundary did not close this: in prose a name has a space
# on each side, and a space IS a path boundary.
#
# So the tokenizer below answers the only question worth asking — WHICH WORDS are paths
# handed to a staging verb — and the checks compare a whole path COMPONENT against a whole
# name. That is exact, so the anchor regexes are gone: `garden-memory.md` is one component
# and it is not `MEMORY.md`, no boundary class required.
#
# Case folding stays, and is the decision recorded in #112: Windows resolves .Serena and
# .serena to one directory, so a different spelling must not be a way through.
#
# A command that will not tokenize is a BLOCK, exactly as an unreadable payload is: the
# hook did not find out what it was being asked to clear, so it does not clear it.
# A parameterised second copy of this tokenizer lives in block-dangerous-git.sh as
# payload_fields(), deliberately — same reasoning as the allowlist note above. It is NOT a
# verbatim copy. What is different there, on purpose:
#   - it emits every subcommand rather than a fixed SUB map, and a row for the subcommand
#     itself, and reads VAL with .get();
#   - it strips percent-paren spans before tokenizing;
#   - it turns a backtick that is NOT before a newline into a separator. This tokenizer
#     does not, and must not: here that split would move a path word out of its add
#     segment (git add, a backtick span, then .claude/x), turning a block into an allow;
#   - it reads option words through deb() (backslash and dollar escapes removed);
#   - it folds no case beyond the subcommand, where this one folds paths (see above);
#   - it reads the JSON in the same program; this file has parse() for that.
# SHARED, and a change to any of these here is a change to make there too: HEREDOC_WORD,
# heredoc_ops and strip_heredocs; tokenize and fallback_tokens; MULTI, NO_EXEC, LEADERS and
# runs_no_args; the pipe test and the candidate step in seg_rows; MAX_DEPTH, span_views and
# the nested-view loop. Also shared in behaviour: the line-continuation join, the newline
# separator, the redirection drop, the forward scan over every git word in a segment, and
# the binary UTF-8 stdout write.
staged_args() { # prints "<subcommand>\t<opt|path>\t<word>" per argument; exit 3 = unparsable
    py_run "$cmd" '
import re, shlex, sys

SUB = {"add": "add", "stage": "add", "commit": "commit"}

# The options git itself takes BEFORE the subcommand. These four take a separate value.
GLOBAL_VAL = {"-C", "-c", "--git-dir", "--work-tree", "--exec-path", "--namespace"}

# Options whose value is a message, a mode or a file to READ — never a path to stage.
# Options that may OMIT their value (-S, -u) are deliberately absent: skipping the word
# after one of those would swallow a real path, and that fails OPEN.
VAL = {
    "add": {"--chmod", "--pathspec-from-file"},
    "commit": {"-m", "--message", "-F", "--file", "-C", "--reuse-message",
               "-c", "--reedit-message", "--author", "--date", "--cleanup",
               "--squash", "--fixup", "-t", "--template", "--trailer",
               "--pathspec-from-file"},
}

OPS = (";", "&&", "||", "|", "&", "|&", "(", ")")

HEREDOC_WORD = re.compile(r"-?[ \t]*([\x27\x22]?)([A-Za-z_][A-Za-z0-9_]*)\1(?![^\s;&|()<>])")

def heredoc_ops(line, quote):
    # WHICH <<WORD ON THIS LINE IS A REAL HEREDOC OPERATOR, read the way bash reads it.
    # Returns the line with every operator span removed, the terminator words in order,
    # and the quote state at the end of the line (a quoted string may run onto the next
    # line, and bash keeps reading it as one string).
    #   - Inside single or double quotes, << is text. Outside single quotes a backslash
    #     escapes the next character, as it does in bash.
    #   - An unquoted # that starts a word begins a comment; nothing after it is scanned.
    #   - <<< is a here-string and never a heredoc, whatever follows it.
    #   - EVERY real operator on the line is collected, not only the first.
    #   - A word that runs on past the name (<<EOF-1) is not taken, so its lines are judged.
    # An unbalanced quote leaves the rest of the payload quoted, so no later operator is
    # honoured and every later line is judged: that mistake blocks, it does not swallow.
    keep, ops, cut, i, n = [], [], 0, 0, len(line)
    while i < n:
        c = line[i]
        if quote == "\x27":
            if c == "\x27":
                quote = ""
            i += 1
        elif c == "\\":
            i += 2
        elif quote:
            if c == quote:
                quote = ""
            i += 1
        elif c in "\x27\x22":
            quote = c
            i += 1
        elif c == "#" and (i == 0 or line[i - 1] in " \t;&|()<>"):
            break
        elif line.startswith("<<<", i):
            i += 3
        elif line.startswith("<<", i):
            m = HEREDOC_WORD.match(line, i + 2)
            if m:
                ops.append(m.group(2))
                keep.append(line[cut:i])
                cut = i = m.end()
            else:
                i += 2
        else:
            i += 1
    keep.append(line[cut:])
    return "".join(keep), ops, quote

def strip_heredocs(s):
    # A heredoc body is DATA, not a command. A line inside one that begins with git is
    # prose ABOUT git, which is what this repo is full of.
    #
    # heredoc_ops AND THIS FUNCTION ARE IDENTICAL TEXT in block-dangerous-git.sh and
    # block-infra-staging.sh. A change to one is a change to make to the other.
    #
    # THREE THINGS THIS FUNCTION MUST NOT DO, each a fail-open:
    #
    #   1. DROP THE REST OF THE OPERATOR LINE. In bash the body starts on the NEXT line, so
    #      whatever follows the operator on THIS one is a real command that really runs:
    #      cat <<EOF ; git branch -D feature, cat <<EOF > n.txt && git add -A.
    #   2. SWALLOW WHEN THE TERMINATOR NEVER COMES. With no terminator the swallow is the
    #      whole rest of the payload, judged by nothing. An unterminated heredoc is a shape
    #      bash itself refuses to run (a git shim records no call), so judging those lines
    #      cannot cost a real false positive. With several operators on one line, every
    #      terminator must be found in order, or no line is treated as a body.
    #   3. TAKE A <<WORD THAT BASH DOES NOT: one inside quotes or after a #, the word of a
    #      <<<EOF here-string, or only the first of several operators on a line. Any of
    #      those drops the lines up to a coincidental terminator unjudged.
    #
    # 1 DEPENDS ON 3. In grep -n "<<\x27PY\x27" install.sh followed by a force push, the quoted
    # <<\x27PY\x27 is not an operator, so the line stays whole and the force push is judged.
    lines = s.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out, i, quote, pending = [], 0, "", []
    while i < len(lines):
        text, ops, quote = heredoc_ops(lines[i], quote)
        out.append(text)
        pending += ops
        i += 1
        if pending and not quote:
            j, closed = i, True
            for term in pending:
                while j < len(lines) and lines[j].strip() != term:
                    j += 1
                if j >= len(lines):
                    closed = False
                    break
                j += 1
            if closed:             # every terminator found: real heredocs, bodies are data
                i = j
            # else: not heredocs after all — judge those lines, do not discard them
            pending = []
    return "\n".join(out)

def prepare(src):
# A LINE CONTINUATION is ONE command written over two lines, so it is joined BEFORE any
# newline becomes a separator; splitting there puts the rest of the command, paths
# included, in a segment of its own that no rule reads. Same regex as block-dangerous-git.sh
# (see the note there for the greedy newline class and the trailing-backtick ambiguity).
# Only the JOIN is shared: a backtick elsewhere is NOT made a separator here, because that
# split would move a path word out of its add segment and turn a block into an allow.
    src = re.sub(r"[\\\x60][ \t]*\n+", " ", src)

# Newlines become an explicit separator BEFORE tokenizing: shlex treats one as plain
# whitespace, which would run two commands together into one segment.
    return src.replace("\n", " ; ")

def tokenize(src):
    lex = shlex.shlex(src, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.escape = ""      # a backslash is a Windows path separator here, never an escape
    lex.commenters = ""
    return list(lex)     # raises ValueError when shlex refuses; the caller decides

def fallback_tokens(src):
    # For an INNER string shlex refuses (an apostrophe inside double quotes is enough).
    # It is still judged: quote marks are dropped and the text is split on whitespace and
    # on the separators shlex would have split.
    src = src.replace("\x27", "").replace("\x22", "")
    return re.findall(r"\|\||&&|\|&|[;&|()]|[<>]+|[^\s;&|()<>]+", src)

# A token matching this tokenizes to more than one word, so it may be a command string.
MULTI = re.compile(r"[\s;&|()<>\x60]")

# Commands that never run their arguments, so none of those arguments is a candidate.
# The command is the first word of the segment after LEADERS and VAR=value words; an
# option, a path or an unlisted wrapper in that place leaves the arguments candidates.
# Substitution spans inside these arguments are still read by span_views.
# rg with --pre runs a command, so it is not exempt.
NO_EXEC = frozenset(("echo", "printf", "grep", "rg", "gh"))
LEADERS = frozenset(("sudo", "env", "time", "command", "nohup", "nice", "exec", "!",
                     "if", "then", "elif", "else", "do", "while", "until"))

def runs_no_args(words):
    k = 0
    while k < len(words) and (words[k] in LEADERS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[k])):
        k += 1
    if k < len(words) and words[k] == "rg":
        return not any(w == "--pre" or w.startswith("--pre=") for w in words[k + 1:])
    return k < len(words) and words[k] in NO_EXEC

def seg_rows(toks, out, cands):
    # Appends the rows for toks to out, and to cands every token that may itself be a
    # command string, except a word consumed as a VAL value (a commit message) and any
    # argument of a NO_EXEC command with no pipe anywhere after it in toks.
    segs, cur, piped = [], [], -1
    for t in toks:
        if "|" in t.replace("||", "") and not t.strip("();<>|&"):
            piped = len(segs)                     # shlex glues )| into one token
        if t in OPS:
            segs.append(cur)
            cur = []
        else:
            cur.append(t)
    segs.append(cur)

    for s, seg in enumerate(segs):
        words, k = [], 0
        while k < len(seg):                       # drop redirections and their targets
            if seg[k] and all(c in "<>" for c in seg[k]):
                cands.extend(seg[k + 1:k + 2])    # still a candidate: bash <<< "git add -A"
                k += 2
                continue
            words.append(seg[k])
            k += 1
        is_val = set()                            # indexes in words consumed as a VAL value

        j = 0                                     # leading VAR=value assignments
        while j < len(words) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[j]):
            j += 1
        # The git program may sit behind a wrapper (sudo, env, time, command, xargs) or a
        # shell keyword (then, do), so scan forward for it rather than requiring word 0. An
        # unrecognised word is SKIPPED, never a reason to give up on the segment, and EVERY
        # git in the segment is judged, not just the first (in sudo -u git git add -A the
        # first git is the value of -u). An extra row can only make a rule fire.
        p = j
        while p < len(words):
            if words[p].replace("\\", "/").rsplit("/", 1)[-1].lower() not in ("git", "git.exe"):
                p += 1
                continue
            j = p + 1
            p += 1

            while j < len(words) and words[j].startswith("-"):
                j += 2 if words[j] in GLOBAL_VAL else 1
            if j >= len(words):
                continue
            sub = SUB.get(words[j].lower())
            if sub is None:
                continue

            j += 1
            rest_are_paths = False
            while j < len(words):
                w = words[j]
                if not rest_are_paths and w == "--":
                    rest_are_paths = True
                    j += 1
                elif not rest_are_paths and w.startswith("-") and w != "-":
                    out.append(sub + "\t" + "opt" + "\t" + w)
                    if w in VAL[sub]:
                        is_val.add(j + 1)
                        j += 2
                    else:
                        if w.split("=", 1)[0] in VAL[sub] or (w[1:2] != "-" and w[:2] in VAL[sub]):
                            is_val.add(j)         # --message=text or -mtext: value inline
                        j += 1
                else:
                    out.append(sub + "\t" + "path" + "\t" + w)
                    j += 1

        if s <= piped or not runs_no_args(words):
            cands.extend(w for i, w in enumerate(words) if i not in is_val and MULTI.search(w))
            cands.extend(w[6:] for w in words if w.startswith("--pre="))   # one token, value glued on

MAX_DEPTH = 4

def span_views(s):
    # The inner text of every outermost dollar-paren span and backtick span outside single quotes,
    # then s with every span removed (an empty substitution glues its neighbours into one
    # word). An unclosed span runs to the end of s. Deeper spans are found on the next level.
    # A single-quoted span is never expanded here; if the quoted text is itself run (bash -c)
    # it is a multi-word candidate and its spans are found when that text is read.
    views, keep, cut, i, n, quote = [], [], 0, 0, len(s), ""
    while i < n:
        c = s[i]
        if quote == "\x27" or (c == "\x27" and not quote):
            quote = "\x27" if quote != c else ""
            i += 1
            continue
        if c == "\x22":
            quote = "" if quote else c
        if s.startswith("\x24(", i):
            k, level = i + 2, 1
            while k < n and level:
                level += {"(": 1, ")": -1}.get(s[k], 0)
                k += 1
            views.append(s[i + 2:k - 1] if level == 0 else s[i + 2:])
        elif c == "\x60":
            k = s.find("\x60", i + 1)
            k = n if k < 0 else k + 1
            views.append(s[i + 1:k - 1] if s[k - 1:k] == "\x60" and k - 1 > i else s[i + 1:])
        else:
            i += 1
            continue
        keep.append(s[cut:i])
        cut = i = k
    if views:
        views.append("".join(keep) + s[cut:])
    return views

src = strip_heredocs(sys.stdin.read())
try:
    toks = tokenize(prepare(src))
except ValueError:
    sys.exit(3)
out, cands = [], []
seg_rows(toks, out, cands)

# NESTED VIEWS: inner command strings are judged too, breadth first, each distinct text
# once. They only ADD rows to the top-level ones above. Spans are read before prepare(),
# because its continuation join eats a backtick. A text without git can emit no row and
# is skipped; one that would sit deeper than MAX_DEPTH is refused (exit 3).
seen, queue, q = {src}, [(t, 1) for t in span_views(src) + cands], 0
while q < len(queue):
    text, depth = queue[q]
    q += 1
    if text in seen or "git" not in text.lower():
        continue
    seen.add(text)
    if depth > MAX_DEPTH:
        sys.exit(3)
    body = strip_heredocs(text)
    prep = prepare(body)
    try:
        inner = tokenize(prep)
    except ValueError:
        inner = fallback_tokens(prep)
    more = []
    seg_rows(inner, out, more)
    queue += [(t, depth + 1) for t in span_views(body) + more]

# Written through the BINARY buffer on purpose. On Windows a text-mode stdout rewrites
# every newline as CR LF, and the CR then travels on the LAST FIELD of the line, so read
# hands bash an argument of dot-plus-carriage-return, which matches no path and no name.
# That fails OPEN — and only on Windows, and only from the second line onward, which is to
# say only for a call that runs more than one command. Caught by the suite on
# "git add ." followed by a commit.
sys.stdout.buffer.write("".join(line + "\n" for line in out).encode("utf-8"))
'
}

# The pre-filter is deliberately just "git": `git -C <dir> add …` does not put the verb
# next to the program name, and a filter that demanded that let the whole command past.
if printf '%s' "$norm" | grep -Eiq 'git'; then
    # Rows include commands nested in $( ), backticks and any multi-word argument
    # (bash -c, ssh, eval), up to MAX_DEPTH. A commit message and the arguments of echo,
    # printf, grep, rg and gh (NO_EXEC) with no pipe after them are not read as commands.
    # These shapes reach a shell unjudged. The list is what has been measured, not a set
    # anyone has closed — each entry below was found after the one above it, so treat a
    # shape that is absent as unlooked-for rather than absent:
    #   - text a shell reads on stdin: a heredoc body fed to bash;
    #   - NO_EXEC output put back through a substitution or a process substitution —
    #     `eval "$(echo "git add -A")"`, `echo "git add -A" > >(bash)`;
    #   - an option whose VALUE is a command — `git rebase --exec="git add -A"`,
    #     `git -c alias.x="!git add -A" x`, `ssh -o ProxyCommand="git add -A" host`;
    #   - a git word split by an expansion — `git${IFS}add -A`: bash splits that into
    #     git and its verb, while the raw text carries one word;
    #   - text one command writes to a file and the next command runs —
    #     `echo "git add -A" > x.sh; bash x.sh`. A redirect only: `tee` is not in
    #     NO_EXEC, so the same shape through a pipe is judged;
    #   - a construct inside the git word — `g""it add -A`, `g$''it add -A`: bash joins
    #     the pieces into git and runs it, while the raw text holds no git word for the
    #     pre-filter to find.
    args="$(staged_args)" || block "this command could not be read well enough to tell what it stages — refusing rather than guessing."

    while IFS="$(printf '\t')" read -r sub kind arg; do
        [ -n "$kind" ] || continue

        # Bare `git add -A`/`.` can sweep infra files in — nudge to explicit paths. The
        # allowlist never unlocks this one; it is the accidental sweep the rule exists for.
        # An ARGUMENT of add, so a commit message that merely says "-A" is not one.
        if [ "$sub" = add ] && { [ "$arg" = "-A" ] || [ "$arg" = "--all" ] || { [ "$kind" = path ] && [ "$arg" = "." ]; }; }; then
            block "git add -A / git add . can sweep in .claude/ or a memory file — stage explicit paths."
        fi
        [ "$kind" = path ] || continue

        # One lower-case, forward-slash copy for every comparison below, wrapped in slashes
        # so a whole COMPONENT can be matched with an ordinary glob.
        # SET1 is A-Z plus one literal backslash (tr spells that with two). ShellCheck
        # reads it as a quoting mistake; it is not.
        # shellcheck disable=SC1003
        low="/$(printf '%s' "$arg" | tr 'A-Z\\' 'a-z/')/"

        # Never, whatever the allowlist says: your machine, not the project.
        case "$low" in
            */.serena/*|*/.forgetful/*|*/memory.md/*)
                block "attempt to stage AI-infra path '$arg' — a fresh clone never needs it." ;;
        esac

        # .claude/ is a TWO-WAY sort, not a blanket block. agents/ and skills/ are generated
        # from this repo's CLAUDE.md and a fresh clone needs them; everything else under
        # .claude/ regenerates or belongs to your machine. Checked per argument, so one
        # allowed path in the command does not license the others beside it.
        case "$low" in
            */.claude/*)
                case "$low" in
                    */.claude/agents/*|*/.claude/skills/*) ;;
                    *) block "attempt to stage '$arg' — only .claude/agents/ and .claude/skills/ are product files; the rest regenerates or is yours." ;;
                esac ;;
        esac

        # CLAUDE.md: the one path the allowlist decides. On a repo you have answered `yes`
        # for, this file IS the product — nothing else will ever commit it, and without it a
        # fresh clone re-derives the stack, the chain and the Serena verdict from nothing.
        case "$low" in
            */claude.md/)
                allowlist_says claude-md || block "attempt to stage CLAUDE.md — this repo is not in ~/.claude/repo-allowlist with own-claude-md: yes." ;;
        esac
    done <<< "$args"
fi

exit 0
