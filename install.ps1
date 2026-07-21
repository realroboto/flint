# flint installer wrapper (Windows) — validates Git Bash, runs install.py.
# flint's hook is POSIX sh by design: Claude Code runs shell-form hooks via
# Git Bash on Windows. No Git Bash = no flint (documented requirement).
$ErrorActionPreference = 'Stop'

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Error 'flint requires Git for Windows (Git Bash) - hooks run via bash. https://gitforwindows.org'
    exit 1
}

$py = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) {
    Write-Error 'flint install: Python 3 not found on PATH'
    exit 1
}

& $py.Source (Join-Path $PSScriptRoot 'install.py') @args
exit $LASTEXITCODE
