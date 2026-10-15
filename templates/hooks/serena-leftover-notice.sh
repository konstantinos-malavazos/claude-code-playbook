#!/usr/bin/env bash
# SessionStart hook (matcher: startup).
# Route C: names the Serena servers, and the state files, that an earlier session left
# behind, with the command that stops them. Non-blocking.
#
# THIS HOOK CANNOT FAIL CLOSED, and is not made to try. A session start has nothing to
# stop, so a non-zero exit would only print a hook error at the top of every session. The
# EXIT trap makes every path exit 0, an unexpected one included; a hook that cannot check
# says why on stderr and lets the session start.
trap 'exit 0' EXIT
set -u

_here="${BASH_SOURCE[0]//\\//}"
case "$_here" in */*) _here="${_here%/*}" ;; *) _here="." ;; esac
_home="$_here/.."
_route="$_home/serena/serena_route.py"

# Nothing recorded is the common case, and it is answered without starting python.
_found=
for _f in "$_home/serena-state"/*.json; do
    [ -e "$_f" ] && _found=1 && break
done
[ -n "$_found" ] || exit 0

HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=_lib/common.sh
if ! . "$_here/_lib/common.sh" 2>/dev/null || [ "$HOOK_LIB_LOADED" != 1 ]; then
    echo "serena-leftover-notice: the shared hook library is missing or broken at $_here/_lib/common.sh — not checking for leftover Serena servers. Re-run the installer." >&2
    exit 0
fi
if [ ! -f "$_route" ]; then
    echo "serena-leftover-notice: the route C kit is missing ($_route) — not checking for leftover Serena servers. Re-run the installer." >&2
    exit 0
fi
if [ "${#PY_LIST[@]}" -eq 0 ]; then
    echo "serena-leftover-notice: no python3 or python on PATH — not checking for leftover Serena servers." >&2
    exit 0
fi

# MSYS does not translate a /c/... argument that holds an apostrophe, and python would
# then read it as C:\c\...; cygpath -m hands python a path it can open.
if command -v cygpath >/dev/null 2>&1; then
    _route="$(cygpath -m "$_route")"
    _home="$(cygpath -m "$_home")"
fi

# Not py_run: it lets every candidate print, so a run that fails halfway would leave its
# half on stdout, which SessionStart adds to the session. Only a clean run is shown.
for _c in "${PY_LIST[@]}"; do
    if _out="$("$_c" "$_route" status --notice --home "$_home" 2>/dev/null)"; then
        [ -z "$_out" ] || printf '%s\n' "$_out"
        exit 0
    fi
done
echo "serena-leftover-notice: could not list leftover Serena servers. $(py_tried)" >&2
exit 0
