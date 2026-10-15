#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash / PowerShell).
# Blocks irreversible or policy-violating git operations. Exit 2 = block.
#
# Wire in ~/.claude/settings.json under hooks.PreToolUse (see settings-hooks.snippet.json).

set -euo pipefail

block() { echo "BLOCKED by block-dangerous-git: $1" >&2; exit 2; }

# --- Reading the payload, and failing CLOSED ------------------------------------
# The harness passes the tool call as JSON on stdin. python parses it, not jq. jq is
# absent from most machines, and hand-rolling the two filters with sed/grep is not the
# cheap option it looks like: a real command arrives with its line breaks encoded as the
# two characters \n, and decoding those by hand re-opens the multi-line flatten bug this
# directory has already shipped once. The dependency is swapped, not removed — python is
# a dependency too, and it wins on being present and on being a real JSON reader.
#
# NO PARSER, OR A PARSE THAT ERRORS, IS A BLOCK. Claude Code treats every exit code
# other than 2 as a non-blocking error and lets the tool call through, so 127 is not a
# near-miss of 2 — it is the same class as success, and a hook that cannot read the
# command would allow it. A prompt was considered and rejected: `permissionDecision:
# "ask"` needs no parser and is the honest verdict, but "yes, and don't ask again" makes
# the approval durable, so one keystroke turns the guard off for good. A prompt is not a
# guardrail; it is trust with an extra keystroke. See README.md.
# The interpreter choice, the payload read, the allowlist lookup and the tokenizer's
# shared python live in _lib/common.sh beside this file. Found by parameter expansion,
# not dirname: no fork, and the no-python cases run on a PATH that may have lost dirname.
_lib="${BASH_SOURCE[0]//\\//}"
case "$_lib" in */*) _lib="${_lib%/*}/_lib/common.sh" ;; *) _lib="_lib/common.sh" ;; esac
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=_lib/common.sh
if ! . "$_lib" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    block "the shared hook library is missing or broken at $_lib — re-run the installer."
fi

[ "${#PY_LIST[@]}" -gt 0 ] || block "no python3 or python on PATH — this hook cannot read the command it exists to check."

hook_read_payload

# BOTH FIELDS ARE WRITTEN THROUGH THE BINARY BUFFER. This is the INPUT side of the very
# hazard the tokenizer's OUTPUT was hardened against (see the note at its final write). One
# end of a pipe was hardened and the other was not, and that is not a coincidence: no
# duplication note in this directory has ever listed parse() as a shared part, so nobody
# checked it. Two measured failures came out of the text-mode write:
#
#   1. CR DOUBLING, and it re-opened a fixed force push. On Windows a text-mode stdout
#      rewrites every "\n" as CR LF, so a payload that already carried CRLF reached
#      the tokenizer as "\r\r\n" — and python reads text with UNIVERSAL NEWLINES, where a
#      lone "\r" is a line ending too, so those three bytes arrive as TWO newlines
#      (measured: b"a\r\r\nb" reads back as "a\n\nb"). The line continuation join can only
#      eat one of the two, and the surviving newline orphans the flag exactly as the
#      unjoined continuation used to: `git push \` + CRLF + `--force`
#      returned 0 in an allowlisted repo — the force push ran, while the identical LF
#      payload blocked. A CRLF payload is what a Windows editor produces by default.
#      THE FIX BELONGS HERE AND NOWHERE DOWNSTREAM. Widening the continuation join to
#      accept a `\r` is the obvious-looking local fix and it was BUILT AND MEASURED as a
#      no-op: by the time the join runs, the read above has already turned the doubled CR
#      into newlines, so there is no CR left to match.
#   2. ENCODING. A text-mode write encodes with the machine's ANSI codepage (cp1252 on a
#      default Windows install), so any character outside it raised UnicodeEncodeError —
#      which `2>/dev/null` swallowed and `|| block` then reported as "the payload did not
#      parse as JSON". `echo 你好` exited 2 with that message; the payload parsed fine. It
#      also defeated the allowlist whenever the repo path contained such a character. A
#      false positive carrying a false diagnostic, in the hook that exists to remove false
#      positives. UTF-8 out, and the bytes bash reads are the bytes the payload carried.
#
# THE FIELDS ARE NOT PULLED OUT HERE ANY MORE. parse() used to sit at this point and run
# its own python process; it is now the head of payload_fields() further down, which is
# the same program as the tokenizer. The note above is unchanged and still describes the
# write that program makes, because it is still the same write — see the merge note at
# payload_fields() for why the two became one, and why the binary buffer matters MORE now
# rather than less. Nothing between here and there reads the payload.

# --- What does this command actually DO? ---------------------------------------
# Every rule below reads the ARGUMENTS of a git subcommand, never the command text.
#
# The text scan this replaces refused any command in which a dangerous string APPEARED at
# all. `echo "never run git push --force here"` was blocked. So was a commit message
# explaining why a flag is banned, a grep for it in docs/, and a heredoc writing a note
# about it — including, measurably, the notes for this very ticket (#117). And because a
# compound command dies whole, anything chained in FRONT of the mention never ran either.
#
# This program shares its helpers with staged_args() in _lib/common.sh, but not its
# reading of the arguments. The deliberate divergences, each a real decision and not a
# transcription slip:
#
#   1. It emits for EVERY subcommand, not a fixed SUB map. staged_args() does
#      `sub = SUB.get(...)` and `continue`s on a miss, i.e. a subcommand it does not know
#      is silently DROPPED. That is a fail-open class, and this hook does not import it.
#   2. It emits a row for the subcommand itself, `<sub>\tsub\t<sub>`, because a bare
#      `git push` with no arguments must still be detectable. staged_args() never needed
#      that (`git add` with no arguments stages nothing).
#   3. VAL is read with `.get(sub, ())`, never `VAL[sub]`. staged_args() can index
#      directly because its SUB and VAL have the same keys; with divergence 1 that would
#      be a KeyError on every `git status` — python dies, the caller blocks, and the guard
#      refuses ordinary commands.
#   4. Percent-paren spans are stripped before tokenizing. `(` and `)` are separators, and
#      they split INSIDE a word: `--format=%(refname)` becomes three tokens, so
#      `git branch --format=%(refname) -D feature` splits into segments and the segment
#      carrying the force flag starts with `-D`, not `git` — silently dropped, ALLOW.
#      Measured. The span is bounded so it CANNOT cross a command separator or whitespace:
#      the first cut of this used `[^)]*`, which ran from a `%(` in one command to the
#      first `)` anywhere later and swallowed whole commands in between —
#      `echo '%(' ; git branch -D feature ; echo ')'` collapsed to `echo '%'` and the
#      branch delete was never seen. A format placeholder never contains a separator or a
#      space, so forbidding them inside the span costs nothing and closes that hole.
#   5. A backtick that is not before a newline is a separator: it is command substitution,
#      and `` `git branch -D f` `` is otherwise a single token that is not `git`.
#      staged_args() must not do this: there the split moves a path word out of its add
#      segment.
#   6. Option words are read through deb(), no case is folded beyond the subcommand, and
#      the JSON is read in this same program. Each is noted below.
#
# The forward scan over every git word in a segment is shared with staged_args(), and so is
# word(), through which the program word and the verb — never a path — are read. It
# blocks an unquoted mention outside an allowlisted repo (`man git push`, `echo git push
# origin main`); a quoted mention is one token whose basename is not `git`.
#
# NO case folding here. block-infra-staging.sh folds case because Windows resolves
# .Serena and .serena to one directory; this hook must NOT, because `-d` and `-D` are
# opposite operations. The subcommand is lower-cased (git accepts no other spelling);
# option tokens keep their case, but they are emitted with the backslash and dollar-sign
# escapes REMOVED — the spelling bash will actually hand git. See deb() for why that view
# is taken for options only and never for a path.
#
# A command that will not tokenize is a BLOCK, exactly as an unreadable payload is.
# ONE PYTHON PROCESS PER INVOCATION, and this is where the second one went. Reading the
# fields out of the JSON and tokenizing the command used to be two separate programs, so
# an ordinary git command paid two process spawns and a push paid three — on the one
# platform where a process spawn is the most expensive thing a hook does. They are one
# program now: it reads the payload once, and returns everything the shell below needs.
#
# THE THREE FIELDS COME BACK IN ONE STRING, separated by a record separator (\x1e), and
# the command comes LAST on purpose. The command is the only field that can itself contain
# newlines, so it has to be the one that is "everything after the last separator"; a
# line-per-field format would have been ambiguous for exactly that field.
#
# STILL WRITTEN THROUGH THE BINARY BUFFER, for both of the measured reasons in the note
# further up — and the merge makes the first of them REACHABLE where it was not. A
# text-mode stdout rewrites every \n as CR LF, and the CR travels on the last field of the
# line; the old parse() emitted a single field with no newline in it at all, so it had no
# line for that to happen on. This program emits several. Do not take the buffer off.
#
# NO GIT, NO TOKENIZER. The early exit below is a pre-filter: an ordinary non-git Bash
# call does not pay for tokenizing, and a non-git command that will not tokenize is not
# suddenly a block. It is expressed once, here, and the shell branches on whether any
# rows came back rather than testing the command text a second time.
payload_fields() { # prints cwd \x1e <tokenized rows> \x1e command; exit 3 = unparsable
    # shellcheck disable=SC2016  # this argument is a python program, not shell
    py_run "$HOOK_PAYLOAD" "$HOOK_PY_SHARED"'
import json, re, shlex, sys

# Bytes decoded as UTF-8. A text-mode read uses the Windows code page, and a byte that page
# has no character for comes back as a surrogate, which the UTF-8 write below refuses.
_d = json.loads(sys.stdin.buffer.read())
_ti = _d.get("tool_input") or {}
CWD = _d.get("cwd") or ""
CMD = _ti.get("command") or _ti.get("script") or ""

def emit(rows):
    sys.stdout.buffer.write((CWD + "\x1e" + rows + "\x1e" + CMD).encode("utf-8"))

if not may_be_git(CMD):
    emit("")
    sys.exit(0)

# Options whose value is a message, a mode, a ref or a file to READ — never a flag we
# judge. Options that may OMIT their value (--force-with-lease, --signed, --contains,
# --no-contains, --merged, --no-merged) are deliberately absent: skipping the word after
# one of those would swallow a real argument, and the word swallowed could be -D. That
# fails OPEN, which is the one direction this file may not fail in.
VAL = {
    "add": {"--chmod", "--pathspec-from-file"},
    "commit": {"-m", "--message", "-F", "--file", "-C", "--reuse-message",
               "-c", "--reedit-message", "--author", "--date", "--cleanup",
               "--squash", "--fixup", "-t", "--template", "--trailer",
               "--pathspec-from-file"},
    "branch": {"-u", "--set-upstream-to", "--sort", "--format", "--points-at"},
    "clean": {"-e", "--exclude"},
    "push": {"--repo", "--receive-pack", "--exec", "-o", "--push-option"},
    "reset": {"--pathspec-from-file"},
}

def deb(w):
    # WHAT BASH WILL HAND GIT, used to decide OPTION-NESS and nothing else.
    #
    # lex.escape is set to "" below so a backslash stays a literal character and a Windows
    # path survives tokenizing. That decision is right and it stays — but bash removes the
    # backslash before git ever sees the word, so a flag written with one arrived here as
    # a token that did not start with a hyphen, was filed as a path, and every rule is
    # gated on kind = opt. No rule ever looked at it. Measured with a git shim on PATH
    # recording the real argv (#117, fifth pass): four force-flag spellings on push all
    # EXECUTED while this hook returned 0 in an allowlisted repo, where letting the push
    # itself through is the whole point and stopping the flag is the only job left.
    # The dollar-sign quoting forms are the same hole by another route: shlex leaves the
    # dollar glued to the front of the word, bash does not pass it on. That one is not an
    # evasion trick, it is ordinary quoting somebody may type by accident.
    #
    # THIS IS NOT lex.escape SET TO A BACKSLASH, and that is the point. Doing it in the
    # tokenizer would rewrite every PATH too, which is exactly what the empty escape
    # exists to prevent, here and identically in staged_args() in _lib/common.sh.
    # A path word is still emitted EXACTLY as it was written; only the option decision and
    # the option label read through the escape. Both directions are cases in test-hooks.sh.
    #
    # SCOPE, stated so the next reader does not read the omission as an oversight: this is
    # applied to the ARGUMENT loop only. The loop that skips the options git itself takes
    # BEFORE the subcommand still tests the raw word, so an escaped GLOBAL option hides the
    # subcommand behind it — measured 0 in both allowlist states on master and here alike,
    # i.e. not a regression of this branch, and it belongs with the other option-spelling
    # gaps on #141 rather than in a fix scoped to what this branch moved.
    return w.replace("\\", "").lstrip("$")

def prepare(src):
# A LINE CONTINUATION is ONE command written over two lines, not two commands, so it has
# to be joined BEFORE any newline becomes a separator. Splitting there put the flag in a
# segment of its own, where no rule judges it: a git push, a trailing backslash, a
# newline, then --force returned 0 while the one-line form returned 2 — and in a repo
# allowlisted for push, that IS the force push running.
# ORDER MATTERS: this must come before the newline replacement below.
# A trailing backtick is a PowerShell continuation AND an unterminated bash command
# substitution; joining treats both as one segment, which still contains a git word and
# is still judged by the forward scan, so the ambiguity resolves fail-CLOSED.
#
# A backtick NOT followed by a newline is a different story, and the ambiguity is resolved
# in favour of BASH: the replacement below makes it a separator, because in bash it opens
# command substitution. In PowerShell it is the escape character, so a git push, a
# backtick and then --force on ONE line is a real force push whose flag lands in a segment
# of its own and is not judged (measured 2 on the text scan this hook replaces, 0 here,
# and only where the repo is allowlisted for push, as with every other orphaned flag). It
# is left that way deliberately: nobody escapes a hyphen, the payload does say which shell
# it came from, and a per-shell tokenizer is a much larger change than #117. Recorded so
# the next reader knows this is a decision and not an oversight.
#
# THE NEWLINE CLASS IS GREEDY, and the + is load-bearing. strip_heredocs above turns \r\n
# and a lone \r alike into \n — exactly as the universal-newline text read that used to
# feed this program did, which is why taking that read away changed nothing here — so a
# payload carrying \r\r\n, \n\r or \r\r arrives as TWO newlines (measured: b"a\r\r\nb"
# reads back as "a\n\nb"). A single-\n join eats one of the two and the surviving newline
# orphans the flag exactly as no join at all did: git push, a backslash, \r\r\n, --force
# returned 0 in an allowlisted repo while the plain CRLF form returned 2. parse() was
# fixed to stop MANUFACTURING that doubling; this makes the join proof against one that
# arrives in the payload, and hardening one end of a pipe while leaving the other narrow
# is the mistake the note at parse() exists to describe.
# NOTE: no apostrophes in this python program — a single quote here ends the shell string.
    src = re.sub(r"[\\\x60][ \t]*\n+", " ", src)

# Divergence 4 — see the note above. Runs BEFORE tokenizing, so the placeholder never
# reaches the punctuation splitter. The character class forbids whitespace and every
# command separator, so the span cannot run out of one command and into the next.
    src = re.sub(r"%\([^)\s;&|]*\)", "%", src)

    src = split_ws(src)

# Newlines become an explicit separator BEFORE tokenizing: shlex treats one as plain
# whitespace, which would run two commands together into one segment. A backtick becomes
# a separator too (divergence 5): it is command substitution, and shlex does not know it.
    return src.replace("\n", " ; ").replace("\x60", " ; ")

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
                cands.extend(seg[k + 1:k + 2])    # still a candidate: bash <<< "git push"
                k += 2
                continue
            words.append(seg[k])
            k += 1
        is_val = set()                            # indexes in words consumed as a VAL value

        j = 0                                     # leading VAR=value assignments
        while j < len(words) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[j]):
            j += 1
        # The git program may sit behind a wrapper (sudo, env, time, command, xargs) or a
        # shell keyword (then, do), so scan forward for it rather than requiring word 0.
        # An unrecognised word is SKIPPED, never a reason to give up on the segment.
        # EVERY git in the segment is judged: in sudo -u git git push --force the first git
        # is the VALUE of -u. An extra row can only make a rule fire.
        p = j
        while p < len(words):
            if not is_git(words[p]):
                p += 1
                continue
            j = p + 1
            p += 1

            while j < len(words) and words[j].startswith("-"):
                j += 2 if words[j] in GLOBAL_VAL else 1
            if j >= len(words):
                continue
            sub = word(words[j])                  # divergence 1: every subcommand, no SUB map
            out.append(sub + "\t" + "sub" + "\t" + sub)   # divergence 2: a bare push counts

            j += 1
            vals = VAL.get(sub, ())               # divergence 3: .get, never VAL[sub]
            rest_are_paths = False
            while j < len(words):
                w = words[j]
                d = deb(w)                        # option-ness only — see deb(); paths keep w
                if not rest_are_paths and d == "--":
                    rest_are_paths = True
                    j += 1
                elif not rest_are_paths and d.startswith("-") and d != "-":
                    out.append(sub + "\t" + "opt" + "\t" + d)
                    if d in vals:
                        is_val.add(j + 1)
                        j += 2
                    else:
                        if d.split("=", 1)[0] in vals or (d[1:2] != "-" and d[:2] in vals):
                            is_val.add(j)         # --message=text or -mtext: value inline
                        j += 1
                else:
                    out.append(sub + "\t" + "path" + "\t" + w)
                    j += 1

        if s <= piped or not runs_no_args(words):
            cands.extend(w for i, w in enumerate(words) if i not in is_val and MULTI.search(w))
            cands.extend(w[6:] for w in words if w.startswith("--pre="))   # one token, value glued on

src = strip_heredocs(CMD)
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
seen, queue, q = {src}, [(t, 1) for t in span_views(src) + alt_views(src) + cands], 0
while q < len(queue):
    text, depth = queue[q]
    q += 1
    if text in seen or not may_be_git(text):
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
    queue += [(t, depth + 1) for t in span_views(body) + alt_views(body) + more]

# Written through the BINARY buffer on purpose. On Windows a text-mode stdout rewrites
# every newline as CR LF, and the CR then travels on the LAST FIELD of the line, so read
# hands bash an argument with a carriage return glued to it, which matches nothing. That
# fails OPEN — and only on Windows, and only from the second line onward, which is to say
# only for a call that runs more than one command.
#
# THE OTHER END OF THIS PIPE IS parse(), and it shipped text-mode while this end did not —
# see the long note there. Same hazard, same platform, opposite direction; hardening one
# end and not the other is what let a fixed force push run again under a CRLF payload.
emit("".join(line + "\n" for line in out))
'
}

# The one read of the payload, and the one place this hook can fail to read it. Three
# outcomes, three different things to say:
#   0  the payload parsed and the command tokenized (possibly to nothing)
#   3  python ran, and shlex refused the command — a command we cannot read is a block,
#      exactly as an unreadable payload is
#   *  no candidate interpreter could run the program at all, or the payload is not JSON.
#      py_tried then asks each candidate whether it is python, so the message can tell
#      "your payload is malformed" apart from "the python3 on your PATH is not python".
_rc=0
fields="$(payload_fields)" || _rc=$?
case "$_rc" in
    0) ;;
    3) block "this command could not be read well enough to tell what it does — refusing rather than guessing. Rewrite it with plain quoting (no nested, escaped or unbalanced quotes), or ask the user to run it." ;;
    *) block "the payload did not parse as JSON — refusing to guess what this command does. $(py_tried)" ;;
esac

# Split on the record separator. cwd first, tokenized rows second, the command last —
# see the format note at payload_fields().
payload_cwd="${fields%%$'\x1e'*}"
_rest="${fields#*$'\x1e'}"
args="${_rest%%$'\x1e'*}"
cmd="${_rest#*$'\x1e'}"

# Normalize for matching. Newlines and \r become ';' so a CRLF payload behaves the same as
# an LF one and a separate LINE stays a separate command.
#
# NOTHING IN THIS HOOK ANCHORS ON THAT SEPARATOR ANY MORE. An earlier version of this
# comment said "the patterns below anchor on a start-of-string or a [;&|] separator" —
# they did then, they do not now, and the file contradicted itself about it. $norm has
# exactly two readers left: the --no-verify and --no-gpg-sign rules, and both are bare
# unanchored substrings (see the note at those rules). The `git` pre-filter used to be a
# third; it now lives inside payload_fields(), and the shell branches on whether any rows
# came back. The git rules read the tokenized rows instead, which do their own newline
# handling.
#
# PARAMETER EXPANSION, NOT `tr`. This was two processes per invocation for a transform
# bash can do in the shell it is already running, and on Windows a spawn costs more than
# the whole rest of this hook. The squeeze loop is `tr -s ' '`: runs of spaces collapse to
# one. The line is kept at all, rather than dropped, because block-secret-staging.sh
# computes the same $norm, with
# `printf | tr '\r\n' ';;' | tr -s ' '`: the TRANSFORM is equivalent — same output
# on every input, including runs of spaces, the all-spaces string and the empty one — and
# only the FORM differs. The divergence is deliberate and means nothing more than this:
# this hook is the hot path that was measured, so it is the one that got the builtin.
norm="${cmd//[$'\r\n']/;}"
# A ${v#*…} test is quadratic in bash; this glob test is not.
while [[ $norm == *"  "* ]]; do
    norm="${norm//  / }"
done

# Where a push lands: the part of a refspec after its `:`, less a leading `+` and
# `refs/heads/`. HEAD and @ are the checked-out branch, read once and only when needed.
head_branch=""
push_target_check() { # <refspec | --all | --mirror | --branches> — blocks a push that lands on main, master or develop
    local ref="${1#+}" d
    # The empty refspec `:` and these three options push every branch, trunk included,
    # without naming one.
    case "$ref" in
        :|--all|--mirror|--branches)
            allowlist_says trunk-push "$payload_cwd" || \
                block "git push $1 reaches every branch, main, master and develop included. Push a feature branch by name, or set the 4th field (trunk-push) to yes for this repo in ~/.claude/repo-allowlist."
            return 0 ;;
    esac
    ref="${ref##*:}"
    ref="${ref#refs/heads/}"
    case "$ref" in
        HEAD|@)
            if [ -z "$head_branch" ]; then
                d="$payload_cwd"
                [ -n "$d" ] && [ -d "$d" ] || d="$PWD"
                head_branch="$(git -C "$d" symbolic-ref --short -q HEAD 2>/dev/null || true)"
            fi
            ref="$head_branch" ;;
    esac
    case "$ref" in
        main|master|develop)
            allowlist_says trunk-push "$payload_cwd" || \
                block "git push to $ref — a trunk branch. Push a feature branch, or set the 4th field (trunk-push) to yes for this repo in ~/.claude/repo-allowlist." ;;
    esac
}

# --- Hard blocks ---------------------------------------------------------------
# The pre-filter never asks for the verb: `git -C <dir> push` does not put the verb
# next to the program name, and a filter that demanded that let the whole command past.
# It is safe ONLY because the two raw-text rules further down run OUTSIDE it — see there.
#
# IT IS NOW EXPRESSED ONCE, inside payload_fields(), and this line reads the RESULT rather
# than testing the command text a second time. Two copies of "does this mention git" in
# two languages is a shared contract that can drift, and the drift would be silent: the
# rows are empty exactly when the tokenizer was not run or found no git invocation, which
# is the same set of commands the text filter used to let through to an empty $args.
if [ -n "$args" ]; then
    # Rows include commands nested in $( ), backticks and any multi-word argument
    # (bash -c, ssh, eval), up to MAX_DEPTH. A commit message and the arguments of echo,
    # printf, grep, rg and gh (NO_EXEC) with no pipe after them are not read as commands.
    # These shapes reach a shell unjudged. The list is what has been measured, not a set
    # anyone has closed — each entry below was found after the one above it, so treat a
    # shape that is absent as unlooked-for rather than absent:
    #   - text a shell reads on stdin: a heredoc body fed to bash;
    #   - NO_EXEC output put back through a substitution or a process substitution —
    #     `eval "$(echo "git push --force")"`, `echo "git push --force" > >(bash)`;
    #   - an option whose VALUE is a command — `git rebase --exec="git push --force"`,
    #     `git -c alias.x="!git push --force" x`, `ssh -o ProxyCommand="git push" host`;
    #   - a git word split by an expansion whose whitespace value this payload does not
    #     show — `git${IFS:0:1}push --force`, `git$(printf " ")push --force`;
    #   - text one command writes to a file and the next command runs —
    #     `echo "git push --force" > x.sh; bash x.sh`. A redirect only: `tee` is not in
    #     NO_EXEC, so the same shape through a pipe is judged.
    push_checked=""
    push_open=""    # a push with no refspec seen yet: it lands on the checked-out branch
    push_pos=0
    while IFS="$(printf '\t')" read -r sub kind arg; do
        [ -n "$sub" ] || continue

        # A `sub` row starts a git invocation, so it closes the push before it.
        if [ "$kind" = sub ]; then
            [ -z "$push_open" ] || push_target_check HEAD
            push_open=""
            if [ "$sub" = push ]; then
                push_open=1
                push_pos=0
            fi
        fi

        # git push — the human pushes manually, unless this repo is allowlisted for it.
        # The `sub` row is why a bare `git push` with no arguments is caught. Asked once
        # per command.
        if [ "$sub" = push ] && [ -z "$push_checked" ]; then
            push_checked=1
            allowlist_says push "$payload_cwd" || \
                block "git push is not allowed here — this repo is not in ~/.claude/repo-allowlist with push: yes. Push manually, or add a line."
        fi

        # A push's first positional is the remote; every one after it is a refspec.
        if [ "$sub" = push ] && [ "$kind" = path ]; then
            push_pos=$((push_pos + 1))
            if [ "$push_pos" -gt 1 ]; then
                push_open=""
                push_target_check "$arg"
            fi
        fi

        # Bare `git add -A` / `git add .` sweeps in whatever is lying around, .claude/ and
        # memory files included. The allowlist never unlocks this one. `-A` and `--all`
        # arrive as options, `.` as a path — and as an ARGUMENT of add, so a commit
        # message that merely mentions "-A" is not one.
        if [ "$sub" = add ] && { [ "$arg" = "-A" ] || [ "$arg" = "--all" ] || { [ "$kind" = path ] && [ "$arg" = "." ]; }; }; then
            block "git add -A / git add . — stage explicit paths only (avoids committing AI-infra files)."
        fi

        [ "$kind" = opt ] || continue

        # A "short cluster" is a `-` NOT followed by another `-`, so `-fd` is f and d
        # while `--format` and `--delete` are single long options. That distinction is
        # what keeps `--format` out of the f test, and it is expressed here by testing
        # `--*` first and letting it fall through to nothing.
        case "$sub" in
            reset)
                if [ "$arg" = "--hard" ]; then
                    block "git reset --hard"
                fi ;;
            clean)
                case "$arg" in
                    --force*) block "git clean -f" ;;
                    --*)      ;;
                    -*[fF]*)  block "git clean -f" ;;
                esac ;;
            # --- git branch: block FORCE, allow SAFE (#115) -------------------------
            # This was one pattern, `git +branch +-D`, and it was wrong in both
            # directions.
            #
            # Too strict: it folded case, and `-d` is the OPPOSITE of `-D` — it refuses a
            # branch with unmerged commits. So the safe cleanup was blocked and then
            # reported as a force delete. That is the bug in #115.
            #
            # Too loose, and the worse half: `-D` is one of eight spellings git accepts
            # for the same destructive operation. Measured on the unfixed hook, these all
            # sailed through —
            #   git branch --delete --force · --force --delete · -d --force · -fd · -df
            #   git branch -f <name> <start> · --force <name> <start>  (force-MOVES a ref)
            # — so the guardrail stopped exactly one of them and let seven past.
            #
            # The rule is therefore about FORCE, not about delete: on `git branch`, any
            # force flag is destructive, whether it deletes an unmerged branch or moves a
            # ref over existing history.
            #
            #   allowed   -d  --delete  -a  -r  -m  -v  --list  --format=…
            #   blocked   any SHORT cluster containing D or f, and --force in any position
            #
            # Case-SENSITIVE on purpose, and the reason payload_fields() folds nothing but the
            # subcommand: `-D` blocks, `-d` does not. Every spelling above is a case in
            # templates/hooks/test-hooks.sh, in BOTH directions — the missing allow-case
            # is why this survived so long.
            branch)
                case "$arg" in
                    --force*) block "git branch --force — use --delete on its own, which refuses unmerged branches" ;;
                    --*)      ;;
                    -*[Df]*)  block "git branch force delete/move (-D, -f, -fd, -df) — use -d, which refuses unmerged branches" ;;
                esac ;;
            # Prefix, not equality: `--force-with-lease` is still a force push, and an
            # `= --force` test would silently stop blocking it. There is a case for that.
            push)
                case "$arg" in
                    --force*) block "git push --force" ;;
                    --all|--mirror|--branches) push_target_check "$arg" ;;
                    # With no refspec, --tags pushes the tags and no branch.
                    --tags)   push_open="" ;;
                    --*)      ;;
                    -*[fF]*)  block "git push --force" ;;
                esac ;;
        esac
    done <<< "$args"
    [ -z "$push_open" ] || push_target_check HEAD
fi

# --- Two rules that are deliberately NOT tokenized ------------------------------
# `--no-verify` and `--no-gpg-sign` are matched as raw TEXT, with no `git` anchor, and
# OUTSIDE the pre-filter above — on purpose, and this is the whole reason the pre-filter
# is safe. Re-expressing them as git argument rules would scope them to git and stop
# blocking `npm publish --no-verify`, which bypasses hooks just as thoroughly. That is a
# behaviour NARROWING nobody asked for: none of the false positives this hook was fixed
# for (#117) involve these two flags. Accepted cost, chosen with eyes open — a commit
# message that merely QUOTES `--no-verify` still false-positives. The FP class survives
# for exactly these two flags, by decision, not by oversight.
#
# `grep -Eiq` was CASE-INSENSITIVE, and these are bash substring tests now — two more
# processes off every single invocation, git or not. The `,,` is therefore load-bearing
# and not a tidy-up: without it `--No-Verify` stops being blocked, which is a security
# guardrail quietly narrowing. Both patterns below are already lower case.
[[ ${norm,,} == *--no-verify* ]]   && block "--no-verify (bypasses hooks)"
[[ ${norm,,} == *--no-gpg-sign* ]] && block "--no-gpg-sign"

exit 0
