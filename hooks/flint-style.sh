#!/bin/sh
# flint-style.sh — Claude Code hook: injects the flint style ruleset.
# One script, three events; $1 selects the payload.
#
#   SessionStart     full ruleset (no matcher: must also fire on compact —
#                    compaction prunes injected context, caveman 80a317e)
#   SubagentStart    full ruleset (SessionStart context is parent-thread only
#                    and never reaches Task-spawned subagents, ponytail #252)
#   UserPromptSubmit one static reinforcement line (attention anchor, not the
#                    ruleset — caveman 3ed7b73: "recency and repetition win")
#
# Constraints carried from the upstream plugins' bug history:
# - hookSpecificOutput JSON for ALL events: SubagentStart silently drops raw
#   stdout (ponytail-runtime.js). Wrong shape = context lost, no error.
# - Always exit 0. Non-zero surfaces as a hook failure banner every turn
#   (caveman #538); EPIPE on closed stdout must not kill us (ponytail #149).
# - Never read stdin (ponytail #443: stdin 'end' never fires, session froze).
# - All ruleset paths missing, empty, or unreadable → LOUD marker, never
#   silent-empty context (caveman #587: bad path fell back to a stale ruleset
#   in silence). `-s` rejects a 0-byte file; the encode stage exits into the
#   marker on empty read (EACCES, delete-after-check race).
# - python absent → same loud marker path, built with printf only
#   (ponytail #57-class: hooks run under non-interactive /bin/sh, narrow PATH).
# - Fallback paths are user-writable → refuse symlinks (caveman 5ad8f6d: a
#   symlinked read injected secret file bytes into model context).
# - head -c cap: an oversized ruleset must not eat the context window.
set -u
trap '' PIPE

EVENT="${1:-SessionStart}"
# $EVENT lands inside hand-built JSON below — whitelist it, never interpolate
# an arbitrary argv byte into the payload.
case "$EVENT" in
    SessionStart|SubagentStart|UserPromptSubmit) ;;
    *) EVENT='SessionStart' ;;
esac

if [ "$EVENT" = "UserPromptSubmit" ]; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"FLINT ACTIVE. Terse prose: drop articles/filler/pleasantries/hedging, fragments OK, strip conjunctions where unambiguous, one word when enough, each fact once, never drop a negation or quantifier (only/except), no tool-call narration, quote the shortest decisive line. Lazy code: climb the ladder (YAGNI, reuse, stdlib, native, one line), shortest working diff, root cause not symptom. Security/irreversible/ambiguous sequences: write full prose. Code, commits, error strings: verbatim, always. External lib unchecked this session: context7 first; LSP navigation + diagnostics when available."}}' 2>/dev/null || :
    exit 0
fi

emit_marker() {
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"FLINT HOOK ERROR: %s. Style ruleset NOT injected — report this to the user."}}\n' "$EVENT" "$1" 2>/dev/null || :
    exit 0
}

# Resolution order: baked container path, then clone geometry (this repo),
# then the vmCODE vendored geometry (scripts/ + container-docs/). The baked
# path is root-owned; both fallbacks are user-writable, so symlinks refused.
RULESET='/etc/claude-docs/flint.md'
if [ ! -s "$RULESET" ]; then
    DIR="$(dirname "$0" 2>/dev/null)"
    if [ -s "$DIR/../flint.md" ] && [ ! -L "$DIR/../flint.md" ]; then
        RULESET="$DIR/../flint.md"
    elif [ -s "$DIR/../container-docs/flint.md" ] && [ ! -L "$DIR/../container-docs/flint.md" ]; then
        RULESET="$DIR/../container-docs/flint.md"
    else
        emit_marker 'ruleset not found (or empty) at /etc/claude-docs/flint.md, ../flint.md, or ../container-docs/flint.md'
    fi
fi

# python3 preferred; plain python accepted (Windows Git Bash often ships only
# `python`). A python2 `python` fails the encode stage → loud marker below.
PYBIN="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"
[ -n "$PYBIN" ] \
    || emit_marker 'python3/python not on PATH (hooks run under non-interactive /bin/sh)'

# decode(...,'replace'): a head -c truncation can split a UTF-8 sequence;
# never let that become a UnicodeDecodeError → empty context.
head -c 65536 "$RULESET" 2>/dev/null | "$PYBIN" -c '
import json, sys
txt = sys.stdin.buffer.read().decode("utf-8", "replace")
if not txt.strip():
    sys.exit(3)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": sys.argv[1],
    "additionalContext": txt,
}}))
' "$EVENT" 2>/dev/null || emit_marker 'ruleset unreadable, empty, or JSON encoding failed'
exit 0
