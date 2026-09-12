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
# --- CHOOSING THE INTERPRETER, AND SAYING WHICH ONE -----------------------------
# DUPLICATED VERBATIM into all six hooks and into test-hooks.sh, on purpose, exactly as
# the allowlist lookup and the argument tokenizer below are. A shared file cannot work
# here: install-lib.py discovers every templates/hooks/*.sh and installs each one as a
# hook, so a helper file is either a phantom seventh hook or never installed at all — and
# the hooks that ship are standalone copies in ~/.claude/hooks/ with nothing to source.
#
# ORDER, NEVER EXCLUSION. On Windows `command -v python3` usually resolves to the
# Microsoft Store app-execution alias under AppData/Local/Microsoft/WindowsApps. That
# alias is not one thing: where the Store package is installed it forwards to a real
# interpreter (measured on the reference machine at 163ms a spawn against 60ms for the
# real python sitting beside it on PATH), and where it is not, it prints an advert and
# exits 9009. So a WindowsApps path goes to the END of the list, and is never dropped: on
# a machine where the alias is the only python, refusing it would block every command
# these hooks exist to judge. A guardrail that bricks the machine is not the safer
# failure — this is a preference, not a ban.
#
# NOTHING IS PROBED HERE, and that is the point. A `-c` probe is a whole extra process on
# every single invocation, against a hook whose entire job is one. The parse below already
# IS the probe: a stub fails it exactly the way a missing interpreter does, so the next
# candidate is tried and the happy path pays nothing at all. Only the refusal path — where
# the call is being blocked anyway — asks each candidate whether it is python, so the
# message can name the RESOLVED PATH it tried. `python3` names the thing the user already
# typed; the path is the thing they can act on.
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
# THE SIBLINGS ARE NOT FIXED HERE, and that is a scope decision, not an oversight. The same
# text-mode write is in block-infra-staging.sh:31,34, block-secret-staging.sh:32,
# block-mcp-writes.sh:19, cleanup-handoffs.sh:26 and format-on-edit.sh:25. They are inert
# TODAY only because none of them joins a line continuation — the transform that turns the
# doubled CR into a wrong answer — and block-infra-staging.sh's own note says it intends to
# add that join. So "inert" there has a shelf life. Recorded on issue #140, thread 2, with
# this file named as the worked example.
# THE FIELDS ARE NOT PULLED OUT HERE ANY MORE. parse() used to sit at this point and run
# its own python process; it is now the head of payload_fields() further down, which is
# the same program as the tokenizer. The note above is unchanged and still describes the
# write that program makes, because it is still the same write — see the merge note at
# payload_fields() for why the two became one, and why the binary buffer matters MORE now
# rather than less. Nothing between here and there reads the payload.

# --- The allowlist -------------------------------------------------------------
# ~/.claude/repo-allowlist answers two questions per repo, keyed by REMOTE URL, both
# defaulting to no. See repo-allowlist.sample. This lookup is duplicated verbatim in
# block-infra-staging.sh on purpose — and so is the argument tokenizer below, payload_fields(),
# which is a parameterised second copy of staged_args() in that same file. A shared file
# you can forget to copy turns a guardrail into one that silently stops guarding, which is
# the failure this whole directory is built to avoid. Duplication is loud; a missing
# include is not. The divergences between the two tokenizers are listed at payload_fields().
allowlist_says() { # <push|claude-md> — exit 0 = yes, 1 = no
    local field="$1" file="$HOME/.claude/repo-allowlist" dir remote key push own
    [ -r "$file" ] || return 1
    # Prefer the payload's cwd if the harness sends one; fall back to ours. A payload
    # that PARSES and simply carries no cwd is the fallback case; a payload that will
    # not parse at all was the fail-closed case — and it is now handled once, up front,
    # before this function can be reached. This used to re-parse the payload in a second
    # python process, which only ran on the push and claude-md paths; folding it into the
    # single parse removed a spawn without adding one, because the field comes back from
    # a program that was going to run anyway.
    dir="$payload_cwd"
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

# --- What does this command actually DO? ---------------------------------------
# Every rule below reads the ARGUMENTS of a git subcommand, never the command text.
#
# The text scan this replaces refused any command in which a dangerous string APPEARED at
# all. `echo "never run git push --force here"` was blocked. So was a commit message
# explaining why a flag is banned, a grep for it in docs/, and a heredoc writing a note
# about it — including, measurably, the notes for this very ticket (#117). And because a
# compound command dies whole, anything chained in FRONT of the mention never ran either.
#
# This is a parameterised SECOND COPY of staged_args() in block-infra-staging.sh, kept
# separate on purpose (see the allowlist note above). FIVE deliberate divergences, each a
# real decision and not a transcription slip:
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
#   5. The git PROGRAM is looked for anywhere in the segment, not only at word 0.
#      staged_args() bails the moment word 0 is not git, so every wrapper hides the
#      command behind it: `sudo git push --force`, `env`/`time`/`command`, the canonical
#      `git branch --merged | xargs git branch -D`, and any shell keyword that leads a
#      segment (`then`, `do`). All measured ALLOW under the word-0 rule; all blocked by
#      the plain text scan this hook replaces, so word 0 would have been a REGRESSION.
#      The scan direction is deliberate: an UNRECOGNISED leading word does not end the
#      search, it is skipped and the search continues. A wrapper allow-list would have to
#      be complete to be safe, and the day it is not, the unknown wrapper fails OPEN —
#      the one direction this file may not fail in. And it does not stop at the first git
#      it finds, for the same reason: see the loop.
#
#      THE COST IS NOT ZERO. An earlier draft of this comment claimed the forward scan
#      "costs only false positives of the shape `echo git push --force`, which the text
#      scan blocked too". That was wrong, and wrong in the direction that makes a comment
#      dangerous — it told the next reader the change was free. Master's plain-push rule
#      was the one ANCHORED pattern in the file, so an UNQUOTED mention of `git push`
#      with no force flag was ALLOWED then and is BLOCKED now, in any repo not in the
#      allowlist — which is the shipped default. Measured: `man git push`, `type git
#      push`, `apropos git push`, `echo git push origin main` all went 0 -> 2.
#      The same mechanism buys real tightenings, also measured 0 -> 2: `sudo git push
#      origin main`, `xargs git push`, `git -C <dir> branch -D f`, `git --no-pager branch
#      -D f`, `git.exe push --force`, `"git" push --force`. So it is a TRADE, taken
#      deliberately — a false positive is recoverable and a fail-open force push is not —
#      and both directions are cases in test-hooks.sh so the trade stays visible. What is
#      genuinely free is the QUOTED mention: every measured #117 false positive quotes it,
#      and a quoted mention is one token whose basename is not `git`.
#      Backticks are turned into separators for the same reason `$( … )` already is one:
#      `` `git branch -D f` `` is otherwise a single token that is not `git`.
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
# THE TOKENIZER ITSELF DID NOT MOVE AND WAS NOT REFLOWED. Everything from strip_heredocs
# to the final write is the text that was here before, at the same indentation, because
# issue #140 is queued to change exactly those lines and a reflow would cost it a clean
# rebase. What changed is the head (the JSON read, which used to be a separate program
# above) and the tail (one write instead of one write per program). Two tokenizer lines
# moved with them: the import, and the line that used to call sys.stdin.read().
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
# NO GIT, NO TOKENIZER. The early exit below is the pre-filter that used to be a `grep
# -Eiq git` in the shell: it exists so an ordinary non-git Bash call does not pay for
# tokenizing, and just as importantly so a non-git command that will not tokenize is not
# suddenly a block. It is expressed once, here, and the shell now branches on whether any
# rows came back rather than testing the command text a second time.
payload_fields() { # prints cwd \x1e <tokenized rows> \x1e command; exit 3 = unparsable
    py_run "$payload" '
import json, re, shlex, sys

_d = json.load(sys.stdin)
_ti = _d.get("tool_input") or {}
CWD = _d.get("cwd") or ""
CMD = _ti.get("command") or _ti.get("script") or ""

def emit(rows):
    sys.stdout.buffer.write((CWD + "\x1e" + rows + "\x1e" + CMD).encode("utf-8"))

if "git" not in CMD.lower():
    emit("")
    sys.exit(0)

# The options git itself takes BEFORE the subcommand. These take a separate value.
GLOBAL_VAL = {"-C", "-c", "--git-dir", "--work-tree", "--exec-path", "--namespace"}

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

OPS = (";", "&&", "||", "|", "&", "|&", "(", ")")

def is_git(w):
    # A path separator may be either slash; the program may carry the .exe suffix on
    # Windows. Only the BASENAME decides, so /usr/bin/git and C:\bin\git.exe both count.
    return w.replace("\\", "/").rsplit("/", 1)[-1].lower() in ("git", "git.exe")

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
    # exists to prevent, here and identically in staged_args() in block-infra-staging.sh.
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

def strip_heredocs(s):
    # A heredoc body is DATA, not a command. A line inside one that begins with git is
    # prose ABOUT git, which is what this repo is full of.
    #
    # TWO THINGS THIS FUNCTION MUST NOT DO, both of them measured fail-opens (#117), both
    # confirmed with a git shim on PATH that records the argv real bash passed:
    #
    #   1. KEEP THE REST OF THE LINE. In bash the body starts on the NEXT line, so whatever
    #      follows the operator on THIS one is a real command that really runs. Truncating
    #      at m.start() threw it away: cat <<EOF ; git branch -D feature,
    #      cat <<EOF > n.txt && git add -A, cat <<EOF ; git push --force and eleven more
    #      shapes returned 0 where the text scan this hook replaces returned 2. NOT
    #      allowlist-scoped: git add -A and git add . fail open in EVERY repo, and those
    #      two are the ones repo-allowlist.sample says nothing can unlock.
    #   2. DO NOT SWALLOW WHEN THE TERMINATOR NEVER COMES. The regex fires on <<WORD
    #      anywhere on the line — inside quotes, inside a # comment, in prose — and the
    #      swallow then discards every following line up to the terminator. With no
    #      terminator that is the whole rest of the payload, judged by nothing:
    #      a git status line ending in a # comment that names <<EOF, with git add -A on the
    #      next line, returned 0 in BOTH allowlist states — and the # is what makes it real:
    #      bash never sees a heredoc there, so the second line runs.
    #      An unterminated heredoc is a shape bash ITSELF refuses to run
    #      (the shim records no git call at all), so keeping those lines cannot cost a real
    #      false positive — it can only block a command that was never going to execute.
    #
    # THE TWO ARE ONE FIX, and taking only the first is WORSE than taking neither. Seven
    # shapes block today only BY ACCIDENT: truncating at m.start() cuts a quoted mention in
    # half, shlex raises ValueError, and the hook exits 3 — fail-closed for the wrong
    # reason. Repair the line without also fixing the swallow and those seven walk straight
    # into it. Measured 2 -> 0 for grep -n "<<\x27PY\x27" install.sh followed by a force
    # push, which is a command someone reviewing this very hook would type. Turning an
    # accidental fail-CLOSED into a deliberate fail-OPEN is the worst trade on offer here.
    #
    # KNOWN RESIDUE, recorded rather than half-fixed: a FALSE heredoc whose terminator word
    # happens to appear alone on a later line is still read as a body, so the lines between
    # are dropped. It needs the word to coincide exactly. Closing it means deciding whether
    # <<WORD is a real operator — not inside quotes, not after a # — which is parsing a
    # shell, the same boundary #140 draws.
    #
    # THE SIBLING IS NOT FIXED HERE. block-infra-staging.sh:140 carries the identical
    # truncation and its note calls strip_heredocs a shared part. There the shapes measure 0
    # on master and on this branch alike — shipped with #112, not a #117 regression — and
    # this ticket keeps that file comment-only, so the divergence is deliberate. Recorded
    # here rather than left to be discovered, the same call this file makes for parse().
    lines = s.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out, i = [], 0
    while i < len(lines):
        m = re.search(r"<<-?\s*([\x27\x22]?)([A-Za-z_][A-Za-z0-9_]*)\1", lines[i])
        out.append((lines[i][:m.start()] + lines[i][m.end():]) if m else lines[i])
        i += 1
        if m:
            term = m.group(2)
            j = i
            while j < len(lines) and lines[j].strip() != term:
                j += 1
            if j < len(lines):     # terminator found: a real heredoc, its body is data
                i = j + 1
            # else: not a heredoc after all — judge those lines, do not discard them
    return "\n".join(out)

src = strip_heredocs(CMD)

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

# Newlines become an explicit separator BEFORE tokenizing: shlex treats one as plain
# whitespace, which would run two commands together into one segment. A backtick becomes
# a separator too (divergence 5): it is command substitution, and shlex does not know it.
src = src.replace("\n", " ; ").replace("\x60", " ; ")

lex = shlex.shlex(src, posix=True, punctuation_chars=True)
lex.whitespace_split = True
lex.escape = ""      # a backslash is a Windows path separator here, never an escape
lex.commenters = ""
try:
    toks = list(lex)
except ValueError:
    sys.exit(3)

segs, cur = [], []
for t in toks:
    if t in OPS:
        segs.append(cur)
        cur = []
    else:
        cur.append(t)
segs.append(cur)

out = []
for seg in segs:
    words, k = [], 0
    while k < len(seg):                       # drop redirections and their targets
        if seg[k] and all(c in "<>" for c in seg[k]):
            k += 2
            continue
        words.append(seg[k])
        k += 1

    j = 0                                     # leading VAR=value assignments
    while j < len(words) and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[j]):
        j += 1
    # Divergence 5: the git program may sit behind a wrapper (sudo, env, time, command,
    # xargs) or a shell keyword (then, do), so scan forward for it rather than requiring
    # word 0. An unrecognised word is SKIPPED, never a reason to give up on the segment.
    # EVERY occurrence of git in the segment is judged, not just the first. Stopping at
    # the first one is an assumption, and it fails OPEN: in a sudo -u git git push --force
    # the first git is the VALUE of -u, so the next word became the "subcommand" and the
    # real command was never judged (measured 2 on the text scan, 0 here). Judging them all
    # can only emit extra rows, and an extra row can only make a rule fire — fail-closed.
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
        sub = words[j].lower()                # divergence 1: every subcommand, no SUB map
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
                j += 2 if d in vals else 1
            else:
                out.append(sub + "\t" + "path" + "\t" + w)
                j += 1

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
    3) block "this command could not be read well enough to tell what it does — refusing rather than guessing." ;;
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
# one. The line is kept at all, rather than dropped, because block-infra-staging.sh and
# block-secret-staging.sh compute the same $norm. They still do it the way this hook used
# to, with `printf | tr '\r\n' ';;' | tr -s ' '`: the TRANSFORM is equivalent — same output
# on every input, including runs of spaces, the all-spaces string and the empty one — and
# only the FORM differs. The divergence is deliberate and means nothing more than this:
# this hook is the hot path that was measured, so it is the one that got the builtin.
norm="${cmd//[$'\r\n']/;}"
while [ "${norm#*  }" != "$norm" ]; do
    norm="${norm//  / }"
done

# --- Hard blocks ---------------------------------------------------------------
# The pre-filter is deliberately just "git": `git -C <dir> push` does not put the verb
# next to the program name, and a filter that demanded that let the whole command past.
# It is safe ONLY because the two raw-text rules further down run OUTSIDE it — see there.
#
# IT IS NOW EXPRESSED ONCE, inside payload_fields(), and this line reads the RESULT rather
# than testing the command text a second time. Two copies of "does this mention git" in
# two languages is a shared contract that can drift, and the drift would be silent: the
# rows are empty exactly when the tokenizer was not run or found no git invocation, which
# is the same set of commands the text filter used to let through to an empty $args.
if [ -n "$args" ]; then
    # WHAT THIS TOKENIZER DOES NOT SEE — a known, deliberate gap. Filed as issue #140.
    #
    # payload_fields() reads the command it was handed. It does not read a command that is DATA
    # inside that command, so both of these run and both return 0 where the text scan this
    # hook replaces returned 2:
    #
    #   bash -c "git push --force"     a command string passed to another program
    #                                  (also sh -c, eval, ssh host '…', and any wrapper
    #                                  whose argument is itself a shell command)
    #   "$( git push --force )"        command substitution INSIDE double quotes — it is
    #                                  one shlex token, so the words never separate
    #
    # Unquoted `$( … )` and unquoted backticks DO block; it is the double-quoted form that
    # gets through. Both classes are inherited from the tokenizer in block-infra-staging.sh
    # (#112), which behaves identically, and closing them properly means parsing a shell
    # rather than tokenizing one. THE HALF-MEASURE IS WORSE THAN THE GAP: a rule that
    # catches `bash -c` but not `sh -c` reads as coverage, and the next person stops
    # looking. So the boundary is written down here instead, and the user accepted it
    # rather than growing #117 into a shell parser. If you close it, close all of it.
    push_checked=""
    while IFS="$(printf '\t')" read -r sub kind arg; do
        [ -n "$sub" ] || continue

        # git push — the human pushes manually, unless this repo is allowlisted for it.
        # The `sub` row is why a bare `git push` with no arguments is caught. Asked once
        # per command: allowlist_says re-parses the payload to find out which repo it is.
        if [ "$sub" = push ] && [ -z "$push_checked" ]; then
            push_checked=1
            allowlist_says push || \
                block "git push is not allowed here — this repo is not in ~/.claude/repo-allowlist with push: yes. Push manually, or add a line."
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
                    --*)      ;;
                    -*[fF]*)  block "git push --force" ;;
                esac ;;
        esac
    done <<< "$args"
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
