# ADR 0002 — Windows requires Git Bash; no PowerShell hook port

Date: 2026-07-21 · Status: accepted

## Context

Claude Code on Windows runs shell-form hooks via Git Bash when installed,
falling back to PowerShell only when it isn't (official hooks reference). The
flint hook is POSIX sh carrying eight bug-history invariants (always exit 0,
no stdin, argv whitelist, loud markers, symlink refusal, byte cap, full
quoting, POSIX syntax).

## Decision

Windows support = **Git for Windows required**, documented. The sh hook is
the only implementation; `install.ps1` is a thin wrapper that validates Git
Bash presence and runs the same Python installer. The hook accepts `python`
as a fallback interpreter name (Git Bash environments often lack `python3`).

## Consequences

- One implementation of load-bearing delivery logic; the CI Windows runner
  exercises the real Git Bash path.
- Machines without Git Bash are unsupported — the installer says so and
  stops; no silent degradation.

## Alternatives rejected

- PowerShell port of the hook: duplicates every invariant in a second
  language; the delivery-logic drift between two copies is the exact bug
  class flint exists to kill.
- WSL-only: excludes native Windows Claude Desktop, the stated target.
