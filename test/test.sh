#!/bin/sh
# flint test matrix — hook stdout contract + installer seam + derivado budgets.
# Run from the repo root: sh test/test.sh   Every step must print its ok tag.
set -u
cd "$(dirname "$0")/.." || exit 1
FAILS=0
ck() { if [ "$1" -eq 0 ]; then echo "ok  $2"; else echo "FAIL $2"; FAILS=$((FAILS+1)); fi; }
PY="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"

# 1-3: valid JSON, right event, anchor line on all 3 events
sh hooks/flint-style.sh SessionStart     | "$PY" -m json.tool >/dev/null 2>&1; ck $? "1 SessionStart JSON"
sh hooks/flint-style.sh SubagentStart    | "$PY" -m json.tool >/dev/null 2>&1; ck $? "2 SubagentStart JSON"
sh hooks/flint-style.sh UserPromptSubmit | grep -q '"FLINT ACTIVE'; ck $? "3 UserPromptSubmit anchor"

# 4: every ruleset path missing -> loud marker + exit 0 (probe on a /tmp copy)
FX="$(mktemp -d)"
mkdir -p "$FX/hooks"
cp hooks/flint-style.sh "$FX/hooks/"
sh "$FX/hooks/flint-style.sh" SessionStart | grep -q 'FLINT HOOK ERROR'
ck $? "4 missing ruleset -> loud marker"
sh "$FX/hooks/flint-style.sh" SessionStart >/dev/null 2>&1; ck $? "4b marker path exits 0"

# 5: python missing -> loud marker + exit 0
# Skipped on MSYS/Git Bash: env -i strips vars (SYSTEMROOT etc.) Windows needs
# to exec anything, so the stripped-PATH harness can't be built faithfully
# there. The guard under test is OS-independent and proven on the unix runners.
case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*)
        echo "ok  5 no python -> loud marker (skipped: env -i not faithful on MSYS)" ;;
    *)
        BIN="$FX/bin"; mkdir -p "$BIN"
        for t in dirname head; do ln -s "$(command -v "$t")" "$BIN/$t" 2>/dev/null || cp "$(command -v "$t")" "$BIN/$t"; done
        OUT="$(env -i PATH="$BIN" /bin/sh hooks/flint-style.sh SessionStart 2>/dev/null)"
        echo "$OUT" | grep -q 'not on PATH'; ck $? "5 no python -> loud marker" ;;
esac

# 6: EPIPE -> exit 0
sh hooks/flint-style.sh SessionStart 2>/dev/null | head -c 10 >/dev/null; ck $? "6 EPIPE exit 0"

# 7: argv injection -> whitelisted to SessionStart, no injected JSON key
sh hooks/flint-style.sh 'X","evil":"1' | "$PY" -c 'import json,sys; d=json.load(sys.stdin); assert d["hookSpecificOutput"]["hookEventName"]=="SessionStart"'; ck $? "7 argv whitelist"

# 8: symlinked fallback refused (skipped where ln -s cannot make real symlinks)
ln -sf /etc/hosts "$FX/flint.md" 2>/dev/null
if [ -L "$FX/flint.md" ]; then
    sh "$FX/hooks/flint-style.sh" SessionStart | grep -q 'FLINT HOOK ERROR'; ck $? "8 symlink refused"
else
    echo "ok  8 symlink refused (skipped: no symlink support)"
fi

# 9: oversize ruleset capped at 64 KB -> the real ruleset, capped, never the marker
rm -f "$FX/flint.md"   # step 8's symlink: writing through it would FOLLOW it into /etc/hosts
# Shell-built, not python-built: a native Windows python can't resolve Git
# Bash's POSIX /tmp paths.
{ printf '# flint\n'; yes x | tr -d '\n' | head -c 5242880; } > "$FX/flint.md" 2>/dev/null
sh "$FX/hooks/flint-style.sh" SessionStart | "$PY" -c 'import json,sys; c=json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"]; assert len(c)<=65536 and "FLINT HOOK ERROR" not in c and c.lstrip().startswith("# flint")'
ck $? "9 64KB cap"

# 10: shell syntax (zsh only where present)
bash -n hooks/flint-style.sh && sh -n hooks/flint-style.sh; ck $? "10 bash/sh syntax"
if command -v zsh >/dev/null 2>&1; then zsh -n hooks/flint-style.sh; ck $? "10b zsh syntax"; fi
bash -n install.sh && sh -n install.sh; ck $? "10c installer wrapper syntax"

# 11: installer seam tests
"$PY" test/install_test.py | grep -q '^PASS$'; ck $? "11 installer suite"

# 12: docs-first rule ships on both full-ruleset events + anchor clause per turn
sh hooks/flint-style.sh SessionStart     | grep -q 'once per lib per session' \
  && sh hooks/flint-style.sh SubagentStart  | grep -q 'once per lib per session' \
  && sh hooks/flint-style.sh UserPromptSubmit | grep -q 'context7 first'
ck $? "12 docs-first clauses"

# 13: derivado character budgets. 13b/13c are external hard caps (published
# surface limits); 13d-13f are sanity ceilings — those surfaces publish no
# cap, the guard only catches runaway growth.
[ "$(wc -c < flint.md)" -le 65536 ]; ck $? "13a ruleset <= 64KB"
[ "$(wc -c < desktop/chat/profile.md)" -le 1500 ]; ck $? "13b chat profile <= 1500"
[ "$(wc -c < desktop/chat/project-instructions.md)" -le 8000 ]; ck $? "13c project instructions <= 8000"
[ "$(wc -c < desktop/chat/style.md)" -le 8000 ]; ck $? "13d chat style <= 8000 (sanity)"
[ "$(wc -c < desktop/cowork/SKILL.md)" -le 65536 ]; ck $? "13f cowork skill <= 64KB (sanity)"

# 14: verbatim-derivado canary — both full-ruleset derivados carry the token
grep -q 'once per lib per session' desktop/cowork/SKILL.md \
  && grep -q 'once per lib per session' desktop/chat/project-instructions.md
ck $? "14 verbatim derivado canary"

rm -rf "$FX"
if [ "$FAILS" -eq 0 ]; then echo "ALL PASS"; else echo "FAILURES: $FAILS"; exit 1; fi
