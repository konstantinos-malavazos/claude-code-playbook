#!/usr/bin/env bash
# serena-down.sh [repo-key...] — stop route C Serena servers (no key: all of them) and
# check by process listing that none is left. serena_route.py beside this file does
# the work; this finds a python by the hooks' own interpreter list.
kit="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_LIB_LOADED=
# shellcheck source-path=SCRIPTDIR source=../hooks/_lib/common.sh
. "$kit/../hooks/_lib/common.sh" 2>/dev/null
if [ "${HOOK_LIB_LOADED-}" != 1 ]; then
    echo "serena-down: $kit/../hooks/_lib/common.sh is missing. Run the playbook installer again to restore it." >&2
    exit 1
fi
py=""
for c in ${PY_LIST[@]+"${PY_LIST[@]}"}; do
    if "$c" -c "pass" >/dev/null 2>&1; then py="$c"; break; fi
done
if [ -z "$py" ]; then
    echo "serena-down: no working python found — $(py_tried)" >&2
    exit 1
fi
script="$kit/serena_route.py"
# A /c/... path holding an apostrophe reaches a Windows python untranslated.
if command -v cygpath >/dev/null 2>&1; then script="$(cygpath -m "$script")"; fi
"$py" "$script" down "$@"
