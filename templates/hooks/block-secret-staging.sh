#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks staging/committing credential-shaped paths, and obvious token literals anywhere
# in the command. Exit 2 = block.
#
# WHY THIS EXISTS, since it is not general hygiene: the push block was quietly doing
# secret-leak protection. While a human ran every push, a committed key was survivable —
# you see the diff. Once a repo is allowlisted for push (see repo-allowlist.sample),
# nobody does. The failure is concrete: the agent writes .env with a live key, commits,
# pushes; the repo is private so it feels fine; six months later you make it public to
# show someone and the key is in the history.
#
# WHAT IT CANNOT DO: it sees the command, not the file. `git add config.yml` with a
# password inside passes. This blocks credential-shaped NAMES and pasted-in literals —
# it is not a secret scanner, and calling it one would be the kind of guardrail that
# reports success while guarding nothing.

set -euo pipefail

block() { echo "BLOCKED by block-secret-staging: $1" >&2; exit 2; }

# python parses the payload and a payload it cannot read is a BLOCK, never a pass.
# Duplicated from block-dangerous-git.sh, deliberately — the reasoning for all of it (why
# python and not jq or sed, why 127 is the same class as success, why a WindowsApps
# python3 goes to the END of the list and is never dropped, and why nothing is probed
# until we are refusing anyway) is in the notes there. The code below is byte-identical in
# all seven hooks and in test-hooks.sh. This hook needs one filter, so it has no `parse`
# helper.
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
cmd="$(py_run "$payload" '
import json, sys
ti = json.load(sys.stdin).get("tool_input") or {}
# The buffer, not text mode: a text-mode write turns every \n into \r\n on Windows, and
# tr maps both characters, so one newline would leave TWO separators in the normalised
# command below instead of one, and no whitespace at all where the command had a line
# continuation. The sibling hooks write through the buffer for the same reason.
sys.stdout.buffer.write((ti.get("command") or ti.get("script") or "").encode("utf-8"))
')" || block "the payload did not parse as JSON — refusing to guess whether this command carries a credential. $(py_tried)"
norm="$(printf '%s' "$cmd" | tr '\r\n' ';;' | tr -s ' ')"

# Token literals: blocked wherever they appear, including on a read command. A live key
# on a command line has already leaked — into shell history and into the transcript —
# whether or not git ever sees it, so "was this a write?" is the wrong question to ask.
# The cost is a false positive on something like `grep -r AKIA .`, which is rare and
# loud; the alternative is a pattern that has to guess which commands write.
for pat in \
    'sk-[A-Za-z0-9_-]{20,}' \
    'ghp_[A-Za-z0-9]{20,}' \
    'github_pat_[A-Za-z0-9_]{20,}' \
    'xox[baprs]-[A-Za-z0-9-]{10,}' \
    'AKIA[0-9A-Z]{16}' \
    'AIza[0-9A-Za-z_-]{30,}' \
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
do
    # -e is load-bearing: without it a pattern starting with `-` is parsed as options and
    # grep exits 2 on usage, which this `if` reads as "no match" and waves the command
    # through. The PRIVATE KEY pattern below is exactly that shape, and it failed open for
    # as long as it has existed. Found by running the hook, not by reading it.
    if printf '%s' "$norm" | grep -Eq -e "$pat"; then
        block "a credential literal matching /$pat/ is in this command — do not put it on a command line at all."
    fi
done

# Credential-shaped paths: only on git add / commit / stage, and only over the WORDS that
# verb is handed. Which words those are is a tokenizer's answer, not a regex's.
#
# staged_args() below is a copy of block-infra-staging.sh's — the note above that copy
# lists what must stay in step across every copy of it. One thing is added here, because
# this hook judges the path word itself: glued_view(), so a path written inside an unquoted
# substitution is still read (`git add $(echo .env)`).
staged_args() { # prints "<subcommand>\t<opt|path>\t<word>" per argument; exit 3 = unparsable
    # shellcheck disable=SC2016  # this argument is a python program, not shell
    py_run "$cmd" '
import re, shlex, sys

SUB = {"add": "add", "stage": "add", "commit": "commit"}

# The options git itself takes BEFORE the subcommand. These take a separate value.
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

# A quote or a dollar can sit INSIDE the word git, and shlex leaves the dollar glued to the
# token it produces. Squashing those characters out only ever DELETES, so a git that was
# there is still there: every test on a squashed string widens what gets inspected, and can
# never narrow it. The decision of what to block stays the tokenizer.
_SQUASH = {ord(c): None for c in (chr(34), chr(39), "$", chr(92))}

def squash(s):
    return s.translate(_SQUASH).lower()

# A name that an assignment EARLIER IN THE SAME PAYLOAD gives a whitespace-only value.
_WS_ASSIGN = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)=([\"" + chr(39) + r"])[ \t]+\2")

def split_ws(src):
    # An expansion that yields whitespace is a word SPLIT when bash runs the command, while
    # a quote pair only glues. That is the whole difference between git${IFS}add, which
    # stages, and git""add, which is the single word gitadd and stages nothing — so a
    # literal space here, and nothing else touched, is what lets the tokenizer see it.
    # Two shapes are closed: $IFS, and a name this payload assigns a whitespace-only value.
    # NOT closed: ${IFS:0:1}, $(printf " "), a dollar-quoted tab, and a name set in an
    # earlier tool call — the hook only ever sees one command.
    names = {"IFS"} | {m.group(1) for m in _WS_ASSIGN.finditer(src)}
    alt = "|".join(sorted(names))
    return re.sub(r"\$\{(?:" + alt + r")\}|\$(?:" + alt + r")(?![A-Za-z0-9_])", " ", src)

# A brace expansion or a substitution span can expand to NOTHING, so bash hands git the
# same word with or without it: git${x} add, git add$(true) .env and git`true` add are all
# git add. Only the program word and the verb are read through word() — dropping a span
# from a PATH changes the text the path rules match and turns a block into an allow.
_SPANS = re.compile(r"\$\{[^}]*\}|\$\([^)]*\)|\x60[^\x60]*\x60")

def word(w):
    return squash(_SPANS.sub("", w))

def prepare(src):
# A LINE CONTINUATION is ONE command written over two lines, so it is joined BEFORE any
# newline becomes a separator; splitting there puts the rest of the command, paths
# included, in a segment of its own that no rule reads. Same regex as block-dangerous-git.sh
# (see the note there for the greedy newline class and the trailing-backtick ambiguity).
# Only the JOIN is shared: a backtick elsewhere is NOT made a separator here, because that
# split would move a path word out of its add segment and turn a block into an allow.
    src = re.sub(r"[\\\x60][ \t]*\n+", " ", src)

    src = split_ws(src)

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
            # word() runs only AFTER the separator is normalised: it drops backslashes, and
            # doing it first would swallow the separator of a Windows path.
            if word(words[p].replace("\\", "/").rsplit("/", 1)[-1]) not in ("git", "git.exe"):
                p += 1
                continue
            j = p + 1
            p += 1

            while j < len(words) and words[j].startswith("-"):
                j += 2 if words[j] in GLOBAL_VAL else 1
            if j >= len(words):
                continue
            sub = SUB.get(word(words[j]))
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

# The text of a substitution, glued back where its span stood. An UNQUOTED $( ) splits into
# tokens of its own, because shlex reads the open paren as a segment separator, so a path
# written inside one lands in no segment and no rule ever reads it. Reinstating the text is
# evidence, not evaluation: it is what the span was written to produce. It only ADDS a view.
def glued_view(s):
    views = span_views(s)
    g = s
    for inner in views[:-1]:
        g = g.replace("$(" + inner + ")", inner, 1).replace("\x60" + inner + "\x60", inner, 1)
    return [g] if g != s else []

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
seen, queue, q = {src}, [(t, 1) for t in span_views(src) + glued_view(src) + cands], 0
while q < len(queue):
    text, depth = queue[q]
    q += 1
    if text in seen or "git" not in squash(text):
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
    queue += [(t, depth + 1) for t in span_views(body) + glued_view(body) + more]

# Written through the BINARY buffer on purpose. On Windows a text-mode stdout rewrites
# every newline as CR LF, and the CR then travels on the LAST FIELD of the line, so read
# hands bash an argument of dot-plus-carriage-return, which matches no path and no name.
# That fails OPEN — and only on Windows, and only from the second line onward, which is to
# say only for a call that runs more than one command. Caught by the suite on
# "git add ." followed by a commit.
sys.stdout.buffer.write("".join(line + "\n" for line in out).encode("utf-8"))
'
}

# The left edge of a path INSIDE one word, as a COMPLEMENT class: wpath lists the
# characters that CONTINUE a word, so a construct nobody listed lands outside the list and
# blocks, instead of walking past a list of separators somebody had to think of first.
# Quotes, $, braces, parens, backtick and backslash are deliberately not word characters:
# each can expand to nothing, so `git add ${x}.env` is really `git add .env`. wpath drops
# `/`, since `/` separates path components and dir/.env really is .env.
wpath='A-Za-z0-9_.,:=@%+^~!?*#['
pbrk='(^|[^]'"$wpath"'-])'
# The pre-filter is deliberately just "git": `git -C <dir> add …` does not put the verb
# next to the program name, and a filter that demanded that let the whole command past.
# A quote or a dollar can sit INSIDE the word git, so the test runs over a copy with those
# squashed out. Squashing only ever DELETES characters, so a git that was there is still
# there and this can only widen what reaches the tokenizer. The `,,` is load-bearing: drop
# it and the filter stops being case-insensitive, which is a guardrail quietly narrowing.
sq=${norm//'"'/}
sq=${sq//"'"/}
sq=${sq//'$'/}
sq=${sq//"\\"/}
if [[ ${sq,,} == *git* ]]; then
    args="$(staged_args)" || block "this command could not be read well enough to tell what it stages — refusing rather than guessing."

    # The subcommand does not change the answer here: add, stage and commit all put the
    # path in the repo. Only path rows are read — an option word is never a path.
    while IFS="$(printf '\t')" read -r _ kind arg; do
        [ "$kind" = path ] || continue

        # `.env.example` and friends are the committed TEMPLATE — the one file in this
        # family that is supposed to be in the repo. Remove those tokens before matching
        # rather than trying to write a not-followed-by pattern, which ERE cannot express.
        scan="$(printf '%s' "$arg" | sed -E 's/\.env\.(example|sample|template|dist)//gI')"
        for pat in \
            "$pbrk"'\.env($|[^A-Za-z0-9_-])' \
            '\.env\.(local|prod|production|staging|dev)\b' \
            '\.(pem|p12|pfx|jks|keystore|ppk)\b' \
            'id_(rsa|dsa|ecdsa|ed25519)\b' \
            "$pbrk"'(credentials|secrets?|service-account)\.(json|ya?ml|toml|ini)\b' \
            '\.npmrc\b' \
            '\.pypirc\b' \
            '\.netrc\b'
        do
            if printf '%s' "$scan" | grep -Eiq -e "$pat"; then
                block "attempt to stage a credential-shaped path matching /$pat/ — put it in .gitignore instead."
            fi
        done
    done <<< "$args"
fi

exit 0
