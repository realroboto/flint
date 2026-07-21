# ADR 0001 — flint extracted from vmCODE; consumers vendor a pinned copy

Date: 2026-07-21 · Status: accepted

## Context

flint was born inside vmCODE (a container build system), entangled with its
seed and Containerfile. Installing on new devices was manual; Claude Desktop
surfaces had nothing. The ruleset's wording is load-bearing
(benchmark-validated upstream), so two editable copies would be an
instruction-drift hazard — the same class of bug that motivated flint's
creation (marketplace clones running 35 commits behind).

## Decision

This repo is flint's single canonical home: ruleset, hook, installer,
derivados, tests, docs. vmCODE (and any future consumer) vendors a **pinned
copy** — pin recorded in the consumer's version manifest, updated by explicit
ref-bump, never edited in place. Cutover was immediate: no window with two
masters.

## Consequences

- Ruleset/hook edits happen here, propagate by `git pull` (devices) and
  ref-bump (consumers).
- The hook resolves the ruleset across all consumer geometries (baked path →
  clone → vmCODE vendored layout), so one script ships everywhere.
- A consumer's local edit to a vendored copy is a bug by definition.

## Alternatives rejected

- vmCODE stays canonical, new repo mirrors: public repo lags a private build
  system; two masters in practice.
- Independent fork: guaranteed wording drift.
- Git submodule in consumers: off-pattern for vmCODE's vendoring convention,
  checkout friction in container builds.
