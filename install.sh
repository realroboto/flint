#!/bin/sh
# flint installer wrapper — finds a Python 3 and runs install.py.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
PY="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"
if [ -z "$PY" ]; then
    echo 'flint install: python3 not found on PATH' >&2
    exit 1
fi
exec "$PY" "$DIR/install.py" "$@"
